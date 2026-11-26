# frozen_string_literal: true

module UI
  module Petscii
    module Views
      # The Trophy Room on a C64 (Trophies::Room): one screen of 40 by 25,
      # nothing to scroll or choose. The five most downloaded titles with
      # their bars, the downloads, the numbers, the team; the 40th column
      # stays empty. CRSR up goes to the tabs (the Frame), the hotkeys open
      # the other places.
      class TrophyView < Rubbs::Petscii::Kit::View
        # The keys on the hint bar.
        HINT = [['O', true], [' Own  ', false], ['T', true], [' Today  ', false], ['Y', true], [' You  ', false],
                ['←', true], [' Back  ', false], ['Q', true], [' Bye', false]].freeze
        # The column of a title, its cells, and of its engine.
        NAME = 3
        NAME_WIDTH = 16
        ENGINE = 20
        # The column of a bar, and its longest.
        BAR = 26
        BAR_WIDTH = 6
        # The last column a number reaches (the 40th cell is never printed).
        RIGHT = 37
        # The cells of a number in the lists of numbers.
        NUMBER = 6
        # The short names of the engines that are longer than five cells.
        ENGINES = {
          'electron'   => 'elec',
          'ebitengine' => 'ebit',
          'retroarch'  => 'retro',
          'batocera'   => 'bato',
          'phaser'     => 'phasr'
        }.freeze

        # [room] the Trophies::Room, or +nil+ when there is none yet
        def initialize(room)
          super()
          @room = room
        end

        # The Trophies::Room shown, or +nil+.
        attr_reader :room

        def section = :trophy

        def hint = HINT

        def draw(canvas)
          Layout.band(canvas, 'TROPHY ROOM', 'all time', Canvas::YELLOW)
          return polishing(canvas) unless @room&.ready?

          most_downloaded(canvas)
          heading(canvas, 10, 'BY THE NUMBERS')
          numbers.each_with_index { |parts, i| number(canvas, 11 + i, parts) }
          heading(canvas, 17, 'THE TEAM')
          number(canvas, 18, team)
          canvas.text(row(20), 1, credit, Canvas::DARK_GREY)
        end

        private

        def row(line) = Layout.row(line)

        def most_downloaded(canvas)
          heading(canvas, 2, 'MOST DOWNLOADED')
          @room.top.first(5).each_with_index { |entry, i| entry(canvas, 3 + i, i + 1, entry) }
          canvas.text(row(3), NAME, 'No downloads yet.', Canvas::GREY) if @room.top.empty?
          downloads(canvas, 8)
        end

        def polishing(canvas)
          canvas.text(row(2), 1, 'The trophies are being polished.', Canvas::YELLOW)
          canvas.text(row(3), 1, 'Please call again later.', Canvas::LIGHT_GREY)
        end

        def heading(canvas, line, title) = canvas.text(row(line), 1, title, Canvas::LIGHT_BLUE)

        def entry(canvas, line, rank, entry)
          r = row(line)
          canvas.text(r, 1, rank.to_s, Canvas::ORANGE)
          canvas.text(r, NAME, Layout.plain(entry.title)[0, NAME_WIDTH], Canvas::WHITE)
          canvas.text(r, ENGINE, engine(entry.engine), Canvas::GREY)
          canvas.text(r, BAR, ' ' * bar(entry.downloads), Canvas::LIGHT_GREEN, rvs: true)
          right(canvas, r, Trophies.number(entry.downloads), Canvas::WHITE)
        end

        def engine(name) = Layout.plain(ENGINES.fetch(name.to_s.downcase, name.to_s))[0, 5]

        def bar(downloads) = [(BAR_WIDTH * downloads / [@room.most, 1].max.to_f).round, 1].max

        def downloads(canvas, line)
          r = row(line)
          col = Layout.runs(canvas, r, 1, [[Trophies.number(@room.downloads), Canvas::WHITE], [' downloads', Canvas::LIGHT_GREY]])
          visitors = Trophies.number(@room.visitors)
          start = [RIGHT + 1 - visitors.length - ' visitors'.length, col + 2].max
          Layout.runs(canvas, r, start, [[visitors, Canvas::WHITE], [' visitors', Canvas::LIGHT_GREY]], limit: RIGHT + 1)
        end

        def right(canvas, row, text, color) = canvas.text(row, RIGHT + 1 - text.length, text, color)

        # Each line: the number, then the words after it ([text, number?]
        # each).
        def numbers
          green = @room.green_percent ? "#{@room.green_percent}%" : '-'
          [[@room.released, ['released of ', false], [Trophies.number(@room.titles), true], [' titles', false]],
           [@room.platforms, ['platforms  ', false], [Trophies.number(@room.categories), true], [' categories', false]],
           [@room.commits, ['commits, ', false], [Trophies.number(@room.repos), true], [' public repos', false]],
           [@room.boards, ['BBS boards, ', false], [Trophies.number(@room.accounts), true], [' accounts', false]],
           [@room.runs, ['CI runs, ', false], [green, true], [' green', false]]]
        end

        def team
          [@room.core, ['members, ', false], [Trophies.number(@room.candidates), true], [' candidates', false]]
        end

        def number(canvas, line, parts)
          value, *words = parts
          r = row(line)
          canvas.text(r, 1, Trophies.number(value).rjust(NUMBER), Canvas::WHITE)
          Layout.runs(canvas, r, NUMBER + 3, words.map { |t, n| [t, n ? Canvas::WHITE : Canvas::LIGHT_GREY] }, limit: RIGHT + 1)
        end

        def credit
          ago = Layout.age(@room.updated_at, Time.now.to_i)
          "Updated #{ago} ago  teletypegames.org"
        end
      end
    end
  end
end
