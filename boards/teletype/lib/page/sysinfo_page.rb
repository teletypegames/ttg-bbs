# frozen_string_literal: true

module SysinfoPage
  def self.configure(tui)
    tui.page :sysinfo do
      enter do
        @page_title = 'SYSTEM INFO'
        @items = [
          "Online users  #{ONLINE.count}",
          "Messages      #{MESSAGES.count}",
          "Wiki          https://wiki.teletypegames.org",
          "Games API     https://teletypegames.org",
          "Platform      #{RUBY_PLATFORM}",
          "Ruby          #{RUBY_VERSION}"
        ]
      end

      render do
        @items.each_with_index do |row, i|
          text row[0, cont_w], x: CONT_X, y: CONT_Y + i, style: THEME[:normal]
        end
        text 'q back', x: CONT_X, y: CONT_Y + cont_h, style: THEME[:normal]
      end

      key('q')     { go :idle }
      key(:escape) { go :idle }
    end
  end
end
