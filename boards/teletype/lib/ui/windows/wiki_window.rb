# frozen_string_literal: true

module UI
  module Windows
    module_function

    # Split-view wiki browser. Left=titles, right=selected page content
    # (rendered with markdown-aware formatting).
    def wiki(app, services:, category:, title:)
      cols = app.cols
      rows = app.rows
      w = cols - 4
      h = rows - 6
      window = BBS::Window.new(title: " #{title} ")
      window.layout(3, 3, w, h)
      window.theme = app.theme

      items = services[:wiki].list(category)

      list = BBS::Widgets::ListBox.new(
        items: items,
        label: ->(p) { "  #{p.title}".ljust(28) }
      )
      list_width = [32, (w / 3)].max
      list.layout(window.bounds.x + 2, window.bounds.y + 2, list_width, h - 5)
      window.add(list)

      preview = BBS::Widgets::ScrollView.new(lines: [])
      preview.layout(window.bounds.x + list_width + 4, window.bounds.y + 2,
                     w - list_width - 7, h - 5)
      window.add(preview)

      meta = BBS::Widgets::Label.new(text: '', style_key: :input_label)
      meta.layout(window.bounds.x + 2, window.bounds.y + h - 2, w - 4, 1)
      window.add(meta)

      load_preview = lambda do
        page = list.selected_item
        next unless page
        meta.text = "#{page.created_at.to_s[0, 10]}  #{services[:wiki].page_url(page.locale, page.path)}"
        text = services[:wiki].content(page.id)
        preview.lines = format_md(text, preview.bounds.width - 1, app.theme)
        preview.scroll = 0
      end

      list.on_select = ->(_, _) { load_preview.call }

      if items.empty?
        preview.lines = ['  (no pages found)']
      else
        load_preview.call
      end

      window.reset_focus
      window.focus_manager.focus(list)
      app.open_window(window)
      window
    end

    # ── Markdown → ANSI line array ────────────────────────────────────────────
    #
    # Returns an array of strings (each is one rendered terminal line with
    # embedded ANSI SGR escapes) suitable for BBS::Widgets::ScrollView.
    #
    # Each inline span is terminated by the theme :text SGR so the trailing
    # text on the same line keeps the right background color.
    def format_md(text, width, theme)
      styles = {
        base:    theme[:text],
        h1:      theme[:text_bright],
        h2:      theme[:accent],
        h3:      theme[:label],
        bold:    theme[:text_bright],
        italic:  theme[:text_dim],
        code:    theme[:label],
        link:    theme[:accent],
        quote:   theme[:text_dim],
        bullet:  theme[:accent],
        rule:    theme[:label],
      }
      result    = []
      paragraph = []
      in_code   = false
      base      = styles[:base]

      flush_paragraph = lambda do
        next if paragraph.empty?
        joined = paragraph.join(' ').gsub(/\s+/, ' ').strip
        BBS::FrameBuffer.wrap_ansi(inline_md(joined, styles, base), width)
                        .each { |l| result << l }
        paragraph.clear
      end

      text.to_s.split(/\r?\n/).each do |line|
        # Fenced code block toggle
        if line.lstrip.start_with?('```')
          flush_paragraph.call
          in_code = !in_code
          next
        end

        if in_code
          flush_paragraph.call
          BBS::FrameBuffer.clip_ansi(line, width).then do |clipped|
            result << "#{styles[:code]}#{clipped}#{base}"
          end
          next
        end

        # Blank line: paragraph break
        if line.strip.empty?
          flush_paragraph.call
          result << ''
          next
        end

        # ATX header
        if (m = line.match(/\A([#]{1,6})\s+(.+?)\s*#*\s*\z/))
          level   = m[1].length
          heading = m[2].strip
          flush_paragraph.call
          style = level == 1 ? styles[:h1] : (level == 2 ? styles[:h2] : styles[:h3])
          BBS::FrameBuffer.wrap_ansi(inline_md(heading, styles, base), width).each do |l|
            result << "#{style}#{l}#{base}"
          end
          next
        end

        # Horizontal rule: --- *** ___
        if line.match?(/\A\s*([-*_])\1{2,}\s*\z/)
          flush_paragraph.call
          result << "#{styles[:rule]}#{'─' * width}#{base}"
          next
        end

        # Blockquote
        if (m = line.match(/\A\s*>\s?(.*)/))
          content = m[1]
          flush_paragraph.call
          inner_w = [width - 2, 1].max
          BBS::FrameBuffer.wrap_ansi(inline_md(content, styles, base), inner_w).each do |l|
            result << "#{styles[:quote]}│ #{base}#{l}"
          end
          next
        end

        # Unordered list item
        if (m = line.match(/\A(\s*)[-*+]\s+(.+)/))
          indent = m[1].length
          body   = m[2]
          flush_paragraph.call
          prefix_w = indent + 2
          inner_w  = [width - prefix_w, 1].max
          wrapped  = BBS::FrameBuffer.wrap_ansi(inline_md(body, styles, base), inner_w)
          wrapped.each_with_index do |l, i|
            pad = ' ' * indent
            result << if i.zero?
                        "#{pad}#{styles[:bullet]}•#{base} #{l}"
                      else
                        "#{' ' * prefix_w}#{l}"
                      end
          end
          next
        end

        # Ordered list item
        if (m = line.match(/\A(\s*)(\d+)\.\s+(.+)/))
          indent = m[1].length
          num    = m[2]
          body   = m[3]
          flush_paragraph.call
          prefix = "#{' ' * indent}#{num}. "
          inner_w = [width - prefix.length, 1].max
          wrapped = BBS::FrameBuffer.wrap_ansi(inline_md(body, styles, base), inner_w)
          wrapped.each_with_index do |l, i|
            result << if i.zero?
                        "#{' ' * indent}#{styles[:bullet]}#{num}.#{base} #{l}"
                      else
                        "#{' ' * prefix.length}#{l}"
                      end
          end
          next
        end

        # Regular paragraph line — buffer for reflow
        paragraph << line.strip
      end

      flush_paragraph.call
      result
    end

    # Apply inline markdown formatting (bold, italic, code, links) and
    # return the string with embedded ANSI codes. Each closing marker emits
    # `base_sgr` so that surrounding text keeps the right background.
    def inline_md(text, styles, base_sgr)
      s = text.to_s
      # Links [text](url) — show the link text styled (URL dropped)
      s = s.gsub(/\[([^\]]+)\]\(([^)]+)\)/) { "#{styles[:link]}#{::Regexp.last_match(1)}#{base_sgr}" }
      # Inline code `code`
      s = s.gsub(/`([^`]+)`/) { "#{styles[:code]}#{::Regexp.last_match(1)}#{base_sgr}" }
      # Bold **text**
      s = s.gsub(/\*\*([^*]+)\*\*/) { "#{styles[:bold]}#{::Regexp.last_match(1)}#{base_sgr}" }
      # Italic *text* and _text_ (require word boundaries to avoid mid-word _)
      s = s.gsub(/(?<![A-Za-z0-9*])\*([^*\s][^*]*?[^*\s]|\S)\*(?![A-Za-z0-9*])/) {
        "#{styles[:italic]}#{::Regexp.last_match(1)}#{base_sgr}"
      }
      s = s.gsub(/(?<![A-Za-z0-9_])_([^_\s][^_]*?[^_\s]|\S)_(?![A-Za-z0-9_])/) {
        "#{styles[:italic]}#{::Regexp.last_match(1)}#{base_sgr}"
      }
      # Strip stray backslash escapes for common markdown chars
      s.gsub(/\\([\\`*_{}\[\]()#+\-.!>])/) { ::Regexp.last_match(1) }
    end
  end
end
