# frozen_string_literal: true

module UI
  module Petscii
    # The Board on a Commodore 64: PETSCII on a 40×25 screen. The front page
    # is the masthead in reversed spaces over a menu of rubbs: the newest
    # posts to open at once, then the board's own items, each with a line
    # about it under the menu. CRSR moves the bar, RETURN opens, and the
    # digits of the posts and the letters of the items work as before.
    class Board < UI::Board
      FACE = 'petscii'

      LOGO_COLORS = [YE, YE, "\e[0;33m", "\e[0;33m", "\e[0;31m"].freeze

      # The rows the front page keeps for itself: the masthead (a blank
      # row, the logo, the motto, a blank row), two headings, the about and
      # the hint, and the last row of the screen.
      FRONT_ROWS = 1 + 5 + 1 + 1 + 2 + 2 + 1
      MOST_HEADLINES = 5

      S = BBS::Selector

      def self.screen(session) = Screen.new(session, cols: COLS, rows: ROWS)

      def self.logo
        logo_bits.each_with_index.map do |row, i|
          "  #{LOGO_COLORS[i]}#{row.gsub(/#+/) { |run| "#{RV}#{' ' * run.size}#{RO}" }.tr('.', ' ')}#{LG}"
        end
      end

      private

      # The front page draws itself each time.
      def start; end

      def main_choice
        menu  = menu_items
        posts = @posts.all(published: shown, limit: [ROWS - FRONT_ROWS - menu.size, MOST_HEADLINES].min)
        items = [S.heading(rule_label('latest')), *posts.each_with_index.map { |p, i| headline(p, i) },
                 S.heading(rule_label('menu')), *menu]
        items.delete_at(0) if posts.empty?
        @screen.cls
        @screen.puts
        Board.logo.each { |l| @screen.puts l }
        motto
        @screen.puts
        index = items.index { |i| i.selectable? && same?(i.value, @front) }
        @front = @screen.menu(items, index: index, back: 'q', hint: 'crsr: choose  return: open')
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

      # The editor's choice under a post, on a row the cursor moves along.
      def post_choice(post)
        @screen.puts
        @screen.menu([S.item('edit', key: 'e', value: 'e'),
                      S.item(post.published ? 'unpublish' : 'publish', key: 'p', value: 'p'),
                      S.item('delete', key: 'd', value: 'd'), S.item('back', key: 'q', value: 'q')],
                     across: true, index: 3, back: 'q')
      end

      def draft_choice(draft, post)
        @screen.title(post ? "EDIT POST #{post.id}" : 'NEW POST', right)
        @screen.puts
        items = [S.item("#{GR}title#{LG}    #{draft[:title]}", key: 't', value: 't'),
                 S.item("#{GR}category#{LG} #{@categories.find(draft[:category]).name}", key: 'c', value: 'c'),
                 S.item("#{GR}summary#{LG}  #{draft[:summary].empty? ? '-' : draft[:summary]}", key: 's', value: 's'),
                 S.item("#{GR}body#{LG}     #{draft[:body].lines.size} lines", key: 'b', value: 'b'),
                 S.heading('─' * (COLS - 4)),
                 S.item('view, as a reader will', key: 'v', value: 'v'),
                 S.item("save#{GR}, unpublished#{LG}", key: 'w', value: 'w'),
                 S.item('quit', key: 'q', value: 'q')]
        items[6] = S.item('save', key: 'w', value: 'w') if post
        choice = @screen.menu(items, index: @draft_index, back: 'q', hint: 'crsr: choose  return: take')
        @draft_index = items.index { |i| i.value == choice }
        choice
      end
    end
  end
end
