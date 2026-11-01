# frozen_string_literal: true

require 'bbs'
require_relative 'commodore/basic'

# The Commodore doors: a C64 and a Plus/4 at their READY. prompt, with a
# BASIC to type into and a disk drive that holds our games for that machine.
# LOAD"$",8 and LIST show the disk; LOAD"NAME",8 and RUN show the game, with
# the catalog link to play it in a browser or download it.
module Commodore
  Machine = Struct.new(:platform, :boot, :colors, :reset_address, :basic35, :disk, keyword_init: true)

  BLUE_SCREEN = "\e[0;94;44m"
  GREY_SCREEN = "\e[0;30;47m"

  C64 = Machine.new(
    platform:      'c64',
    boot:          ['', '    **** COMMODORE 64 BASIC V2 ****', '', ' 64K RAM SYSTEM  38911 BASIC BYTES FREE'],
    colors:        { base: "\e[94;44m", text: BLUE_SCREEN, bright: "\e[0;97;44m", accent: BLUE_SCREEN,
                     error: BLUE_SCREEN, dim: "\e[0;37;44m", prompt: BLUE_SCREEN },
    reset_address: 64_738,
    basic35:       false,
    disk:          '"TELETYPE GAMES  " TT 2A'
  ).freeze

  PLUS4 = Machine.new(
    platform:      'plus4',
    boot:          ['', 'COMMODORE BASIC V3.5 60671 BYTES FREE', '3-PLUS-1 ON KEY F1'],
    colors:        { base: "\e[30;47m", text: GREY_SCREEN, bright: GREY_SCREEN, accent: GREY_SCREEN,
                     error: GREY_SCREEN, dim: "\e[0;90;47m", prompt: GREY_SCREEN },
    reset_address: nil,
    basic35:       true,
    disk:          '"TELETYPE GAMES  " TT 3D'
  ).freeze

  # A FakeOS definition for +machine+. +games+ is the catalog (GamesService),
  # +sizes+ the WarpSizes, for the size of each program on the disk.
  def self.os(machine, games:, sizes:)
    BBS::FakeOS.define do
      name   machine.platform
      prompt ''
      colors machine.colors

      boot do
        ctx[:commodore] = Shell.new(self, machine, games: games, sizes: sizes)
        ctx[:commodore].power_on
      end

      on_unknown { |input, io| io.ctx[:commodore].enter(input) }
    end
  end

  # One power-on of the machine: the screen, the BASIC and the disk.
  class Shell
    WIDTH = 40
    BLOCK = 254
    DISK_BLOCKS = 664

    def initialize(io, machine, games:, sizes:)
      @io      = io
      @machine = machine
      @games   = games
      @sizes   = sizes
      @column  = 0
      @basic   = Basic.new(screen, reset_address: machine.reset_address)
    end

    def power_on
      @io.cls
      @column = 0
      @machine.boot.each { |line| say(line) }
      say('')
      @io.puts '(LOAD"$",8 THEN LIST: OUR GAMES. EXIT: BACK TO THE BBS)', style: :dim
      ready
    end

    def enter(input)
      case input
      when /\A\s*(EXIT|QUIT|BYE)\s*\z/i then @io.halt
      when /\A\s*LOAD\b/i then load(input)
      when /\A\s*DLOAD\b/i
        @machine.basic35 ? load(input.sub(/DLOAD/i, 'LOAD')) : basic(input)
      when /\A\s*DIRECTORY\s*\z/i
        @machine.basic35 ? directory_listing : basic(input)
      else basic(input)
      end
    end

    private

    def basic(input)
      @basic.enter(input)
      ready unless input.match?(/\A\s*\d/)
    rescue Basic::Reset
      power_on
    end

    def ready = say('READY.')

    def say(text)
      write(text)
      newline
    end

    # ── the disk ───────────────────────────────────────────────────────────

    def load(input)
      m = input.match(/\A\s*LOAD\s*(?:"([^"]*)"?)?\s*(?:,\s*(\d+))?\s*(?:,\s*\d+)?\s*\z/i)
      return basic(input) unless m

      name = m[1].to_s.upcase
      if name.empty?
        say('?MISSING FILE NAME  ERROR')
        return ready
      end
      say("SEARCHING FOR #{name}")
      @io.pause(0.6)
      if name == '$'
        say('LOADING')
        @basic.load(directory)
      elsif (game = find(name))
        say('LOADING')
        @io.pause(0.8)
        @basic.load(program_for(game))
      else
        say('?FILE NOT FOUND  ERROR')
      end
      ready
    end

    def directory_listing
      directory.each { |n, text| say("#{n} #{text}") }
      ready
    end

    def disk_games
      @games.by_platform(@machine.platform).select(&:released?)
    end

    def find(pattern)
      disk_games.find { |g| File.fnmatch(pattern, file_name(g)) || File.fnmatch(pattern, g.title.upcase) }
    end

    def file_name(game) = game.name.upcase.tr('_', '-')[0, 16]

    def directory
      entries = disk_games.map do |game|
        name = file_name(game)
        [blocks(game), "#{' ' * [3 - blocks(game).to_s.length, 0].max}\"#{name}\"#{' ' * (16 - name.length)} PRG"]
      end
      used = entries.sum(&:first)
      [[0, @machine.disk], *entries, [[DISK_BLOCKS - used, 0].max, 'BLOCKS FREE.']]
    end

    def blocks(game)
      prg  = game.assets.find { |a| a.path.end_with?('.prg') }
      size = prg && @sizes.of(File.basename(prg.path))
      size ? (size.to_f / BLOCK).ceil : 1
    end

    # The game as a BASIC program: LIST shows it, RUN prints it.
    def program_for(game)
      lines = ["REM *** #{file_name(game)} #{game.version} ***", 'PRINT CHR$(147)', print_line(game.title.upcase),
               print_line(version_line(game)), 'PRINT', *wrap(game.desc).map { |l| print_line(l) }, 'PRINT',
               print_line('PLAY IT IN A BROWSER OR DOWNLOAD IT:'),
               *wrap(@games.catalog_url(game).sub(%r{\Ahttps?://}, '')).map { |l| print_line(l) }, 'END']
      lines.each_with_index.map { |text, i| [(i + 1) * 10, text] }
    end

    def version_line(game)
      date = game.released_at&.strftime('%Y-%m-%d')
      "VERSION #{game.version}#{" (#{date})" if date}"
    end

    def print_line(text) = %(PRINT "#{text.delete('"')}")

    def wrap(text) = BBS::FrameBuffer.wrap_ansi(text.to_s.tr('"', "'"), WIDTH - 2)

    # ── the screen, 40 columns wide ────────────────────────────────────────

    def screen
      Basic::Screen.new(
        write:    ->(text) { write(text) },
        newline:  -> { newline },
        column:   -> { @column },
        cls:      -> { @io.cls; @column = 0 },
        readline: -> { @io.session.readline.tap { @column = 0 } },
        stop?:    -> { key_pressed? }
      )
    end

    def write(text)
      text.to_s.split(/([\n\f])/).each do |part|
        case part
        when "\n" then newline
        when "\f" then @io.cls; @column = 0
        else
          until part.empty?
            room = WIDTH - @column
            chunk = part[0, room]
            @io.print(chunk, newline: 0)
            @column += chunk.length
            part = part[chunk.length..]
            newline if @column >= WIDTH
          end
        end
      end
    end

    def newline
      @io.newline
      @column = 0
      sleep 0.004
    end

    # RUN/STOP: any key, or a hang-up, breaks a running program.
    def key_pressed?
      key = @io.session.readkey(timeout: 0)
      key != :idle
    rescue IOError, SystemCallError
      true
    end
  end
end
