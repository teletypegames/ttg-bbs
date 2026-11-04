# frozen_string_literal: true

module UI
  class Petscii
    # The logon sequence of a C64 call: who is calling, then the scans of
    # the old boards and the quote of the day.
    module Logon
      def self.show(face)
        Clubhouse.text_mode(face.session)
        s = face.board.logon_summary(face.name, registered: face.registered?, session_id: face.session_id)
        face.context[:caller_number] = s[:caller_number]
        welcome(face, s)
        scans(face, s)
        quote(face, s[:quote])
        face.pause('return: enter the board')
      end

      def self.welcome(face, s)
        face.title('TELETYPE BBS', s[:node] ? "node #{s[:node]}" : '')
        face.puts
        face.say(s[:stats] ? "Welcome back, #{s[:name]}!" : "Welcome, #{s[:name]}! Your first call here.", color: WH)
        face.puts " #{GR}you are caller ##{s[:caller_number]}#{LG}"
        if s[:stats]
          face.puts " #{GR}calls: #{s[:stats].calls}, last on #{s[:stats].last_call.localtime.strftime('%Y-%m-%d')}#{LG}"
        end
        return if s[:registered]

        face.say(
          s[:name] == AccountService::ANONYMOUS ? 'Call with a name to keep one.' : 'A guest: S, then R keeps your name.',
          color: GR
        )
      end

      def self.scans(face, s)
        face.puts
        scan(face, 'mailbox', s[:mail].nil? ? "#{DG}register for mail" : "#{s[:mail]} new letter#{'s' if s[:mail] != 1}")
        scan(face, 'message bases', new_posts(s[:new_scan]))
        scan(
          face,
          'voting booth',
          s[:polls_open].zero? ? 'all voted' : "#{s[:polls_open]} poll#{'s' if s[:polls_open] != 1} open"
        )
      end

      def self.new_posts(new_scan)
        if new_scan.nil? then "#{DG}register to track"
        elsif new_scan.empty? then 'nothing new'
        else new_scan.map { |b, n| "#{b.title} #{n}" }.join(', ')
        end
      end

      def self.quote(face, quote)
        face.puts
        face.puts " #{CY}quote of the day#{LG}"
        text, who = quote
        face.say("\"#{text}\"#{" - #{who}" if who}", color: WH)
      end

      def self.scan(face, label, result)
        face.write " #{GR}#{label} #{DG}#{'.' * (15 - label.length)}#{LG} "
        sleep 0.25
        face.puts "#{YE}#{BBS::FrameBuffer.clip_ansi(result.to_s, 21)}#{LG}"
      end
    end

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
