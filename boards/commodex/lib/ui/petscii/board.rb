# frozen_string_literal: true

module UI
  module Petscii
    # One call: the main menu, the lists, the game pages, the tips.
    class Board
      MENU = [['s', 'search titles', 'a part of a title finds the game'],
              ['y', 'browse by year', 'the games of one year'],
              ['g', 'browse by genre', 'shoot-em-ups, platformers, sports'],
              ['c', 'publishers & developers', 'the games of one company'],
              ['r', 'random game', 'a game picked at random'],
              ['t', 'games with tips', 'the games callers left tips for'],
              ['i', 'about commodex bbs', 'where the games come from'],
              ['q', 'log off', 'hang up. see you!']].freeze
      MENU_ITEMS = MENU.map { |key, label, about| BBS::Selector.item(label, key: key, value: key, about: about) }.freeze
      # The letters of the companies side by side, each with its count.
      LETTER_COLUMNS = 6

      def initialize(bbs, screen, ctx)
        @catalog = bbs.catalog
        @about   = bbs.about
        @tips    = bbs.tips
        @screen  = screen
        @session = ctx[:session_id]
      end

      def run
        @screen.cls
        @screen.puts
        Petscii.masthead(@catalog.count).each { |l| @screen.puts l }
        loop do
          @screen.puts
          @choice = @screen.menu(MENU_ITEMS, index: MENU_ITEMS.index { |i| i.value == @choice }, back: 'q',
                                             hint: 'crsr: choose  return: take')
          case @choice
          when 's' then search
          when 'y' then groups('YEARS', @catalog.years) { |year| @catalog.in_year(year) }
          when 'g' then groups('GENRES', @catalog.genres) { |genre| @catalog.of_genre(genre) }
          when 'c' then companies
          when 'r' then game(@catalog.random)
          when 't' then games('GAMES WITH TIPS', @tips.games_with_tips, empty: 'no game has a tip yet. be the first!')
          when 'i' then @screen.page('ABOUT COMMODEX BBS', [Words::ABOUT, '', Words::SOURCES])
          when 'q' then return
          end
          @screen.title('COMMODEX BBS', "#{@catalog.count} games")
        end
      end

      private

      def search
        @screen.title('SEARCH')
        @screen.say('Type a part of a game title, return alone goes back.', GR)
        @screen.puts
        query = @screen.ask(" #{WH}title?#{LG} ", max: 30)
        return if query.empty?

        found = @catalog.search(query)
        return games("SEARCH: #{query.upcase}", found) if found.is_a?(Array) && found.any?

        @screen.puts
        @screen.say(Words.search(found, query), RD)
        @screen.pause
      end

      # A list of [name, count] groups, then the games of the one picked.
      def groups(heading, list)
        loop do
          picked = @screen.pick(heading, list, right: list.size.to_s) { |name, count| "#{name} #{GR}#{count}#{LG}" }
          return unless picked

          games(picked.first.to_s.upcase, yield(picked.first))
        end
      end

      def companies
        letters = @catalog.letters
        loop do
          @screen.title('PUBLISHERS & DEVELOPERS')
          @screen.say('The first letter of the name:', LG)
          @screen.puts
          k = @screen.menu(letters.map { |l, count| BBS::Selector.item(count.to_s, key: l, value: l) },
                           columns: LETTER_COLUMNS, hint: 'crsr or letter, return  stop: back')
          return unless k

          groups("COMPANIES: #{k.upcase}", @catalog.companies(k)) { |name| @catalog.of_company(name) }
        end
      end

      def games(heading, list, empty: 'no games here.')
        loop do
          picked = @screen.pick(heading, list, empty: empty, right: "#{list.size} games", &:label)
          return unless picked

          game(picked)
          return if list.size == 1
        end
      end

      def game(game)
        loop do
          count = @tips.count(game)
          lines = [*@screen.wrap(game.title).map { |l| " #{WH}#{l}#{LG}" }, '',
                   *Words.facts(game).map { |label, text| " #{CY}#{label.downcase}:#{LG} #{text}" },
                   " #{CY}tips:#{LG} #{Words.tips(count)}"]
          @screen.page('GAME', lines, right: game.id, wait: false)
          case @screen.actions(%w[w wiki], %w[t tips], ['a', 'add a tip'], %w[q back])
          when 'w' then about(game)
          when 't' then tips(game, count)
          when 'a' then add_tip(game)
          when 'q' then return
          end
        end
      end

      def about(game)
        @screen.puts " #{GR}asking wikipedia…#{LG}"
        found = @about.summary(game)
        if found.is_a?(Symbol)
          @screen.say(Words.about(found), RD)
          return @screen.pause
        end

        @screen.page('ABOUT', [" #{WH}#{found.title}#{LG}", '', *found.paragraphs.flat_map { |p| [" #{p}", ''] },
                               " #{GR}#{SummaryModel::LICENSE.downcase}:#{LG}", " #{GR}#{found.url}#{LG}"])
      end

      def tips(game, count)
        lines = @tips.tips(game).flat_map { |t| [" #{CY}#{t.author}#{GR} #{t.date}#{LG}", " #{t.text}", ''] }
        lines = [" #{GR}no tips yet. press a on the game page to add one.#{LG}"] if lines.empty?
        @screen.page("TIPS: #{game.title.upcase}", lines, right: Words.tips(count))
      end

      def add_tip(game)
        @screen.title("A TIP: #{game.title.upcase}")
        @screen.say(Words::TIP_RULES, GR)
        @screen.say('An empty tip goes back.', GR)
        @screen.puts
        handle = @screen.ask(" #{WH}handle#{LG} (optional)? ", max: TipService::MAX_HANDLE)
        text = @screen.edit('', title: "YOUR TIP FOR #{game.title.upcase}", single_line: true,
                                       max: TipService::MAX_TEXT)
        @screen.title("A TIP: #{game.title.upcase}")
        if text.to_s.strip.empty?
          @screen.say('Nothing sent.', GR)
          return @screen.pause
        end

        result = @tips.submit(game, text: text, handle: handle, session: @session)
        @screen.puts
        @screen.say(Words.tip(result), result == :ok ? GN : RD)
        @screen.pause
      end
    end
  end
end
