# frozen_string_literal: true

require_relative 'petscii/screen'
require_relative 'logo'
require_relative 'card'
require_relative 'petscii/reader'
require_relative 'petscii/library'

module UI
  # The library on a Commodore 64: PETSCII on a 40×25 screen, a cursor
  # menu, the series, their seasons and episodes as numbered lists, an
  # episode's card a page, and Memory Alpha's articles section by section.
  module Petscii
    LOGO_COLORS = [WH, LB, LB, CY, BL].freeze
    STARS       = "#{DG}  .    *        .     +     .     *   .#{LG}".freeze
    NOTE        = 'Articles from memory-alpha.fandom.com, under CC BY-NC.'

    def self.flow(bbs)
      BBS::Flow.define do
        call do |_ctx, runner|
          Library.new(bbs.catalog, bbs.library, Screen.new(runner.session)).run
          nil
        end
        call do |_ctx, runner|
          BBS::Goodbye.petscii(Screen.new(runner.session), title: 'starbase bbs', color: LB, note: NOTE)
          nil
        rescue IOError, Errno::EPIPE, Errno::ECONNRESET
          nil
        end
      end
    end

    def self.masthead
      ['', STARS, '', *Logo.petscii(LOGO_COLORS), '', STARS, '', "  #{WH}a star trek library on your commodore#{LG}"]
    end
  end
end
