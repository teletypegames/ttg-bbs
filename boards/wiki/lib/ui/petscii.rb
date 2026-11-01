# frozen_string_literal: true

require_relative 'logo'
require_relative 'petscii/screen'
require_relative 'petscii/browser'

module UI
  # The wiki on a Commodore 64: PETSCII on a 40×25 screen, the page tree as
  # numbered cursor menus, the pages as screenfuls of text that wait for RETURN.
  module Petscii
    LOGO_COLORS = [CY, CY, LB, LB, "\e[0;34m"].freeze

    # TTG WIKI in reversed blocks, five rows.
    def self.logo
      Logo.rows.each_with_index.map do |bits, row|
        line = bits.gsub(/#+/) { |run| "#{RV}#{' ' * run.size}#{RO}" }.tr('.', ' ')
        "  #{LOGO_COLORS[row]}#{line}#{LG}"
      end
    end

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
      screen.cls
      screen.puts
      screen.puts " #{CY}#{RV}#{' thanks for calling the ttg wiki'.ljust(39)}#{RO}#{LG}"
      screen.puts
      minutes = (seconds / 60).to_i
      screen.puts " #{GR}on line #{minutes.positive? ? "#{minutes}m" : "#{seconds.to_i}s"}#{LG}"
      screen.puts
      screen.puts " #{GR}the wiki on the web:#{LG}"
      screen.puts " #{CY}#{Browser::PUBLIC_HOST}#{LG}"
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
