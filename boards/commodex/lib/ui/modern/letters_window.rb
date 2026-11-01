# frozen_string_literal: true

module UI
  module Modern
    # The publishers and developers by their first letter.
    module LettersWindow
      module_function

      def install(app)
        app.window(:letters, type: :master_detail) { |w| configure(w) }
      end

      def configure(w)
        w.title      ' Publishers & developers '
        w.height     { |ctx| ctx[:app].rows - 6 }
        w.list_width 20
        w.items      { |ctx| ctx[:catalog].letters }
        w.item_label { |(letter, count), _ctx| "#{letter.upcase}  (#{count})" }
        w.render_detail { |(letter, _count), width, ctx| detail(ctx[:app], letter, width) }
        w.bottom_meta { |_item, _ctx| 'Enter lists the companies' }
        w.on_activate { |(letter, _count), _window, ctx| ctx[:app].open_letter(letter) }
      end

      def detail(app, letter, width)
        t     = app.theme
        names = app.catalog.companies(letter).map(&:first)
        ["#{t[:text_bright]}#{letter.upcase}#{t[:text]}", '', *app.wrap(names.join(' · '), width - 1)]
      end
    end
  end
end
