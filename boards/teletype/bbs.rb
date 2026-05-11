# frozen_string_literal: true

require 'bbs'
require 'time'
require_relative 'lib/repository/online_users_repository'
require_relative 'lib/repository/message_board_repository'
require_relative 'lib/repository/wiki_repository'
require_relative 'lib/repository/catalog_repository'

include BBS::Color

ONLINE   = OnlineUsersRepository.new
MESSAGES = MessageBoardRepository.new(ENV.fetch('MESSAGES_PATH', 'data/messages.dat'))
WIKI     = WikiRepository.new(token: ENV['WEBAPP_WIKIJS_TOKEN'])
CATALOG  = CatalogRepository.new

MENU_ITEMS = [
  'Messages', 'Post Message', 'Blog Posts',
  'HowTo Guides', 'Game Catalog', 'Online Users',
  'System Info', 'Exit'
].freeze

SEP_X  = 21
CONT_X = 23
CONT_Y = 3

def fmt_date(iso)
  Time.parse(iso.to_s).strftime('%Y-%m-%d')
rescue
  iso.to_s
end

def wrap_wiki(text, width)
  clean = text.to_s
              .gsub(/\[([^\]]+)\]\([^)]+\)/, '\1')
              .gsub(/[#*_`~>|\\]/, '')
              .gsub(/\r?\n+/, ' ')
              .strip
  words = clean.split
  lines = []
  line  = +''
  words.each do |word|
    if line.empty?
      line << word
    elsif line.length + 1 + word.length <= width
      line << ' ' << word
    else
      lines << line.dup
      line = +word
    end
  end
  lines << line unless line.empty?
  lines
end

BBS.configure do |c|
  c.on_session_end = ->(session) { ONLINE.remove(session.session_id) }

  c.flow = BBS::Flow.define do
    big_banner 'TELETYPE BBS', style: :success

    ask :username, prompt: 'Name (blank for Anonymous)',
        transform: ->(v) { v.strip.empty? ? 'Anonymous' : v.strip[0...20] }

    call { |ctx| ONLINE.add(ctx[:session_id], ctx[:username]) }

    call do |ctx, runner|
      session    = runner.instance_variable_get(:@session)
      username   = ctx[:username]
      session_id = ctx[:session_id]

      tui = BBS::TUI.define do
        init do
          @menu_sel    = 0
          @state       = :idle
          @prev_state  = :idle
          @items       = []
          @item_sel    = 0
          @scroll      = 0
          @detail      = []
          @page_header = ''
          @page_meta   = ''
          @input       = ''
          @status      = ''
          @username    = username
          @session_id  = session_id
        end

        render do
          cont_w = term_cols - CONT_X - 1
          cont_h = term_rows - CONT_Y - 4

          clear

          bar y: 1,
              content: "  TELETYPE BBS  │  #{@username}  │  #{ONLINE.count} online",
              style: :success

          menu_labels = MENU_ITEMS.map { |item| item[0, 15] }
          list menu_labels, x: 2, y: CONT_Y, selected: @menu_sel,
               style: :gray, highlight: :white

          (CONT_Y..CONT_Y + cont_h).each { |r| text c(:gray, '│'), x: SEP_X, y: r }

          case @state
          when :idle
            text c(:gray, 'Navigate with ↑↓, select with Enter'),
                 x: CONT_X, y: CONT_Y + cont_h / 2

          when :messages
            text c(:cyan, '── Message Board ──'), x: CONT_X, y: CONT_Y
            (@items[@scroll, cont_h - 2] || []).each_with_index do |line, i|
              text line[0, cont_w], x: CONT_X, y: CONT_Y + 2 + i
            end
            text c(:gray, "#{@items.size} msg(s)  ↑↓ scroll  q back"),
                 x: CONT_X, y: CONT_Y + cont_h

          when :new_msg
            text c(:cyan, '── Post Message ──'), x: CONT_X, y: CONT_Y
            text c(:gray,'Type message and press Enter.  Esc cancels.'),
                 x: CONT_X, y: CONT_Y + 2
            text c(:white, "#{@username}: #{@input}_"), x: CONT_X, y: CONT_Y + 4
            text c(:green, @status), x: CONT_X, y: CONT_Y + 6 unless @status.empty?

          when :blog, :howto
            color    = @state == :blog ? :blue : :magenta
            hdr      = @state == :blog ? '── Blog Posts ──' : '── HowTo Guides ──'
            text c(color, hdr), x: CONT_X, y: CONT_Y
            if @items.empty?
              text c(:gray, 'No items found.'), x: CONT_X, y: CONT_Y + 2
            else
              list_h   = cont_h - 5
              visible  = @items[@scroll, list_h] || []
              labels   = visible.map { |p| p.title[0, cont_w - 2] }
              list labels, x: CONT_X, y: CONT_Y + 2,
                   selected: @item_sel - @scroll, style: :gray, highlight: :white
              if (page = @items[@item_sel])
                hint = page.description.to_s.strip[0, cont_w]
                text c(:gray, hint), x: CONT_X, y: CONT_Y + cont_h - 2 unless hint.empty?
              end
              text c(:gray, '↑↓ navigate  Enter read  q back'),
                   x: CONT_X, y: CONT_Y + cont_h
            end

          when :page_view
            text c(:cyan, @page_header[0, cont_w]), x: CONT_X, y: CONT_Y
            text c(:gray, @page_meta[0, cont_w]),   x: CONT_X, y: CONT_Y + 1
            (@detail[@scroll, cont_h - 3] || []).each_with_index do |l, i|
              text c(:gray, l[0, cont_w]), x: CONT_X, y: CONT_Y + 3 + i
            end
            text c(:gray, "#{@scroll + 1}/#{@detail.size}  ↑↓ scroll  q back"),
                 x: CONT_X, y: CONT_Y + cont_h

          when :games
            text c(:cyan, '── Game Catalog ──'), x: CONT_X, y: CONT_Y
            if @items.empty?
              text c(:gray, 'No games found.'), x: CONT_X, y: CONT_Y + 2
            else
              game = @items[@item_sel]
              text c(:white, "#{@item_sel + 1}/#{@items.size}  #{game.title}"[0, cont_w]),
                   x: CONT_X, y: CONT_Y + 1
              text c(:gray, "#{game.platform}  #{game.author}"[0, cont_w]),
                   x: CONT_X, y: CONT_Y + 2
              wrap_wiki(game.desc.to_s, cont_w).first(cont_h - 10).each_with_index do |l, i|
                text c(:gray, l), x: CONT_X, y: CONT_Y + 4 + i
              end
              badges = []
              badges << c(:green,   '[▶ Play]')     unless game.play_path.empty?
              badges << c(:yellow,  '[⬇ Download]') unless game.download_path.empty?
              badges << c(:blue,    '[Source]')     unless game.source_path.empty?
              badges << c(:magenta, '[Docs]')       unless game.docs_path.empty?
              text badges.join('  '), x: CONT_X, y: CONT_Y + cont_h - 5
              text c(:gray, "↑↓ navigate  q back"), x: CONT_X, y: CONT_Y + cont_h
            end

          when :online
            text c(:yellow, '── Online Users ──'), x: CONT_X, y: CONT_Y
            @items.each_with_index do |uname, i|
              you = uname == @username ? c(:gray, ' ← you') : ''
              text c(:white, uname) + you, x: CONT_X, y: CONT_Y + 2 + i
            end
            text c(:gray, "#{@items.size} user(s) online  q back"),
                 x: CONT_X, y: CONT_Y + cont_h

          when :sysinfo
            text c(:magenta, '── System Info ──'), x: CONT_X, y: CONT_Y
            @items.each_with_index do |row, i|
              text c(:gray, row[0, cont_w]), x: CONT_X, y: CONT_Y + 2 + i
            end
            text c(:gray, 'q back'), x: CONT_X, y: CONT_Y + cont_h
          end

          bar y: term_rows, content: '  ↑↓ Navigate  Enter Select  q Back/Quit  r Refresh',
              style: :muted
        end

        # ── Navigation ────────────────────────────────────────────────────────

        key(:up) do
          case @state
          when :blog, :howto
            if @item_sel > 0
              @item_sel -= 1
              @scroll = @item_sel if @item_sel < @scroll
            end
          when :games
            @item_sel = (@item_sel - 1) % @items.size if @items.any?
          when :messages
            @scroll = [@scroll - 1, 0].max
          when :page_view
            @scroll = [@scroll - 1, 0].max
          else
            @menu_sel = (@menu_sel - 1) % MENU_ITEMS.size
          end
        end

        key(:down) do
          case @state
          when :blog, :howto
            if @item_sel < @items.size - 1
              @item_sel += 1
              list_h = (term_rows - CONT_Y - 4) - 5
              @scroll = @item_sel - list_h + 1 if @item_sel >= @scroll + list_h
            end
          when :games
            @item_sel = (@item_sel + 1) % @items.size if @items.any?
          when :messages
            cont_h = term_rows - CONT_Y - 4
            max = [@items.size - (cont_h - 2), 0].max
            @scroll = [@scroll + 1, max].min
          when :page_view
            cont_h = term_rows - CONT_Y - 4
            max = [@detail.size - (cont_h - 3), 0].max
            @scroll = [@scroll + 1, max].min
          else
            @menu_sel = (@menu_sel + 1) % MENU_ITEMS.size
          end
        end

        key(:enter) do
          if @state == :new_msg
            if @input.strip.empty?
              @status = 'Message cannot be empty.'
            else
              MESSAGES.append(@username, @input.strip[0...200])
              @status = 'Sent!'
              @input  = ''
            end
          elsif (@state == :blog || @state == :howto) && @items[@item_sel]
            page         = @items[@item_sel]
            body         = WIKI.content(page.id)
            @detail      = wrap_wiki(body, term_cols - CONT_X - 1)
            @page_header = page.title
            @page_meta   = "#{fmt_date(page.created_at)}  #{WIKI.page_url(page.locale, page.path)}"
            @prev_state  = @state
            @scroll      = 0
            @state       = :page_view
          else
            case MENU_ITEMS[@menu_sel]
            when 'Messages'
              @items  = MESSAGES.last(30).map do |m|
                "#{c(:yellow, m.timestamp)} #{c(:white, m.username)}: #{m.text}"
              end
              @scroll = 0
              @state  = :messages
            when 'Post Message'
              @input  = ''
              @status = ''
              @state  = :new_msg
            when 'Blog Posts'
              @items    = WIKI.list('blog')
              @item_sel = 0
              @scroll   = 0
              @state    = :blog
            when 'HowTo Guides'
              @items    = WIKI.list('howto')
              @item_sel = 0
              @scroll   = 0
              @state    = :howto
            when 'Game Catalog'
              @items    = CATALOG.fetch
              @item_sel = 0
              @state    = :games
            when 'Online Users'
              @items = ONLINE.snapshot.sort.map { |_, name| name }
              @state = :online
            when 'System Info'
              @items = [
                "Online users  #{ONLINE.count}",
                "Messages      #{MESSAGES.count}",
                "Wiki          https://wiki.teletypegames.org",
                "Games API     https://teletypegames.org",
                "Platform      #{RUBY_PLATFORM}",
                "Ruby          #{RUBY_VERSION}"
              ]
              @state = :sysinfo
            when 'Exit'
              :halt
            end
          end
        end

        key(:escape) do
          if @state == :idle
            :halt
          elsif @state == :page_view
            @scroll = 0
            @state  = @prev_state
            nil
          else
            @state = :idle
            nil
          end
        end

        key('q') do
          if @state == :new_msg
            @input << 'q' if @input.length < 200
            nil
          elsif @state == :idle
            :halt
          elsif @state == :page_view
            @scroll = 0
            @state  = @prev_state
            nil
          else
            @state = :idle
            nil
          end
        end

        key('r') do
          if @state == :new_msg
            @input << 'r' if @input.length < 200
            nil
          else
            case @state
            when :messages
              @items  = MESSAGES.last(30).map do |m|
                "#{c(:yellow, m.timestamp)} #{c(:white, m.username)}: #{m.text}"
              end
              @scroll = 0
            when :online
              @items = ONLINE.snapshot.sort.map { |_, name| name }
            when :blog
              @items = WIKI.list('blog'); @item_sel = 0; @scroll = 0
            when :howto
              @items = WIKI.list('howto'); @item_sel = 0; @scroll = 0
            when :games
              @items = CATALOG.fetch; @item_sel = 0
            end
            nil
          end
        end

        key(:backspace) do
          @input.chop! if @state == :new_msg && !@input.empty?
        end

        (' '..'~').each do |ch|
          next if ch == 'q' || ch == 'r'
          key(ch) do
            @input << ch if @state == :new_msg && @input.length < 200
          end
        end
      end

      BBS::TUIRunner.new(session, session_id, tui).run
    end

    say 'Goodbye!', style: :muted
  end
end

BBS.start
