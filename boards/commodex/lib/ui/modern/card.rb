# frozen_string_literal: true

module UI
  module Modern
    # The card of a game in the right pane of a games window: the title, the
    # facts in a column, the tips, the addresses and the keys.
    module Card
      KEYS = 'Enter or Alt-B: about · Alt-T: tips · Alt-D: add a tip'

      module_function

      def lines(app, game, width)
        t = app.theme
        [*app.wrap("#{t[:text_bright]}#{game.title}#{t[:text]}", width - 1), '',
         *facts(app, game, width), '', *links(game, t), '',
         *app.wrap("#{t[:text_dim]}#{KEYS}#{t[:text]}", width - 1)]
      end

      # The facts and the tips, the labels padded to one column.
      def facts(app, game, width)
        t     = app.theme
        facts = Words.facts(game)
        pad   = facts.map { |label, _| label.size }.max.to_i + 2
        facts.flat_map { |label, text| fact(app, label, text, pad, width) } +
          ["#{t[:label]}#{'Tips'.ljust(pad)}#{t[:accent]}#{Words.tips(app.tip_service.count(game))}#{t[:text]}"]
      end

      def fact(app, label, text, pad, width)
        t = app.theme
        first, *rest = app.wrap(text, width - 1 - pad)
        ["#{t[:label]}#{label.ljust(pad)}#{t[:text]}#{first}", *rest.map { |r| "#{' ' * pad}#{r}" }]
      end

      def links(game, t)
        [*(game.article ? ["#{t[:text_dim]}#{game.wikipedia_url}#{t[:text]}"] : []),
         "#{t[:text_dim]}#{game.wikidata_url}#{t[:text]}"]
      end
    end
  end
end
