# frozen_string_literal: true

require_relative 'c64/screen'
require_relative 'c64/board'
require_relative 'c64/messages'
require_relative 'c64/content'
require_relative 'c64/people'

module UI
  # The board on a Commodore 64: PETSCII on a 40×25 screen, single-key
  # menus and numbered lists, the way the C64 boards of the eighties were.
  # It works on the same TeletypeBBS as the modern face.
  module C64
    LOGO_FONT = {
      'T' => %w[### .#. .#. .#. .#.], 'E' => %w[### #.. ##. #.. ###], 'L' => %w[#.. #.. #.. #.. ###],
      'Y' => %w[#.# #.# .#. .#. .#.], 'P' => %w[##. #.# ##. #.. #..]
    }.freeze
    LOGO_COLORS = [CY, CY, LB, LB, "\e[0;34m"].freeze

    # TELETYPE in reversed blocks, five rows.
    def self.logo
      5.times.map do |row|
        bits = 'TELETYPE'.chars.map { |c| LOGO_FONT[c][row] }.join('.')
        line = bits.gsub(/#+/) { |run| "#{RV}#{' ' * run.size}#{RO}" }.tr('.', ' ')
        "    #{LOGO_COLORS[row]}#{line}#{LG}"
      end
    end

    def self.flow(bbs)
      BBS::Flow.define do
        # The board's face, the name and the password.
        call do |ctx, runner|
          screen = Screen.new(runner.session)
          ctx[:call_started] = Time.now
          ctx[:lang] = 'en'
          ctx[:authenticated] = false
          screen.cls
          screen.puts
          C64.logo.each { |l| screen.puts l }
          screen.puts
          screen.puts "  #{WH}teletype bbs#{LG}, the c64 side"
          screen.puts "  #{GR}caller ##{bbs.last_callers.caller_number}, #{bbs.online.count} on line#{LG}"
          screen.puts
          name = AccountService.normalize_name(screen.ask("  #{WH}name#{LG} (return: anonymous)\r\n  > ", max: 20))
          ctx[:username] = name
          if bbs.accounts.registered?(name)
            3.times do
              password = screen.ask("  #{WH}password#{LG}: ", mask: '*')
              if bbs.accounts.authenticate(name, password)
                ctx[:authenticated] = true
                break
              end
              sleep 2
              screen.puts "  #{RD}wrong password.#{LG}"
            end
            unless ctx[:authenticated]
              screen.say("#{name} is a registered name. Call again, or use another name.", RD)
              next :halt
            end
          end
          bbs.start_call(ctx[:session_id], name, listed: true)
          nil
        end
        # The logon sequence: who is calling, then the scans of the old boards.
        call do |ctx, runner|
          screen = Screen.new(runner.session)
          s = bbs.logon_summary(ctx[:username], registered: ctx[:authenticated], session_id: ctx[:session_id])
          ctx[:caller_number] = s[:caller_number]
          screen.title('TELETYPE BBS', s[:node] ? "node #{s[:node]}" : '')
          screen.puts
          screen.say(s[:stats] ? "Welcome back, #{s[:name]}!" : "Welcome, #{s[:name]}! Your first call here.", WH)
          screen.puts " #{GR}you are caller ##{s[:caller_number]}#{LG}"
          if s[:stats]
            screen.puts " #{GR}calls: #{s[:stats].calls}, last on #{s[:stats].last_call.localtime.strftime('%Y-%m-%d')}#{LG}"
          end
          unless s[:registered]
            screen.say(
s[:name] == AccountService::ANONYMOUS ? 'Call with a name to keep one.' : 'A guest: S, then R keeps your name.', GR)
          end
          screen.puts
          C64.scan(screen, 'mailbox', s[:mail].nil? ? "#{DG}register for mail" : "#{s[:mail]} new letter#{'s' if s[:mail] != 1}")
          C64.scan(screen, 'message bases',
                   if s[:new_scan].nil? then "#{DG}register to track"
                   elsif s[:new_scan].empty? then 'nothing new'
                   else s[:new_scan].map { |b, n| "#{b.title} #{n}" }.join(', ')
                   end)
          C64.scan(screen, 'voting booth',
s[:polls_open].zero? ? 'all voted' : "#{s[:polls_open]} poll#{'s' if s[:polls_open] != 1} open")
          C64.scan(screen, 'new files', s[:new_files].empty? ? 'none this month' : s[:new_files].first)
          screen.puts
          screen.puts " #{CY}quote of the day#{LG}"
          text, who = s[:quote]
          screen.say("\"#{text}\"#{" - #{who}" if who}", WH)
          screen.pause('return: enter the board')
          nil
        end
        call do |ctx, runner|
          Board.new(bbs, Screen.new(runner.session), ctx).run
          nil
        end
        call do |ctx, runner|
          C64.goodbye(Screen.new(runner.session), name: ctx[:username] || AccountService::ANONYMOUS,
                                                  seconds: Time.now - (ctx[:call_started] || Time.now),
                                                  caller_number: ctx[:caller_number], quote: bbs.taglines.pick)
          nil
        rescue IOError, Errno::EPIPE, Errno::ECONNRESET
          nil
        end
      end
    end

    def self.scan(screen, label, result)
      screen.write " #{GR}#{label} #{DG}#{'.' * (15 - label.length)}#{LG} "
      sleep 0.25
      screen.puts "#{YE}#{BBS::FrameBuffer.clip_ansi(result.to_s, 21)}#{LG}"
    end

    def self.goodbye(screen, name:, seconds:, caller_number:, quote:)
      screen.cls
      screen.puts
      screen.puts " #{CY}#{RV}#{" thanks for calling, #{name}".ljust(39)[0, 39]}#{RO}#{LG}"
      screen.puts
      minutes = (seconds / 60).to_i
      screen.puts " #{GR}caller ##{caller_number}, on line #{minutes.positive? ? "#{minutes}m" : "#{seconds.to_i}s"}#{LG}"
      screen.puts
      text, who = quote
      screen.say("...\"#{text}\"#{" - #{who}" if who}", WH)
      screen.puts
      screen.puts " #{GR}our games:#{LG}"
      screen.puts " #{CY}teletypegames.org#{LG}"
      screen.puts " #{GR}every file on plain http:#{LG}"
      screen.puts " #{CY}archive.teletypegames.org#{LG}"
      screen.puts
      sleep 1.2
      screen.puts " #{LG}+++"
      sleep 0.6
      screen.puts ' ATH0'
      sleep 0.4
      screen.puts " #{RD}NO CARRIER#{LG}"
      screen.puts
    end
  end
end
