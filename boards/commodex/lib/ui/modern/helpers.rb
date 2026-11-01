# frozen_string_literal: true

module UI
  module Modern
    # The helpers of the Application: the search, the lists of games, a
    # game's about page and tips, and the desktop.
    module Helpers
      HELP = 'F2 search · F3 random game · F10 menu: years, genres, companies, tips'

      def catalog = services[:catalog]

      def tip_service = services[:tips]

      # Who a tip is counted for: the caller's address, not the session.
      def caller_key = BBS::RateLimit.caller_key(session)

      def search
        BBS::Dialogs.input(self, prompt: 'Part of a game title:', title: ' Search ', width: 60,
                                 on_submit: ->(text) { find(text) unless text.strip.empty? })
      end

      def find(query)
        games = catalog.search(query)
        return note(Words.search(games, query), ' Search ') unless games.is_a?(Array) && games.any?

        open_window(:games, title: " Search: #{query.strip} ", games: games)
      end

      def random = open_window(:games, title: ' Random game ', games: [catalog.random])

      def years = open_window(:groups, title: ' Years ', kind: :year, groups: catalog.years)

      def genres = open_window(:groups, title: ' Genres ', kind: :genre, groups: catalog.genres)

      def companies = open_window(:letters)

      def with_tips
        games = tip_service.games_with_tips
        return note('No game has an approved tip yet. Be the first!', ' Tips ') if games.empty?

        open_window(:games, title: ' Games with tips ', games: games)
      end

      # The games of a year, a genre or a company.
      def games_of(kind, name)
        case kind
        when :year  then catalog.in_year(name)
        when :genre then catalog.of_genre(name)
        else catalog.of_company(name)
        end
      end

      def open_group(kind, name) = open_window(:games, title: " #{name} ", games: games_of(kind, name))

      def open_letter(letter)
        open_window(:groups, title: " Companies: #{letter.upcase} ", kind: :company, groups: catalog.companies(letter))
      end

      def about(game)
        found = with_loading('Asking Wikipedia…') { services[:about].summary(game) }
        return note(Words.about(found), ' About ') if found.is_a?(Symbol)

        open_window(:about, game: game, summary: found)
      end

      def tips(game) = open_window(:tips, game: game, tips: tip_service.tips(game))

      def add_tip(game) = open_window(:add_tip, game: game)

      def note(text, title) = BBS::Dialogs.message(self, text, title: title, width: 64)

      def selected(window) = window.list_widget.selected_item

      def wrap(text, width) = BBS::FrameBuffer.wrap_ansi(text.to_s, width)

      def about_width = [cols - 4, 78].min

      def status_text = "#{catalog.count} games │ #{Time.now.strftime('%H:%M')}"

      # The desktop: the logo, the tagline, the keys, then the search.
      def desktop
        mark = ((cols - Logo.half_blocks.first.length) / 2) + 1
        Logo.half_blocks.each_with_index { |row, i| desktop_label(row, :accent, mark, 2 + i, row.length) }
        desktop_label("─── #{Words::TAGLINE} ───", :text_dim, 1, 6, cols, align: :center)
        desktop_label(HELP, :text_dim, 1, rows - 2, cols, align: :center)
        statusbar.right_text = status_text
        search
      end

      def desktop_label(text, style, x, y, width, align: :left)
        label = BBS::Widgets::Label.new(text: text, align: align, style_key: style)
        label.layout(x, y, width, 1)
        add(label)
      end
    end
  end
end
