# frozen_string_literal: true

require 'test_helper'

class SessionServiceTest < Minitest::Test
  include TmpData

  def service = @service ||= SessionService.new(SessionRepository.new(path('sessions.sqlite3')))

  def test_a_call_is_recorded_then_completed
    service.upsert(session_id: 's1', player_name: 'NOR', code: '2J5GFN')
    service.upsert(session_id: 's1', feedback: 'Great puzzle!', email: 'norman@example.com')
    call = service.find('s1')
    assert_equal ['NOR', '2J5GFN', 'Great puzzle!', 'norman@example.com'],
                 [call.player_name, call.code, call.feedback, call.email]
    refute_nil call.timestamp
  end

  def test_an_invalid_email_does_not_touch_the_call
    service.upsert(session_id: 's1', player_name: 'NOR', email: 'norman@example.com')
    service.upsert(session_id: 's1', email: 'nope')
    assert_equal 'norman@example.com', service.find('s1').email
  end

  def test_a_scanners_line_is_not_recorded
    service.upsert(session_id: 's1', player_name: 'GET / HTTP/1.0', code: '90')
    assert_nil service.find('s1')
  end

  def test_the_database_is_the_configured_sqlite_file
    service.upsert(session_id: 's1', player_name: 'ATM')
    assert File.exist?(path('sessions.sqlite3'))
  end

  def test_the_legacy_csv_is_imported_once_and_renamed
    File.write(path('sessions.csv'), <<~CSV)
      session_id,timestamp,player_name,code,feedback,email
      8effc48c813f29a9,2026-04-27T22:57:01Z,ATM,265LFI,That was cool!,
      bd2138d83c29df79,2026-04-28T19:03:50Z,ATM,265LFI,Hello,player@example.com
    CSV
    call = nil
    capture_subprocess_io { call = service.find('bd2138d83c29df79') }
    assert_equal ['2026-04-28T19:03:50Z', 'player@example.com'], [call.timestamp, call.email]
    assert File.exist?(path('sessions.csv.imported'))
    refute File.exist?(path('sessions.csv'))
  end

  def test_a_malformed_legacy_line_is_set_aside_and_the_good_ones_imported
    File.write(path('sessions.csv'), <<~CSV)
      session_id,timestamp,player_name,code,feedback,email
      a1,2026-04-27T22:57:01Z,ATM,265LFI,ok,
      a2,2026-04-28T19:03:50Z,ATM,265LFI,"broken,
      a3,2026-04-29T19:03:50Z,NOR,2J5GFN,fine,n@example.com
    CSV
    _, err = capture_subprocess_io { service.upsert(session_id: 'new', player_name: 'X') }
    assert_match(/2 rows .* imported .*, 1 set aside/, err)
    assert_equal %w[ok fine], [service.find('a1').feedback, service.find('a3').feedback]
    assert_nil service.find('a2')
    assert_includes File.read(path('sessions.csv.rejected')), 'a2,'
  end

  def test_opening_at_boot_imports_the_legacy_csv
    File.write(path('sessions.csv'), <<~CSV)
      session_id,timestamp,player_name,code,feedback,email
      a1,2026-04-27T22:57:01Z,ATM,265LFI,ok,
    CSV
    capture_subprocess_io { SessionRepository.new(path('sessions.sqlite3')).open! }
    assert File.exist?(path('sessions.csv.imported'))
  end

  def test_the_gem_flow_takes_the_service_as_its_store
    flow = Impostor::Modern.flow(sessions: service)
    assert_kind_of Rubbs::Common::Call::Flow, flow
  end
end
