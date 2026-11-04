# frozen_string_literal: true

require 'test_helper'
require 'json'

class MessageModelTest < Minitest::Test
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
    assert MessageModel.append(note('one'))
    assert MessageModel.append(note('two'))
    assert_equal %w[two one], MessageModel.last(10).map(&:text)
    assert_equal %w[Ada Ada], [MessageModel.last(1).first.from, MessageModel.last(1).first.sender]
  end

  def test_only_the_newest_are_kept
    5.times { |i| MessageModel.append(note(i.to_s), keep: 3) }
    assert_equal %w[4 3 2], MessageModel.last(10).map(&:text)
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
    assert_equal [2, 2], LegacyInbox.new(legacy).import
    assert_equal ['hi[2J', nil], MessageModel.last(10).map(&:text)
    assert_equal %w[https://x.example/rss Bob], MessageModel.last(10).last.values.values_at(:url, :sender)
    refute File.exist?(legacy)
    assert File.exist?("#{legacy}.imported")
    assert_match(/imported 2 messages from inbox.jsonl \(2 skipped\)/, $stderr.string)
  end

  def test_no_import_into_a_full_inbox
    MessageModel.append(note('kept'))
    File.write(path('inbox.jsonl'), JSON.generate(kind: 'feedback', at: 'x', text: 'old'))
    assert_nil LegacyInbox.new(path('inbox.jsonl')).import
    assert_equal 1, MessageModel.count
    assert File.exist?(path('inbox.jsonl'))
  end
end
