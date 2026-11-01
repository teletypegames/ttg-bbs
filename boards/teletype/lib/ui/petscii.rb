# frozen_string_literal: true

require_relative 'wording'
require_relative 'petscii/screen'
require_relative 'petscii/board'
require_relative 'petscii/messages'
require_relative 'petscii/content'
require_relative 'petscii/people'
require_relative 'petscii/more'
require_relative 'petscii/clubhouse'

module UI
  # The board on a Commodore 64: PETSCII on a 40×25 screen, single-key
  # menus and numbered lists, the way the C64 boards of the eighties were.
  # It works on the same TeletypeBBS as the modern face.
  module Petscii
    def self.flow(bbs)
      BBS::Flow.define do
        call { |ctx, runner| Petscii.entrance(bbs, ctx, runner) }
        call { |ctx, runner| Petscii.logon(bbs, ctx, runner) }
        call do |ctx, runner|
          Board.new(bbs, Screen.new(runner.session), ctx).run
          nil
        end
        call { |ctx, runner| Petscii.leaving(bbs, ctx, runner) }
      end
    end

    # The entrance of the clubhouse: the name and the password go into the
    # guestbook. :halt when the caller does not get in.
    def self.entrance(bbs, ctx, runner)
      screen = Screen.new(runner.session)
      ctx[:call_started]  = Time.now
      ctx[:authenticated] = false
      ctx[:caller_key]    = BBS::RateLimit.caller_key(runner.session)
      door = Clubhouse::Entrance.new(screen, bbs)
      door.show
      typed = door.ask_name
      ctx[:plain] = capitals?(typed)
      log_on(bbs, ctx, screen, door, AccountService.normalize_name(typed))
    end

    def self.log_on(bbs, ctx, screen, door, name)
      ctx[:username] = name
      result = bbs.accounts.log_on(name, caller_key: ctx[:caller_key]) do |again|
        door.wrong('WRONG PASSWORD.') if again
        door.ask_password
      end
      ctx[:authenticated] = result == :ok
      return turned_away(screen, name, result) unless %i[ok guest].include?(result)

      bbs.start_call(ctx[:session_id], name, listed: true)
      nil
    end

    def self.turned_away(screen, name, result)
      Clubhouse.text_mode(screen.session)
      screen.cls
      screen.say(Wording.turned_away(name, result), RD)
      :halt
    end

    # The logon sequence: who is calling, then the scans of the old boards.
    def self.logon(bbs, ctx, runner)
      Clubhouse.text_mode(runner.session)
      screen = Screen.new(runner.session)
      s = bbs.logon_summary(ctx[:username], registered: ctx[:authenticated], session_id: ctx[:session_id])
      ctx[:caller_number] = s[:caller_number]
      welcome(screen, s)
      scans(screen, s)
      quote(screen, s[:quote])
      screen.pause('return: enter the board')
      nil
    end

    def self.welcome(screen, s)
      screen.title('TELETYPE BBS', s[:node] ? "node #{s[:node]}" : '')
      screen.puts
      screen.say(s[:stats] ? "Welcome back, #{s[:name]}!" : "Welcome, #{s[:name]}! Your first call here.", WH)
      screen.puts " #{GR}you are caller ##{s[:caller_number]}#{LG}"
      if s[:stats]
        screen.puts " #{GR}calls: #{s[:stats].calls}, last on #{s[:stats].last_call.localtime.strftime('%Y-%m-%d')}#{LG}"
      end
      return if s[:registered]

      screen.say(s[:name] == AccountService::ANONYMOUS ? 'Call with a name to keep one.' : 'A guest: S, then R keeps your name.',
                 GR)
    end

    def self.scans(screen, s)
      screen.puts
      scan(screen, 'mailbox', s[:mail].nil? ? "#{DG}register for mail" : "#{s[:mail]} new letter#{'s' if s[:mail] != 1}")
      scan(screen, 'message bases', new_posts(s[:new_scan]))
      scan(screen, 'voting booth',
           s[:polls_open].zero? ? 'all voted' : "#{s[:polls_open]} poll#{'s' if s[:polls_open] != 1} open")
    end

    def self.new_posts(new_scan)
      if new_scan.nil? then "#{DG}register to track"
      elsif new_scan.empty? then 'nothing new'
      else new_scan.map { |b, n| "#{b.title} #{n}" }.join(', ')
      end
    end

    def self.quote(screen, quote)
      screen.puts
      screen.puts " #{CY}quote of the day#{LG}"
      text, who = quote
      screen.say("\"#{text}\"#{" - #{who}" if who}", WH)
    end

    def self.leaving(bbs, ctx, runner)
      goodbye = ctx[:plain] ? method(:goodbye) : Clubhouse::Leaving.method(:play)
      goodbye.call(ctx[:plain] ? Screen.new(runner.session) : runner.session,
                   name: ctx[:username] || AccountService::ANONYMOUS,
                   seconds: Time.now - (ctx[:call_started] || Time.now),
                   caller_number: ctx[:caller_number], quote: bbs.taglines.pick)
      nil
    rescue IOError, Errno::EPIPE, Errno::ECONNRESET
      nil
    end

    # Whether a name came in capitals only: UltimateTerm in its ANSI mode
    # swaps the case of what is typed (and cannot show the graphics), so its
    # caller gets the text menu.
    def self.capitals?(text) = text.to_s.count('A-Z') >= 2 && !text.to_s.match?(/[a-z]/)

    def self.scan(screen, label, result)
      screen.write " #{GR}#{label} #{DG}#{'.' * (15 - label.length)}#{LG} "
      sleep 0.25
      screen.puts "#{YE}#{BBS::FrameBuffer.clip_ansi(result.to_s, 21)}#{LG}"
    end

    # The C64's goodbye (BBS::Goodbye): the caller's number and time on
    # line, a quote, and where to find us.
    def self.goodbye(screen, name:, seconds:, caller_number:, quote:)
      BBS::Goodbye.petscii(screen, bar: "thanks for calling, #{name}") do |s|
        minutes = (seconds / 60).to_i
        s.puts " #{GR}caller ##{caller_number}, on line #{minutes.positive? ? "#{minutes}m" : "#{seconds.to_i}s"}#{LG}"
        s.puts
        text, who = quote
        s.say("...\"#{text}\"#{" - #{who}" if who}", WH)
        s.puts
        s.puts " #{GR}our games:#{LG}"
        s.puts " #{CY}teletypegames.org#{LG}"
        s.puts " #{GR}every board of ours, one port:#{LG}"
        s.puts " #{CY}teletypegames.org:2399#{LG}"
      end
    end
  end
end
