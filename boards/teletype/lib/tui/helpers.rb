# frozen_string_literal: true

module TUIHelpers
  # ── Layout ───────────────────────────────────────────────────────────────────

  def content_width  = term_cols - CONTENT_X - 1
  def content_height = term_rows - 4

  # ── Theming ──────────────────────────────────────────────────────────────────

  def themed_color(style, text)
    "#{THEME.fetch(style, THEME[:normal])}#{text}#{THEME[:reset]}"
  end

  def format_date(iso_string)
    Time.parse(iso_string.to_s).strftime('%Y-%m-%d')
  rescue
    iso_string.to_s
  end

  # ── Chrome ───────────────────────────────────────────────────────────────────

  def render_chrome
    screen_fill background: :black
    panel_height = term_rows - 1

    box x: 1,                y: 1, width: LEFT_WIDTH,                height: panel_height,
        style: THEME[:border], background: :black
    box x: LEFT_WIDTH + 1,   y: 1, width: term_cols - LEFT_WIDTH,    height: panel_height,
        title: " #{@page_title}  │  #{@username}  │  #{ONLINE.count} online ",
        style: THEME[:border], background: :black

    list MENU_ITEMS.map { |item| item[0, LEFT_WIDTH - 4] },
         x: 2, y: CONTENT_Y,
         selected:  @menu_selection,
         style:     THEME[:normal],
         highlight: THEME[:selected]

    bar y: term_rows,
        content: "  \e[1;37;43m↑↓\e[0;30;43m Navigate  \e[1;37;43mEnter\e[0;30;43m Select  " \
                 "\e[1;37;43mQ\e[0;30;43m Back  \e[1;37;43mR\e[0;30;43m Refresh",
        style: THEME[:status]
  end

  # ── Page renderers ────────────────────────────────────────────────────────────

  def render_messages
    (@items[@scroll, content_height] || []).each_with_index do |message, index|
      line = "#{themed_color(:label, message.timestamp)} " \
             "#{themed_color(:bright, message.username)}: #{message.text}"
      text line[0, content_width], x: CONTENT_X, y: CONTENT_Y + index
    end
    text "#{@items.size} msg(s)  ↑↓ scroll  r refresh  q back",
         x: CONTENT_X, y: CONTENT_Y + content_height, style: THEME[:label]
  end

  def render_wiki_list
    list_view @items,
              x: CONTENT_X, y: CONTENT_Y,
              height: content_height - 3, scroll: @scroll, selected: @item_selection,
              label: ->(p) { p.title[0, content_width - 2] },
              hint:  ->(p) { p.description.to_s[0, content_width] },
              hint_y: CONTENT_Y + content_height - 2,
              style: THEME[:normal], highlight: THEME[:selected]
    text '↑↓ navigate  Enter read  r refresh  q back',
         x: CONTENT_X, y: CONTENT_Y + content_height, style: THEME[:label]
  end

  def render_page_view
    text @page_metadata[0, content_width], x: CONTENT_X, y: CONTENT_Y, style: THEME[:label]
    (@detail[@scroll, content_height - 2] || []).each_with_index do |line, index|
      text line[0, content_width], x: CONTENT_X, y: CONTENT_Y + 2 + index, style: THEME[:normal]
    end
    text "#{@scroll + 1}/#{@detail.size}  ↑↓ scroll  q back",
         x: CONTENT_X, y: CONTENT_Y + content_height, style: THEME[:label]
  end

  def render_game_card
    if @items.empty?
      text 'No games found.', x: CONTENT_X, y: CONTENT_Y, style: THEME[:normal]
      return
    end
    game  = @items[@item_selection]
    links = game.external_links

    text "#{@item_selection + 1}/#{@items.size}  #{game.title}"[0, content_width],
         x: CONTENT_X, y: CONTENT_Y, style: THEME[:bright]
    text "#{game.platform}  ·  #{game.author}"[0, content_width],
         x: CONTENT_X, y: CONTENT_Y + 1, style: THEME[:normal]

    story_row_count = content_height - 4 - links.size
    wordwrap(game.story, content_width).first(story_row_count).each_with_index do |line, index|
      text line, x: CONTENT_X, y: CONTENT_Y + 3 + index, style: THEME[:normal]
    end

    link_start_row = CONTENT_Y + content_height - links.size
    links.each_with_index do |link, index|
      text "#{themed_color(:label, link[:label])}  #{link[:url]}"[0, content_width],
           x: CONTENT_X, y: link_start_row + index
    end

    text '↑↓ navigate  r refresh  q back',
         x: CONTENT_X, y: CONTENT_Y + content_height, style: THEME[:label]
  end

  def render_online_users
    @items.each_with_index do |username, index|
      indicator = username == @username ? themed_color(:label, ' ← you') : ''
      text themed_color(:bright, username) + indicator, x: CONTENT_X, y: CONTENT_Y + index
    end
    text "#{@items.size} user(s) online  r refresh  q back",
         x: CONTENT_X, y: CONTENT_Y + content_height, style: THEME[:label]
  end
end
