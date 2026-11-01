# frozen_string_literal: true

module UI
  # A post as the board pages it, +width+ columns wide: its head (title,
  # category, date, author, state, summary) over a rule, then its Markdown.
  # The web shows the C64 screen of a post from the same lines.
  module PostPage
    def self.lines(categories, post, width:, long_dates: width >= 58)
      [*head(categories, post, width, long_dates), " #{DG}#{'─' * (width - 1)}#{LG}", *body(post, width)]
    end

    def self.head(categories, post, width, long_dates)
      date  = ->(time) { time.localtime.strftime(long_dates ? '%Y-%m-%d %H:%M' : '%Y-%m-%d') }
      meta  = [categories.find(post.category).name, date.call(post.created_at), post.author].compact.join(' · ')
      lines = wrap(post.title, width).map { |l| " #{WH}#{l}#{LG}" }
      lines << " #{GR}#{meta}#{LG}"
      lines << " #{GR}updated #{date.call(post.updated_at)}#{LG}" if post.updated?
      lines << " #{RD}unpublished: only the editors see it#{LG}" unless post.published
      [*lines, '', *summary(post, width)]
    end

    def self.summary(post, width)
      post.summary.empty? ? [] : wrap(post.summary, width).map { |l| " #{CY}#{l}#{LG}" }
    end

    def self.body(post, width)
      text = post.body.strip.empty? ? '*(no text yet)*' : post.body
      BBS::Markdown.to_lines(text, width: width, theme: MARKDOWN).map { |l| " #{l}" }
    end

    def self.wrap(text, width) = BBS::FrameBuffer.wrap_ansi(text.to_s, width)
  end
end
