# frozen_string_literal: true

require 'time'

# What the board gives the network's day (the Today tab of TTG Gate BBS and
# the sign-in bulletin of every board): the Jargon File's word of the day
# and the newest RFC, in data/herald.json (TTG::HeraldNote), until midnight.
class HeraldService
  BOARD   = 'hackercave-bbs'
  HEADING = 'HackerCave'

  def initialize(jargon:, path:, newest: -> { RfcModel.newest(1).first })
    @jargon = jargon
    @path   = path
    @newest = newest
  end

  # The note of +at+'s day, a Hash; nil when there is neither a word nor an RFC.
  def note(at = Time.now)
    word = @jargon.word_of_the_day
    rfc  = @newest.call
    return nil unless word || rfc

    {
      'board'   => BOARD,
      'heading' => HEADING,
      'title'   => [("jargon: #{word.headword}" if word), ("newest RFC #{rfc.number}" if rfc)].compact.join(' · '),
      'text'    => rfc ? "RFC #{rfc.number}: #{rfc.title}" : '',
      'until'   => TTG::HeraldNote.day_end(at).utc.iso8601
    }
  end

  # Writes the note of +at+'s day unless the file has it: :written, :same or :none.
  def publish(at = Time.now) = TTG::HeraldNote.publish(@path, note(at))
end
