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
    def self.logo = BBS::BlockFont.petscii(Logo::WORD, colors: LOGO_COLORS, indent: 4)

    def self.masthead(count)
      rule = " #{DG}#{'─' * (COLS - 2)}#{LG}"
      [rule, '', *logo, '', rule,
       "  #{WH}#{Words::TAGLINE.downcase}#{LG}", "  #{GR}#{count} games, cheats and tips#{LG}", rule]
    end

    def self.flow(bbs)
      BBS::Flow.define do
        call do |_ctx, runner|
          Board.new(bbs, Screen.new(runner.session), caller_key: BBS::RateLimit.caller_key(runner.session)).run
          nil
        end
        call do |_ctx, runner|
          BBS::Goodbye.petscii(Screen.new(runner.session), title: 'commodex bbs', color: LB,
                                                            note: 'Games from wikidata.org (cc0), stories from ' \
                                                                  'wikipedia.org (cc by-sa).')
          nil
        rescue IOError, Errno::EPIPE, Errno::ECONNRESET
          nil
        end
      end
    end
  end
end
