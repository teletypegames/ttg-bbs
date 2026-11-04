# frozen_string_literal: true

require_relative 'board'
require_relative 'petscii/screen'

module UI
  # The blog on a Commodore 64: PETSCII on a 40×25 screen, every view the
  # whole screen with a footer bar of its keys (UI::Petscii::Screen). The
  # front page is the masthead over one cursor menu: the newest posts to
  # open at once, as many as the screen holds, then the board's own items,
  # each with a line about it over the footer. A post is read under a footer
  # that stays on every page, with the editor's keys over it.
  class Petscii < Board
    LOGO_COLORS = [YE, YE, OR, OR, "\e[0;31m"].freeze

    # The rows over the front page's menu: a blank row, the logo and the
    # motto.
    MASTHEAD_ROWS = 1 + 5 + 1

    S = BBS::Selector

    masthead do
      gap
      logo LOGO, colors: LOGO_COLORS
      line(color: WH) { motto }
    end

    # A post on a C64, as lines of ANSI: the title bar, then the post as the
    # board pages it. The web draws it in C64 colours.
    def self.post_screen(bbs, post)
      screen = Screen.new(nil)
      [screen.title_bar(bbs.categories.find(post.category).name.upcase, "#{bbs.posts.total(published: true)} posts "),
       *screen.fit(PostPage.lines(bbs.categories, post, screen))]
    end

    main_menu(home: :masthead, gap: false, hint: 'crsr: move  return: open  q: log off') do
      heading "latest #{'─' * (COLS - 4 - 6)}"
      each_of(-> { latest_posts }) do |post, i|
        next heading("#{GR}no posts yet") unless post

        item((i + 1).to_s, -> { headline_label(post) }, -> { post_about(post) }) { show(post.id) }
      end
      heading "menu #{'─' * (COLS - 4 - 4)}"
      instance_exec(&ITEMS)
    end

    def make_screen(session) = Screen.new(session)

    # The front page's menu on the whole screen down to the footer bar.
    def menu(items, back: nil, index: nil, hint: nil)
      screen.full_menu(items, top: MASTHEAD_ROWS + 2, index: index, back: back, hint: hint)
    end

    private

    # The newest posts, as many as the screen holds over the menu items;
    # [nil] for none.
    def latest_posts
      room  = screen.footer_row - MASTHEAD_ROWS - 1 - 2 - 2 - menu_size
      found = posts.all(published: shown, limit: room)
      found.empty? ? [nil] : found
    end

    def menu_size
      self.class.main_menu.entries.count { |e| !e.heading && (e.shown.nil? || instance_exec(&e.shown)) }
    end

    def motto
      gap = COLS - 1 - 2 - MOTTO.length - right.length
      " #{MOTTO}#{GR}#{' ' * [gap, 1].max}#{right}"
    end

    def rule_label(text) = "#{text} #{'─' * (COLS - 4 - text.length)}"

    def headline_label(post)
      draft = post.published? ? '' : "#{RD}u#{LG} "
      "#{GR}#{post.created_at.localtime.strftime('%m-%d')}#{LG} #{draft}#{post.title}"
    end

    def post_about(post) = post.summary.empty? ? categories.find(post.category).name : post.summary

    def unpublished_label = "unpublished #{GR}(#{posts.total(published: false)})#{LG}"

    def log_out_label = 'log out'

    # A post read under its footer; after an edit or a change of its
    # state it is shown again, until the caller goes back or deletes it.
    # True when it was changed or deleted.
    def show(id)
      changed = false
      loop do
        post = posts.find(id)
        return changed unless readable?(post)

        case read(post)
        when 'c' then show_qr(post)
        when 'e' then changed = compose(post) || changed
        when 'p' then changed = publish?(post, !post.published?) || changed
        when 'd' then return true if delete?(post)
        else return changed
        end
      end
    end

    # The post under its footer, with the key of its QR code when it is
    # published and the editor's keys: the key of the action taken.
    def read(post)
      qr      = post.published? ? [['c', qr_label]] : []
      actions = user ? editor_actions(post) : []
      screen.view(categories.find(post.category).name.upcase, post_lines(post), right: right, actions: qr + actions)
    end

    # The editor's row is full: the QR code is just "qr" there.
    def qr_label = user ? 'qr' : 'qr code of its web page'

    def editor_actions(post) = [%w[e edit], ['p', post.published? ? 'unpublish' : 'publish'], %w[d delete]]

    def saved_new(post) = "Saved as number #{post.id}, unpublished. Open it and press P to publish it."

    def draft_choice(draft, post)
      title(post ? "EDIT POST #{post.id}" : 'NEW POST', right)
      puts
      items = draft_items(draft, post)
      items.concat(body_preview(draft[:body], room: draft_rows - items.size))
      choice = screen.full_menu(items, top: 3, index: @draft_index, back: 'q', hint: 'crsr: choose  return: take  q: quit')
      @draft_index = items.index { |i| i.value == choice }
      choice
    end

    def draft_items(draft, post)
      [*draft_fields(draft),
       S.heading('─' * (COLS - 4)),
       S.item('view, as a reader will', key: 'v', value: 'v', about: 'the post as it will show'),
       S.item(post ? 'save' : "save#{GR}, unpublished#{LG}", key: 'w', value: 'w', about: save_about(post)),
       S.item('quit', key: 'q', value: 'q', about: 'keep the draft for later, or discard it')]
    end

    def draft_fields(draft)
      summary = draft[:summary].empty? ? '-' : draft[:summary]
      [field('t', 'title   ', draft[:title], 'the title of the post'),
       field('c', 'category', categories.find(draft[:category]).name, 'pick another category'),
       field('s', 'summary ', summary, 'one paragraph over the body'),
       field('b', 'body    ', "#{draft[:body].lines.size} lines", 'the text, in markdown')]
    end

    def save_about(post) = post ? 'keep the changes' : 'publish it with P later'

    def leave_choice = screen.footer_choice('Keep the draft for later?', [%w[k keep], %w[d discard], %w[b back]], back: 'b')

    def field(key, name, value, about) = S.item("#{GR}#{name}#{LG} #{value}", key: key, value: key, about: about)

    # The rows of the draft's menu: from the third row to the footer, less
    # the about row and the footer.
    def draft_rows = screen.footer_row - 3 + 1 - 2

    # The first lines of the body under a rule, as many as +room+ holds.
    def body_preview(body, room:)
      return [] if room < 3

      lines = body.lines.map { |l| plain(l.chomp) }.reject(&:empty?).first(room - 1)
      lines = ['(no text yet)'] if lines.empty?
      [S.heading(rule_label('body')), *lines.map { |l| S.heading("#{GR}#{l}") }]
    end
  end
end
