# frozen_string_literal: true

module TUIHelpers
  def tc(style, str)   = "#{THEME.fetch(style, THEME[:normal])}#{str}#{THEME[:reset]}"
  def cont_w           = term_cols - CONT_X - 1
  def cont_h           = term_rows - 4

  def fmt_date(iso)
    Time.parse(iso.to_s).strftime('%Y-%m-%d')
  rescue
    iso.to_s
  end

  def wordwrap(text, width)
    words = text.to_s
                .gsub(/\[([^\]]+)\]\([^)]+\)/, '\1')
                .gsub(/[#*_`~>|\\]/, '')
                .gsub(/\r?\n+/, ' ')
                .strip
                .split
    lines, line = [], +''
    words.each do |w|
      if    line.empty?                         then line << w
      elsif line.length + 1 + w.length <= width then line << ' ' << w
      else  lines << line.dup; line = +w
      end
    end
    lines << line unless line.empty?
    lines
  end

  def wiki_list_render
    list_h  = cont_h - 3
    visible = @items[@scroll, list_h] || []
    if visible.empty?
      text 'No items found.', x: CONT_X, y: CONT_Y, style: THEME[:normal]
    else
      list visible.map { |p| p.title[0, cont_w - 2] },
           x: CONT_X, y: CONT_Y,
           selected: @item_sel - @scroll,
           style: THEME[:normal], highlight: THEME[:selected]
      if (page = @items[@item_sel])
        hint = page.description.to_s.strip[0, cont_w]
        text hint, x: CONT_X, y: CONT_Y + cont_h - 2, style: THEME[:normal] unless hint.empty?
      end
    end
    text '↑↓ navigate  Enter read  q back', x: CONT_X, y: CONT_Y + cont_h, style: THEME[:normal]
  end

  def open_wiki_page(back:)
    return unless (page = @items[@item_sel])
    @detail     = wordwrap(WIKI.content(page.id), cont_w)
    @page_title = page.title
    @page_meta  = "#{fmt_date(page.created_at)}  #{WIKI.page_url(page.locale, page.path)}"
    @prev_page  = back
    @scroll     = 0
    go :page_view
  end
end
