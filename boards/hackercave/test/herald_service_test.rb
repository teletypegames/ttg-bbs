# frozen_string_literal: true

require 'test_helper'
require 'ttg/common'

class HeraldServiceTest < Minitest::Test
  include TempDir

  Word = Struct.new(:headword)
  Rfc  = Struct.new(:number, :title)

  def service(word: Word.new('hacker'), rfc: Rfc.new(9999, 'A New Thing'))
    jargon = Object.new.tap { |j| j.define_singleton_method(:word_of_the_day) { word } }
    HeraldService.new(jargon: jargon, path: path('herald.json'), newest: -> { rfc })
  end

  def test_the_note_of_the_day_holds_until_midnight
    at   = Time.local(2026, 11, 27, 15)
    note = service.note(at)
    assert_equal ['hackercave-bbs', 'HackerCave', 'jargon: hacker · newest RFC 9999', 'RFC 9999: A New Thing'],
                 note.values_at('board', 'heading', 'title', 'text')
    assert_equal Time.local(2026, 11, 28).utc.iso8601, note['until']
  end

  def test_it_is_written_once_and_not_without_anything
    assert_equal :written, service.publish
    assert_equal :same, service.publish
    assert_equal 'jargon: hacker · newest RFC 9999', JSON.parse(File.read(path('herald.json')))['title']
    assert_equal :none, service(word: nil, rfc: nil).publish
  end
end
