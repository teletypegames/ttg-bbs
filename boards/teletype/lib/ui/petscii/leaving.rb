# frozen_string_literal: true

module UI
  class Petscii
    # Leaving the clubhouse: its lamps going out (Clubhouse::Leaving), or
    # for the menu of text the C64's goodbye (BBS::Goodbye) with the
    # caller's number and time on line, a quote, and where to find us.
    module Leaving
      def self.play(face)
        seconds = Time.now - (face.context[:call_started] || Time.now)
        number  = face.context[:caller_number]
        quote   = face.board.taglines.pick
        if face.context[:plain]
          goodbye(face.screen, face.name, seconds, number, quote)
        else
          Clubhouse::Leaving.play(face.session, name: face.name, seconds: seconds, caller_number: number, quote: quote)
        end
      end

      def self.goodbye(screen, name, seconds, caller_number, quote)
        BBS::Goodbye.petscii(screen, bar: "thanks for calling, #{name}") do |s|
          minutes = (seconds / 60).to_i
          s.puts " #{GR}caller ##{caller_number}, on line #{minutes.positive? ? "#{minutes}m" : "#{seconds.to_i}s"}#{LG}"
          s.puts
          text, who = quote
          s.say("...\"#{text}\"#{" - #{who}" if who}", color: WH)
          s.puts
          s.puts " #{GR}our games:#{LG}"
          s.puts " #{CY}teletypegames.org#{LG}"
          s.puts " #{GR}every board of ours, one port:#{LG}"
          s.puts " #{CY}teletypegames.org:2399#{LG}"
        end
      end
    end
  end
end
