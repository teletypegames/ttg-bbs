# frozen_string_literal: true

module UI
  module Modern
    # The Trophy Room tab (Trophies::Room): the five most downloaded titles
    # on the left, the numbers on the right, the team under them; all time.
    # Nothing to choose: TAB and the arrows turn the tabs, the letters open
    # the others, Q hangs up.
    class TrophyRoom < Screen
      # The columns of the left side.
      LEFT = 40
      # The cells of the longest bar.
      BAR = 8
      # Seconds a room is kept before it is made again.
      KEEP = 30
      # Where the numbers come from.
      SOURCES = 'Downloads of teletypegames.org · Gitea · Authentik · Woodpecker · WarpEngine catalog'

      key(:tab, :right) { pages.switch }
      key(:left) { pages.switch(-1) }
      key('o', 'O') { pages.open_tab(:own) }
      key('d', 'D', 'g', 'G') { pages.open_tab(:discovery) }
      key('t', 'T') { pages.open_tab(:today) }
      key('w', 'W') { pages.open_tab(:wall) }
      key('f', 'F') { pages.open_tab(:feedback) }
      key('h', 'H') { pages.open_tab(:hunt) }
      key('a', 'A') { pages.profile }
      key(:escape, 'q', 'Q') { quit }

      # [source] answers the Trophies::Room now (or +nil+)
      def initialize(source)
        super()
        @source = source
      end

      def lines
        room = self.room
        lines = [*masthead(:trophy), '', title_line]
        return lines.push('', "#{YELLOW}The trophies are being polished. Please try again later.#{RESET}") unless room&.ready?

        lines.push(rule, '')
        lines.concat(width >= LEFT + 32 ? columns(downloads(room), numbers(room)) : [*downloads(room), '', *numbers(room)])
        lines.push('', rule, footer(room), hints)
      end

      private

      def room
        now = Time.now.to_i
        if @made_at.nil? || now - @made_at >= KEEP
          @made_at = now
          @room    = @source.call
        end
        @room
      rescue StandardError => e
        Rubbs.log('trophies', e)
        nil
      end

      def title_line
        left = 'TELETYPE GAMES · TROPHY ROOM'
        right = 'all time'
        "#{YELLOW}#{BOLD}#{left}#{RESET}#{' ' * [width - left.length - right.length, 1].max}#{DIM}#{right}#{RESET}"
      end

      def downloads(room)
        lines = ["#{look.accent}#{BOLD}MOST DOWNLOADED#{RESET}", '']
        room.top.each_with_index { |entry, i| lines << entry_line(entry, i + 1, room.most) }
        lines << "#{DIM}No downloads yet.#{RESET}" if room.top.empty?
        lines.push('', "#{BOLD}#{Trophies.number(room.downloads)}#{RESET}#{TEXT} downloads · " \
                       "#{RESET}#{BOLD}#{Trophies.number(room.visitors)}#{RESET}#{TEXT} visitors#{RESET}")
      end

      def entry_line(entry, rank, most)
        name = fit("#{entry.title} · #{entry.engine}", LEFT - BAR - 10)
        bar  = '█' * [(BAR * entry.downloads / [most, 1].max.to_f).round, 1].max
        "#{YELLOW}#{rank}.#{RESET} #{TEXT}#{name}#{RESET} #{GREEN}#{bar.ljust(BAR)}#{RESET} " \
          "#{BOLD}#{Trophies.number(entry.downloads).rjust(5)}#{RESET}"
      end

      def numbers(room)
        ["#{look.accent}#{BOLD}BY THE NUMBERS#{RESET}", '',
         number(room.released, "released of #{Trophies.number(room.titles)} titles"),
         number(room.platforms, "platforms · #{Trophies.number(room.categories)} categories"),
         number(room.commits, "commits in #{Trophies.number(room.repos)} public repos"),
         number(room.boards, "BBS boards · #{Trophies.number(room.accounts)} accounts"),
         number(room.runs, "CI runs · #{room.green_percent ? "#{room.green_percent}%" : '-'} green"),
         '', *team(room)]
      end

      def team(room)
        ["#{look.accent}#{BOLD}THE TEAM#{RESET}", '',
         number(room.core, "members · #{Trophies.number(room.candidates)} candidates")]
      end

      def number(value, words)
        "#{BOLD}#{Trophies.number(value).rjust(6)}#{RESET}  #{TEXT}#{fit(words, [width - LEFT - 10, 20].max).rstrip}#{RESET}"
      end

      def columns(left, right)
        (0...[left.size, right.size].max).map { |i| "#{pad_ansi(left[i].to_s, LEFT)}#{LINE}│#{RESET} #{right[i]}" }
      end

      def pad_ansi(text, size) = text + (' ' * [size - text.gsub(/\e\[[\d;]*m/, '').length, 0].max)

      def footer(room)
        ago = Rubbs::Petscii::Kit::Layout.age(room.updated_at, Time.now.to_i)
        "#{DIM}#{fit("#{SOURCES} · updated #{ago} ago", width)}#{RESET}"
      end

      def hints
        "#{DIM}TAB tabs  O own  T today  H hunt  W wall  F feedback  A profile  Q hang up#{RESET}"
      end
    end
  end
end
