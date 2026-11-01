# frozen_string_literal: true

require_relative 'petscii/screen'
require_relative 'petscii/board'
require_relative 'logo'
require_relative 'words'

module UI
  # The board on a Commodore 64: PETSCII on a 40×25 screen. A cursor main
  # menu, the games as numbered cursor lists, a game on a page of its own
  # with its actions on one row, the Wikipedia lead and the tips as pages
  # that wait for RETURN, and a line for a search and for a new tip.
  module Petscii
    LOGO_COLORS = [LB, LB, CY, CY, WH].freeze

    # COMMODEX in reversed blocks, five rows.
    def self.logo
      Logo.rows.each_with_index.map do |line, row|
        blocks = line.gsub(/#+/) { |run| "#{RV}#{' ' * run.size}#{RO}" }.tr('.', ' ')
        "    #{LOGO_COLORS[row]}#{blocks}#{LG}"
      end
    end

    def self.masthead(count)
      rule = " #{DG}#{'─' * (COLS - 2)}#{LG}"
      [rule, '', *logo, '', rule,
       "  #{WH}#{Words::TAGLINE.downcase}#{LG}", "  #{GR}#{count} games, cheats and tips#{LG}", rule]
    end

    def self.flow(bbs)
      BBS::Flow.define do
        call do |ctx, runner|
          Board.new(bbs, Screen.new(runner.session), ctx).run
          nil
        end
        call do |_ctx, runner|
          Petscii.goodbye(Screen.new(runner.session))
          nil
        rescue IOError, Errno::EPIPE, Errno::ECONNRESET
          nil
        end
      end
    end

    def self.goodbye(screen)
      screen.cls
      screen.puts
      screen.puts " #{LB}#{RV}#{' thanks for calling commodex bbs'.ljust(39)}#{RO}#{LG}"
      screen.puts
      screen.say('Games from wikidata.org (cc0), stories from wikipedia.org (cc by-sa). More of us: teletypegames.org', GR)
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
