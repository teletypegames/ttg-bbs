# frozen_string_literal: true

require_relative 'c64/screen'
require_relative 'c64/browser'

module UI
  # The wiki on a Commodore 64: PETSCII on a 40×25 screen, the page tree as
  # numbered lists, the pages as screenfuls of text that wait for RETURN.
  module C64
    LOGO_FONT = {
      'T' => %w[### .#. .#. .#. .#.], 'G' => %w[### #.. #.# #.# ###],
      'W' => %w[#...# #...# #.#.# ##.## #...#], 'I' => %w[### .#. .#. .#. ###],
      'K' => %w[#.# #.# ##. #.# #.#]
    }.freeze
    LOGO_COLORS = [CY, CY, LB, LB, "\e[0;34m"].freeze

    # TTG WIKI in reversed blocks, five rows.
    def self.logo
      5.times.map do |row|
        bits = %w[TTG WIKI].map { |word| word.chars.map { |c| LOGO_FONT[c][row] }.join('.') }.join('...')
        line = bits.gsub(/#+/) { |run| "#{RV}#{' ' * run.size}#{RO}" }.tr('.', ' ')
        "  #{LOGO_COLORS[row]}#{line}#{LG}"
      end
    end

    def self.flow(wiki)
      BBS::Flow.define do
        call do |ctx, runner|
          screen = Screen.new(runner.session)
          ctx[:call_started] = Time.now
          screen.cls
          screen.puts
          C64.logo.each { |l| screen.puts l }
          screen.puts
          screen.puts "  #{WH}the teletype games wiki#{LG}, c64 side"
          screen.puts "  #{GR}#{wiki.pages.size} pages indexed#{LG}"
          screen.puts
          screen.say('Pick a page by its number, RETURN pages on, Q goes back. Pages marked * are private.', GR)
          screen.pause('return: enter the wiki')
          Browser.new(wiki, screen, ctx).run
          C64.goodbye(screen, seconds: Time.now - ctx[:call_started])
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
