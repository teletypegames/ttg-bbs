# frozen_string_literal: true

module UI
  module Modern
    # The approved tips of a game: who and when on the left, the tip on the
    # right, and a button for a new one.
    module TipsWindow
      module_function

      def install(app)
        app.window(:tips, type: :master_detail) { |w| configure(w) }
      end

      def configure(w)
        w.maximizable true
        w.title         { |ctx| " Tips: #{ctx[:game].title} " }
        w.height        { |ctx| ctx[:app].rows - 6 }
        w.list_width    26
        w.items         { |ctx| ctx[:tips] }
        w.item_label    { |tip, _ctx| "#{tip.author} · #{tip.date}" }
        w.empty_message 'No tips yet. Add the first one!'
        w.render_detail { |tip, width, ctx| detail(ctx[:app], tip, width) }
        w.bottom_meta   { |tip, _ctx| "tip ##{tip.id}" }
        add_button(w)
      end

      def add_button(w)
        w.action(label: 'A&dd a tip') do |_win, ctx|
          ctx[:app].add_tip(ctx[:game])
          :keep
        end
      end

      def detail(app, tip, width)
        t = app.theme
        ["#{t[:accent]}#{tip.author}#{t[:text_dim]} · #{tip.date}#{t[:text]}", '', *app.wrap(tip.text, width - 1)]
      end
    end
  end
end
