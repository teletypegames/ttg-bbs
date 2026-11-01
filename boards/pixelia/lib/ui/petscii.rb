# frozen_string_literal: true

require_relative 'petscii/screen'
require_relative 'petscii/gallery'
require_relative 'petscii/canvas'
require_relative 'petscii/wall'
require_relative 'logo'

module UI
  # The board on a Commodore 64: PETSCII on a 40×25 screen. A cursor menu,
  # the 16colo.rs gallery in numbered cursor lists and pages of 40 columns, the
  # shared canvas, which is the C64's own screen size, and the Wall.
  module Petscii
    # PIXELIA in reversed blocks, five rows, a colour a letter.
    def self.logo
      Logo.rows.map do |runs|
        line = runs.map do |text, color|
          blocks = text.gsub(/#+/) { |run| "#{RV}#{' ' * run.size}#{RO}" }.tr('.', ' ')
          color ? "#{Pen::CODES[color]}#{blocks}" : blocks
        end
        "      #{line.join}#{LG}"
      end
    end

    def self.masthead
      rule = " #{DG}#{'─' * (COLS - 2)}#{LG}"
      [rule, '', *logo, '', rule,
       "  #{WH}the petscii & ansi art gallery#{LG}", "  #{GR}classic 8-bit art and a canvas for all#{LG}", rule]
    end

    def self.flow(bbs)
      BBS::Flow.define do
        call do |ctx, runner|
          Board.new(bbs, Screen.new(runner.session), ctx[:session_id] || runner.session.session_id).run
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
      screen.puts " #{PU}#{RV}#{' thanks for calling pixelia bbs'.ljust(39)}#{RO}#{LG}"
      screen.puts
      screen.say('More of us: teletypegames.org', GR)
      screen.puts
      sleep 1.2
      screen.puts " #{LG}+++"
      sleep 0.6
      screen.puts ' ATH0'
      sleep 0.4
      screen.puts " #{RD}NO CARRIER#{LG}"
      screen.puts
    end

    # One call: the menu and its sections.
    class Board
      HELP = [
        " #{WH}pixelia#{LG} is an art board of teletype games.", '',
        " #{YE}1#{LG} the ansi gallery: the 16colo.rs archive, year by year, pack by pack. A piece shows 40 " \
        'columns at a time: R shows the next 40 columns of a wider one.', '',
        " #{YE}2#{LG} the canvas: one 40×25 picture that every caller paints on, from a c64 or a modern " \
        'terminal, and both see it the same.', '',
        " #{YE}3#{LG} the wall: the pictures saved from the canvas.", '',
        " #{GR}telnet pixelia on a modern terminal for the full-colour 80 column gallery.#{LG}"
      ].freeze

      def initialize(bbs, screen, session_id)
        @bbs        = bbs
        @screen     = screen
        @session_id = session_id
      end

      def run
        loop do
          @screen.cls
          @screen.puts
          Petscii.masthead.each { |l| @screen.puts l }
          @screen.puts
          items   = menu_items
          @choice = @screen.menu(items, index: items.index { |i| i.value == @choice }, back: 'q',
                                        hint: 'crsr: choose  return: take')
          case @choice
          when '1' then Gallery.new(@bbs.gallery, @screen).run
          when '2' then Canvas.new(@bbs, @screen, @session_id).run
          when '3' then Wall.new(@bbs.wall, @screen).run
          when 'h' then @screen.page('PIXELIA BBS', HELP)
          when 'q' then return
          end
        end
      end

      private

      def menu_items
        [item("the ansi gallery #{GR}16colo.rs#{LG}", '1', 'the 16colo.rs archive, year by year'),
         item("the canvas #{GR}#{@bbs.canvas.painters} painting now#{LG}", '2', 'one picture, every caller paints on it'),
         item("the wall #{GR}#{@bbs.wall.all.size} works#{LG}", '3', 'the pictures saved from the canvas'),
         item('help', 'h', 'how the board works'),
         item('log off', 'q', 'hang up. see you!')]
      end

      def item(label, key, about) = BBS::Selector.item(label, key: key, value: key, about: about)
    end
  end
end
