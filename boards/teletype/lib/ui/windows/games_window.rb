# frozen_string_literal: true

module UI
  module Windows
    module_function

    # Game catalog browser. Left=titles, right=card with story + links.
    def games(app, services:)
      BBS::Windows::MasterDetail.open(app,
        title:         ' Game Catalog ',
        items:         services[:games].all,
        item_label:    ->(g) { g.title },
        list_width:    30,
        empty_message: '  (no games)',
        render_detail: ->(game, width) { game_card_lines(game, width) }
      )
    end

    def game_card_lines(game, width)
      lines = []
      lines << "  \e[1;33m#{game.title}\e[0m"
      lines << "  \e[0;36m#{game.platform} · #{game.author}\e[0m"
      lines << ''
      BBS::FrameBuffer.wrap_ansi(game.desc.to_s,  width - 4).each { |l| lines << "  #{l}" }
      lines << ''
      BBS::FrameBuffer.wrap_ansi(game.story.to_s, width - 4).each { |l| lines << "  #{l}" }
      lines << ''
      game.external_links.each do |link|
        lines << "  \e[0;37m#{link[:label].ljust(10)}\e[0m \e[1;36m#{link[:url]}\e[0m"
      end
      lines
    end
  end
end
