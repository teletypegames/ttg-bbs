# frozen_string_literal: true

module UI
  module Petscii
    # The Board on a Commodore 64: PETSCII on a 40×25 screen, every view
    # the whole screen with a footer bar of its keys. The front page is the
    # masthead over a menu of rubbs: the newest posts to open at once, as
    # many as the screen holds, then the board's own items, each with a line
    # about it over the footer. CRSR moves the bar, RETURN opens, and the
    # digits of the posts and the letters of the items work as before. A
    # post is read under a footer that stays on every page, with the
    # editor's keys over it.
    class Board < UI::Board
      FACE = 'petscii'

      LOGO_COLORS = [YE, YE, "\e[0;33m", "\e[0;33m", "\e[0;31m"].freeze

      # The rows over the front page's menu: a blank row, the logo and the
      # motto.
      MASTHEAD_ROWS = 1 + 5 + 1

      S = BBS::Selector

      def self.screen(session) = Screen.new(session, cols: COLS, rows: ROWS)

      def self.logo = BBS::BlockFont.petscii(LOGO, colors: LOGO_COLORS, indent: 2)

      private

      # The front page draws itself each time.
      def start; end

      def main_choice
        items = front_items
        @screen.cls
        @screen.puts
        Board.logo.each { |l| @screen.puts l }
        motto
        index = items.index { |i| i.selectable? && same?(i.value, @front) }
        @front = @screen.full_menu(items, top: MASTHEAD_ROWS + 1, index: index, back: 'q',
                                          hint: 'crsr: move  return: open  q: log off')
      end

      # The newest posts, as many as the screen holds over the menu items.
      def front_items
        menu   = menu_items
        room   = @screen.footer_row - MASTHEAD_ROWS - 2 - 2 - menu.size
        posts  = @posts.all(published: shown, limit: room)
        latest = posts.empty? ? [S.heading("#{GR}no posts yet")] : posts.each_with_index.map { |p, i| headline(p, i) }
        [S.heading(rule_label('latest')), *latest, S.heading(rule_label('menu')), *menu]
      end

      def same?(value, other) = value.is_a?(PostModel) ? other.is_a?(PostModel) && other.id == value.id : value == other

      def motto
        stat = user ? "#{user.name} " : "#{@posts.total(published: true)} posts "
        gap  = COLS - 1 - 2 - MOTTO.length - stat.length
        @screen.puts "  #{WH}#{MOTTO}#{GR}#{' ' * [gap, 1].max}#{stat}#{LG}"
      end

      def rule_label(text) = "#{text} #{'─' * (COLS - 4 - text.length)}"

      def headline(post, index)
        draft = post.published ? '' : "#{RD}u#{LG} "
        about = post.summary.empty? ? @categories.find(post.category).name : post.summary
        S.item("#{GR}#{post.created_at.localtime.strftime('%m-%d')}#{LG} #{draft}#{post.title}",
               key: (index + 1).to_s, value: post, about: about)
      end

      def menu_items
        items = [S.item('latest posts', key: 'l', value: 'l', about: 'every post, newest first'),
                 S.item('categories', key: 'c', value: 'c', about: @categories.all.map(&:name).join(', ')),
                 S.item('go to post #', key: 'g', value: 'g', about: 'by the number the web shows')]
        items += if user
                   [S.item("unpublished #{GR}(#{@posts.total(published: false)})#{LG}", key: 'u', value: 'u',
                                                                                     about: 'waiting to be published'),
                    S.item('write a post', key: 'w', value: 'w', about: 'it waits unpublished until you publish it'),
                    S.item('change your password', key: 'p', value: 'p', about: "#{user.name}'s password"),
                    S.item('log out', key: 'o', value: 'o', about: "back to a reader, #{user.name}")]
                 else
                   [S.item('editor login', key: 'e', value: 'e', about: 'for the editors of the blog')]
                 end
        items << S.item('log off', key: 'q', value: 'q', about: 'hang up. see you!')
      end

      # A post read under its footer; after an edit or a change of its
      # state it is shown again, until the caller goes back or deletes it.
      # True when it was changed or deleted.
      def show(id)
        changed = false
        loop do
          post = @posts.find(id)
          return changed unless readable?(post)

          case read(post)
          when 'e' then changed = compose(post) || changed
          when 'p' then changed = publish?(post, !post.published) || changed
          when 'd' then return true if delete?(post)
          else return changed
          end
        end
      end

      def read(post)
        actions = if user
                    [%w[e edit], ['p', post.published ? 'unpublish' : 'publish'], %w[d delete]]
                  else
                    []
                  end
        @screen.view(@categories.find(post.category).name.upcase, post_lines(post), right: right, actions: actions)
      end

      def saved_new(post) = "Saved as number #{post.id}, unpublished. Open it and press P to publish it."

      def draft_choice(draft, post)
        @screen.title(post ? "EDIT POST #{post.id}" : 'NEW POST', right)
        @screen.puts
        items = draft_items(draft, post)
        items.concat(body_preview(draft[:body], room: draft_rows - items.size))
        choice = @screen.full_menu(items, top: 3, index: @draft_index, back: 'q',
                                          hint: 'crsr: choose  return: take  q: quit')
        @draft_index = items.index { |i| i.value == choice }
        choice
      end

      def draft_items(draft, post)
        [*draft_fields(draft),
         S.heading('─' * (COLS - 4)),
         S.item('view, as a reader will', key: 'v', value: 'v', about: 'the post as it will show'),
         S.item(post ? 'save' : "save#{GR}, unpublished#{LG}", key: 'w', value: 'w', about: save_about(post)),
         S.item('quit', key: 'q', value: 'q', about: 'back, without saving')]
      end

      def draft_fields(draft)
        summary = draft[:summary].empty? ? '-' : draft[:summary]
        [field('t', 'title   ', draft[:title], 'the title of the post'),
         field('c', 'category', @categories.find(draft[:category]).name, 'pick another category'),
         field('s', 'summary ', summary, 'one paragraph over the body'),
         field('b', 'body    ', "#{draft[:body].lines.size} lines", 'the text, in markdown')]
      end

      def save_about(post) = post ? 'keep the changes' : 'publish it with P later'

      def field(key, name, value, about) = S.item("#{GR}#{name}#{LG} #{value}", key: key, value: key, about: about)

      # The rows of the draft's menu: from the third row to the footer, less
      # the about row and the footer.
      def draft_rows = @screen.footer_row - 3 + 1 - 2

      # The first lines of the body under a rule, as many as +room+ holds.
      def body_preview(body, room:)
        return [] if room < 3

        lines = body.lines.map { |l| @screen.plain(l.chomp) }.reject(&:empty?).first(room - 1)
        lines = ['(no text yet)'] if lines.empty?
        [S.heading(rule_label('body')), *lines.map { |l| S.heading("#{GR}#{l}") }]
      end
    end
  end
end
