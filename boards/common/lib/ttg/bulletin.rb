# frozen_string_literal: true

module TTG
  # The network's day in a few lines, shown to an account once a day, on the
  # first board it signs in on that day (TTG::Logon): the date, the name day
  # and the weather, and the notes our boards keep for the Today tab. It
  # lives on the Central (TTG Gate BBS) as a Rubbs::Common::Central::Service,
  # Service; the gate gives it its lines with ::source.
  #
  #   TTG::Bulletin.source = ->(at) { [gate.today(at: at).summary] }   # on the gate
  #   TTG::Bulletin.today(session)                                     # => ["Fri 27 Nov · …"], once a day
  module Bulletin
    # The table of who saw the bulletin when, on the Central.
    MIGRATIONS = [
      <<~SQL
        CREATE TABLE bulletin_seen (
          account_id INTEGER PRIMARY KEY,
          day        TEXT NOT NULL
        );
      SQL
    ].freeze

    # The most lines of a bulletin.
    MAX_LINES = 4

    class << self
      # Sets where the lines of the day come from: a callable given the
      # Time, answering an Array of Strings (on the board of the Central).
      attr_writer :source

      # The lines of the day at +at+ (at most MAX_LINES), from ::source;
      # none without one, or when it fails.
      def lines(at = Time.now)
        return [] unless @source

        Array(@source.call(at)).map { |line| Rubbs::Common::Text.line(line.to_s) }.reject(&:empty?).first(MAX_LINES)
      rescue StandardError => e
        Rubbs.log('bulletin', e, level: :warn)
        []
      end
    end

    # The bulletin on this board (a Rubbs::Common::Central::Proxy of Service).
    def self.board = Rubbs.central(Service)

    # The lines for the caller on +session+ the first time today it is asked
    # for an account (an empty Array after that, for a guest, and when the
    # Central does not answer).
    def self.today(session)
      return [] unless session.identity.signed_in?

      Array(board.call(:today, Rubbs::Common::Central::Actor.of(session))['lines']).map(&:to_s)
    end
  end
end

require_relative 'bulletin/service'
