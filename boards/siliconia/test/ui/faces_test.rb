# frozen_string_literal: true

require 'test_helper'
require_relative '../../lib/ui/modern'
require_relative '../../lib/ui/petscii'

# Both faces on a fake line, over the small catalog of the test helper and the callers' data in a
# database in memory.
class FacesTest < Minitest::Test
  include TmpData

  Board = Struct.new(:services)

  # Wikipedia from memory: every article has one paragraph.
  class About
    def summary(machine, language = 'en')
      SummaryModel.new(
        title:      machine.name,
        url:        'https://en.wikipedia.org/wiki/X',
        paragraphs: ['The best selling one.'],
        language:   language
      )
    end
  end

  def setup
    super
    Rubbs::Test.database(MIGRATIONS)
    c      = sample_catalog(@dir)
    @board = Board.new({
      catalog:    c,
      about:      About.new,
      collection: CollectionService.new(catalog: c),
      memories:   MemoryService.new(catalog: c)
    })
  end

  def plain(text) = text.gsub(/\e\[[\d;?]*[A-Za-z]/, '').gsub(/\s+/, ' ')

  def petscii(keys)
    session = Rubbs::Test::Session.new(petscii: true, keys: keys)
    UI::Petscii.new(session, {}, @board).run
    plain(session.output)
  end

  def test_the_c64_legends_and_a_machine_page
    out = petscii(['l', '2', :enter, :enter, 'w', :enter, :enter, *%w[q] * 8])
    assert_includes out, 'the museum of computers and consoles'
    assert_includes out, 'Commodore 64'
    assert_includes out, '17,000,000 units'
    assert_includes out, 'The best selling one.'
  end

  def test_the_c64_search_and_a_guest_cannot_mark
    out = petscii(['s', *'tvc'.chars, :enter, :enter, :enter, 'm', 'o', :enter, :enter, *%w[q] * 8])
    assert_includes out, 'Videoton TV-Computer'
    assert_includes out, 'log in or make an account first'
  end

  def test_the_desktop_opens_the_legends
    before = Rubbs.config.board
    Rubbs.config.board = @board
    session = Rubbs::Test::Session.new(keys: [:alt_x])
    UI::Modern::APP.run(session: session, session_id: 'test')

    out = plain(session.output)
    assert_includes out, 'Commodore VIC-20'
    assert_includes out, 'Legends'
  ensure
    Rubbs.config.board = before
  end
end
