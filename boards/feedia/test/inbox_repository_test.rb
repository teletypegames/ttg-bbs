# frozen_string_literal: true

require 'test_helper'
require 'json'

class InboxRepositoryTest < Minitest::Test
  include TmpDir

  def setup
    super
    $stderr = StringIO.new
  end

  def teardown
    $stderr = STDERR
    super
  end

  def note(text) = MessageModel.from_h(kind: 'feedback', at: '2026-11-01T10:00:00+01:00', from: 'Ada', text: text)

  def test_append_and_last
    inbox = InboxRepository.new(database)
    assert inbox.append(note('one'))
    assert inbox.append(note('two'))
    assert_equal %w[two one], inbox.last(10).map(&:text)
    assert_equal 'Ada', inbox.last(1).first.from
  end

  def test_only_the_newest_are_kept
    inbox = InboxRepository.new(database, keep: 3)
    5.times { |i| inbox.append(note(i.to_s)) }
    assert_equal %w[4 3 2], inbox.last(10).map(&:text)
  end

  def test_the_old_inbox_is_imported_once
    legacy = path('inbox.jsonl')
    File.write(legacy, [
      JSON.generate(kind: 'suggestion', at: '2026-10-27T10:00:00+01:00', from: 'Bob', name: 'X', url: 'https://x.example/rss'),
      '{"kind":"feedback","at":"2026-10-28T1',
      JSON.generate(kind: 'spam', at: 'now'),
      '',
      JSON.generate(kind: 'feedback', at: '2026-10-29T10:00:00+01:00', text: "hi\e[2J")
    ].join("\n"))
    inbox = InboxRepository.new(database, legacy: legacy)
    assert_equal ['hi[2J', nil], inbox.last(10).map(&:text)
    assert_equal 'https://x.example/rss', inbox.last(10).last.url
    refute File.exist?(legacy)
    assert File.exist?("#{legacy}.imported")
    assert_match(/imported 2 messages from inbox.jsonl \(2 skipped\)/, $stderr.string)
  end

  def test_no_import_into_a_full_inbox
    inbox = InboxRepository.new(database)
    inbox.append(note('kept'))
    File.write(path('inbox.jsonl'), JSON.generate(kind: 'feedback', at: 'x', text: 'old'))
    assert_equal 1, InboxRepository.new(database, legacy: path('inbox.jsonl')).count
    assert File.exist?(path('inbox.jsonl'))
  end
end
