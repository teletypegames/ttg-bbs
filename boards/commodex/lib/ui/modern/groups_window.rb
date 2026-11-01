# frozen_string_literal: true

module UI
  module Modern
    # The years, the genres or the companies of one letter, each with its
    # count; the right pane lists the first games of the one picked.
    module GroupsWindow
      SHOWN = 40

      module_function

      def install(app)
        app.window(:groups, type: :master_detail) { |w| configure(w) }
      end

      def configure(w)
        Pane.size(w)
        w.items         { |ctx| ctx[:groups] }
        w.item_label    { |(name, count), _ctx| "#{name} (#{count})" }
        w.empty_message 'Nothing here.'
        w.render_detail { |(name, count), width, ctx| detail(ctx[:app], ctx[:kind], name, count, width) }
        w.bottom_meta   { |_item, _ctx| 'Enter lists the games' }
        w.on_activate   { |(name, _count), _window, ctx| ctx[:app].open_group(ctx[:kind], name) }
      end

      def detail(app, kind, name, count, width)
        t     = app.theme
        games = app.games_of(kind, name)
        ["#{t[:text_bright]}#{name}#{t[:text]}", "#{t[:accent]}#{count} game#{'s' unless count == 1}#{t[:text]}", '',
         *games.first(SHOWN).map { |g| BBS::FrameBuffer.clip_ansi(g.label, width - 1) },
         *(games.size > SHOWN ? ["#{t[:text_dim]}… and #{games.size - SHOWN} more#{t[:text]}"] : [])]
      end
    end
  end
end
