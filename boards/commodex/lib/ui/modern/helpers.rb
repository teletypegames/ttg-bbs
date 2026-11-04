# frozen_string_literal: true

module UI
  module Modern
    # What the caller does on the modern face: the search, the lists of
    # games, a game's card, its about page and tips.
    module Helpers
      CARD_KEYS = 'Enter or Alt-B: about · Alt-T: tips · Alt-D: add a tip'
      SHOWN     = 40

      def search
        ask('Part of a game title:', title: 'Search', width: 60) { |text| find(text) }
      end

      def find(query)
        found = catalog.search(query)
        return note(Wording.search(found, query), 'Search') unless found.is_a?(Array) && found.any?

        show(:games, caption: "Search: #{query.strip}", games: found)
      end

      def random = show(:games, caption: 'Random game', games: [catalog.random])

      def with_tips
        games = tips.games_with_tips
        return note('No game has an approved tip yet. Be the first!', 'Tips') if games.empty?

        show(:games, caption: 'Games with tips', games: games)
      end

      # The games of a year, a genre or a company.
      def games_of(kind, name)
        case kind
        when :year  then catalog.in_year(name)
        when :genre then catalog.of_genre(name)
        else catalog.of_company(name)
        end
      end

      def open_group(kind, name) = show(:games, caption: name.to_s, games: games_of(kind, name))

      def open_letter(letter)
        show(:groups, caption: "Companies: #{letter.upcase}", kind: :company, groups: catalog.companies(letter))
      end

      def read_about(game)
        found = loading('Asking Wikipedia…') { about.summary(game) }
        return note(Wording.about(found), 'About') if found.is_a?(Symbol)

        show(:about, game: game, summary: found)
      end

      def show_tips(game) = show(:tips, game: game, entries: tips.tips(game))

      def add_tip(game) = show(:add_tip, game: game)

      def note(text, title) = message(text, title: title, width: 64)

      def wrap(text, width) = BBS::FrameBuffer.wrap_ansi(text.to_s, width)

      def about_width = [cols - 4, 78].min

      # The card of a game: the title, the facts in a column, the tips, the
      # addresses and the keys.
      def game_card(game, width)
        links = [*(game.article ? [game.wikipedia_url] : []), game.wikidata_url].map { |l| dim(l) }
        [bright(game.title), '', *facts(game, width), '', *links, '', dim(CARD_KEYS)]
      end

      # A year, a genre or a company, and the first SHOWN of its games.
      def group_card(kind, name, count, width)
        games = games_of(kind, name)
        [bright(name), accent("#{count} game#{'s' unless count == 1}"), '',
         *games.first(SHOWN).map { |g| BBS::FrameBuffer.clip_ansi(g.label, width - 1) },
         *(games.size > SHOWN ? [dim("… and #{games.size - SHOWN} more")] : [])]
      end

      # The lead of a game's Wikipedia article with its licence and address.
      def about_body(summary)
        inner = about_width - 5
        [bright(summary.title), '', *summary.paragraphs.flat_map { |p| [*wrap(p, inner), ''] },
         dim(SummaryModel::LICENSE), *wrap(dim(summary.url), inner)]
      end

      private

      # The facts and the tips, the labels padded to one column.
      def facts(game, width)
        facts = Wording.facts(game)
        pad   = facts.map { |label, _| label.size }.max.to_i + 2
        facts.flat_map { |label, text| fact(label, text, pad, width) } +
          ["#{paint(:label, 'Tips'.ljust(pad))}#{accent(Wording.tips(tips.count(game)))}"]
      end

      def fact(label, text, pad, width)
        first, *rest = wrap(text, width - 1 - pad)
        ["#{paint(:label, label.ljust(pad))}#{first}", *rest.map { |r| "#{' ' * pad}#{r}" }]
      end
    end
  end
end
