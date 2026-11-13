# frozen_string_literal: true

require 'json'
require 'time'

module Herald
  # What our boards give the Today tab: each board may keep a note in its data folder
  # (data/herald.json: +board+, +heading+, +title+, +text+, +until+), like Siliconia BBS's machine
  # of the week. The gate reads the notes of the files +pattern+ matches; a note past its +until+,
  # broken or without a title is left out.
  class Notes
    # One board's note: the board's id, a heading, a title, a line of text, until when it holds.
    Note = Data.define(:board, :heading, :title, :text, :until) do
      def self.from_h(data)
        new(
          board:   line(data['board']),
          heading: line(data['heading']),
          title:   line(data['title']),
          text:    line(data['text']),
          until:   Time.iso8601(data['until'].to_s)
        )
      end

      def self.line(text) = Rubbs::Common::Text.line(text.to_s)

      def current?(at) = !title.empty? && !heading.empty? && self.until > at
    end

    # The most notes shown.
    MAX = 3

    def initialize(pattern)
      @pattern = pattern
    end

    # The notes that hold at +at+, by board.
    def current(at = Time.now)
      Dir.glob(@pattern).filter_map { |path| note(path) }.select { |n| n.current?(at) }.first(MAX)
    end

    private

    def note(path)
      Note.from_h(JSON.parse(File.read(path)))
    rescue StandardError => e
      Rubbs.log('herald notes', "#{path}: #{e.class}: #{e.message}")
      nil
    end
  end
end
