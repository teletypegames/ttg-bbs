# frozen_string_literal: true

require_relative 'petscii/screen'
require_relative 'petscii/browser'

module UI
  # The wiki on a Commodore 64: PETSCII on a 40×25 screen, the page tree as
  # numbered cursor menus, the pages as screenfuls of text that wait for RETURN.
  module Petscii
    LOGO_COLORS = [CY, CY, LB, LB, "\e[0;34m"].freeze

    # TTG WIKI in reversed blocks, five rows.
    def self.logo = BBS::BlockFont.petscii('TTG WIKI', colors: LOGO_COLORS, glyphs: BBS::BlockFont::WIDE_W, indent: 2)

    def self.flow(bbs)
      wiki = bbs.wiki
      BBS::Flow.define do
        call do |ctx, runner|
          screen = Screen.new(runner.session)
          ctx[:call_started] = Time.now
          screen.cls
          screen.puts
          Petscii.logo.each { |l| screen.puts l }
          screen.puts
          screen.puts "  #{WH}the teletype games wiki#{LG}, c64 side"
          screen.puts "  #{GR}#{wiki.pages.size} pages indexed#{LG}"
          screen.puts
          screen.say('CRSR and RETURN, or the number, opens a page; Q goes back. Pages marked * are private.', GR)
          screen.pause('return: enter the wiki')
          Browser.new(bbs, screen, ctx).run
          Petscii.goodbye(screen, seconds: Time.now - ctx[:call_started])
          nil
        rescue IOError, Errno::EPIPE, Errno::ECONNRESET
          :halt
        end
      end
    end

    def self.goodbye(screen, seconds:)
      minutes = (seconds / 60).to_i
      BBS::Goodbye.petscii(screen, title: 'the ttg wiki') do |s|
        s.puts " #{GR}on line #{minutes.positive? ? "#{minutes}m" : "#{seconds.to_i}s"}#{LG}"
        s.puts
        s.puts " #{GR}the wiki on the web:#{LG}"
        s.puts " #{CY}#{Browser::PUBLIC_HOST}#{LG}"
      end
    end
  end
end
