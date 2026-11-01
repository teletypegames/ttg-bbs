# frozen_string_literal: true

module UI
  module Modern
    # The lead of a game's Wikipedia article, scrolling, with its licence and
    # address.
    module AboutWindow
      module_function

      def install(app)
        app.window(:about, type: :info) { |w| configure(w) }
      end

      def configure(w)
        w.maximizable true
        w.scroll true
        w.title  { |ctx| " #{ctx[:game].title} " }
        w.width  { |ctx| ctx[:app].about_width }
        w.height { |ctx| ctx[:app].rows - 6 }
        w.body   { |ctx| body(ctx[:app], ctx[:summary]) }
      end

      def body(app, summary)
        t     = app.theme
        inner = app.about_width - 5
        ["#{t[:text_bright]}#{summary.title}#{t[:text]}", '',
         *summary.paragraphs.flat_map { |p| [*app.wrap(p, inner), ''] },
         "#{t[:text_dim]}#{SummaryModel::LICENSE}#{t[:text]}",
         *app.wrap("#{t[:text_dim]}#{summary.url}#{t[:text]}", inner)]
      end
    end
  end
end
