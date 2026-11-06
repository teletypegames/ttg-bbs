# frozen_string_literal: true

module UI
  # A post as the board pages it on +screen+: its head (title, category,
  # date, author, state, summary) over a rule, then its Markdown. The web
  # shows the C64 screen of a post from the same lines.
  module PostPage
    include Rubbs::Petscii::Colors

    def self.lines(categories, post, screen, long_dates: false)
      [*head(categories, post, screen, long_dates), screen.rule_line, *body(post, screen)]
    end

    def self.head(categories, post, screen, long_dates)
      date  = ->(time) { time.localtime.strftime(long_dates ? '%Y-%m-%d %H:%M' : '%Y-%m-%d') }
      meta  = [categories.find(post.category).name, date.call(post.created_at), post.author].compact.join(' · ')
      lines = screen.wrap(post.title).map { |l| " #{WH}#{l}#{LG}" }
      lines << " #{GR}#{meta}#{LG}"
      lines << " #{GR}updated #{date.call(post.updated_at)}#{LG}" if post.updated?
      lines << " #{RD}unpublished: only the editors see it#{LG}" unless post.published?
      [*lines, '', *summary(post, screen)]
    end

    def self.summary(post, screen)
      post.summary.empty? ? [] : screen.wrap(post.summary).map { |l| " #{CY}#{l}#{LG}" }
    end

    def self.body(post, screen) = screen.markdown(post.body.strip.empty? ? '*(no text yet)*' : post.body)
  end
end
