# frozen_string_literal: true

require_relative 'wording'

module UI
  # The board on a Commodore 64: PETSCII on a 40×25 screen, single-key
  # menus and numbered lists, the way the C64 boards of the eighties were.
  # It works on the same TeletypeBBS as the modern face. A call: the logon
  # scans, the main menu (the clubhouse, or a menu of text) and what its
  # keys open, then leaving the clubhouse.
  class Petscii < BBS::Petscii::Face
    # Two rows of two sections, each with its colour: the keys of a section
    # and its bar wear it, so the eye finds the group first. Each item:
    # its key, its label and the line about it under the menu.
    MENU = [
      [['messages', GN, [['m', 'message boards', 'read and post on the boards'],
                         ['e', 'e-mail', 'your letters; feedback to the sysop'],
                         ['o', 'oneliners', 'a line on the wall for every caller'],
                         ['l', 'live chat', 'talk with whoever is on line'],
                         ['i', 'irc channel', 'the irc channel, from a c64'],
                         ['p', 'page the sysop', 'call the sysop to a chat']]],
       ['board', CY, [['u', 'bulletins', 'the bulletins of the board'],
                      ['d', 'dev log', 'what we are making, commit by commit'],
                      ['n', 'network', 'our boards: games, wiki, blog, art']]]],
      [['people', PU, [['c', 'callers & users', 'who is on line, who called'],
                       ['v', 'voting booth', 'the polls of the board'],
                       ['s', 'you & your name', 'your stats, profile and registration'],
                       ['h', 'hall of fame', 'the top callers and posters']]],
       ['more', YE, [['r', 'doors', 'games and programs behind the doors'],
                     ['t', 'ttg master', 'ask the sysop where things are'],
                     ['y', 'system info', 'the numbers of this board'],
                     ['?', 'help', 'how the keys of this board work'],
                     ['q', 'log off', 'hang up. see you on the wire!']]]]
    ].freeze
    SYSOP = ['z', 'sysop console', 'the nodes, a broadcast: sysops only'].freeze
    # The width of the menu: two columns of COLS / 2 less one.
    MENU_WIDTH = COLS - 1

    HELP = [
      'The main menu is the clubhouse: each item a room of the club. CRSR up and down (and left and right) ' \
      'lights a room, RETURN opens it, and the letter in front of a room opens it at once too. ? is this help, ' \
      'Y the system info, and * swaps the pictures for a menu of plain text and back (for a terminal that ' \
      'cannot show the C64 graphics).',
      '',
      'Lists are numbered: CRSR, or type the number, then RETURN. CRSR left and right turn the pages, Q goes ' \
      'back. The <- key and RUN/STOP go back too.',
      '',
      'Long texts stop at every screenful: RETURN shows more, Q leaves.',
      '',
      'Posts and letters take several lines: an empty line, or a lone dot, ends the text.',
      '',
      'In the live chat what the others say shows up above your line. An empty line leaves.',
      '',
      'Our games and files are on the WarpEngine BBS, port 2329: it sends them by XMODEM onto a C64 disk. ' \
      'N, the town map, shows every board of the network.',
      '',
      'The board has a modern face too, with windows: call with a PC terminal and choose 1.',
      '',
      'Lost? T asks the TTG Master.'
    ].freeze

    ACTIONS = {
      'm' => :read_boards,
      'e' => :read_mail,
      'o' => :wall,
      'l' => :live_chat,
      'i' => :listen_irc,
      'p' => :page_sysop,
      'n' => :show_network,
      'u' => :read_bulletins,
      'd' => :read_dev_log,
      'c' => :people,
      'v' => :voting_booth,
      's' => :you,
      'h' => :fame,
      'r' => :door_list,
      't' => :ask_master,
      'y' => :system_info,
      '?' => :help,
      'z' => :sysop_console
    }.freeze

    # The rooms the clubhouse shows as pictures (Clubhouse) instead of
    # the text screens of ACTIONS.
    GRAPHICS = { 'n' => :town_map, 'r' => :games_room, 'h' => :trophies }.freeze

    title('TELETYPE BBS') { node_text }

    def run
      context[:plain] = capitals?(name)
      Clubhouse.text_mode(session)
      loop do
        doing('At the main menu')
        k = text_menu? ? text_main_menu : clubhouse_menu
        next context[:plain] = !text_menu? if k == '*'
        break if %w[q x].include?(k) && logoff?

        enter_room(k) if ACTIONS[k]
      end
      Leaving.play(self)
    end

    def name = identity.name || MemberService::ANONYMOUS
    def registered? = signed_in?
    def anonymous? = name == MemberService::ANONYMOUS
    def sysop? = board.sysop?(identity)
    def session_id = context[:session_id]

    private

    # The room of key +k+: a picture of the clubhouse, or its card and
    # then its text screen.
    def enter_room(k)
      return send(GRAPHICS[k]) if !text_menu? && GRAPHICS[k]

      unless text_menu?
        Clubhouse::Cards.show(session, Clubhouse::Cards::KEYS[k], context[:cards] ||= Set.new)
        Clubhouse.text_mode(session)
      end
      send(ACTIONS[k])
    end

    def doing(text) = online.activity(session_id, "#{text} (C64)")

    # Whether a name came in capitals only: UltimateTerm in its ANSI mode
    # swaps the case of what is typed (and cannot show the graphics), so its
    # caller gets the text menu.
    def capitals?(text) = text.to_s.count('A-Z') >= 2 && !text.to_s.match?(/[a-z]/)

    # The lowercase menu of text instead of the clubhouse: chosen with *,
    # or for a caller whose letters come in capitals (UltimateTerm in its
    # ANSI mode swaps the case and cannot show the graphics).
    def text_menu? = context[:plain] == true

    # The main menu as the clubhouse (Clubhouse::MainMenu); the key taken.
    def clubhouse_menu
      @unread = registered? ? mail.unread_count(name, sysop: sysop?) : 0
      ring_for_mail
      menu = Clubhouse::MainMenu.new(
        session,
        scene.scene(name, registered: registered?, sysop: sysop?),
        node: online.node(session_id)&.number,
        name: name
      )
      @lit = menu.run(lit: @lit, unread: @unread) || @lit
    end

    # New mail since the last look rings once, as on the old boards.
    def ring_for_mail
      seen = context[:mail_seen] || @unread
      context[:mail_seen] = @unread
      bell if @unread.to_i > seen.to_i
    end

    def node_text
      node = online.node(session_id)
      "#{"node #{node.number} " if node}#{Time.now.strftime('%H:%M')}"
    end

    # The front page: the title bar, the caller and what is going on, then
    # the sections as a cursor menu in two columns. The key of the item
    # taken; nil for ← or RUN/STOP.
    def text_main_menu
      @unread = registered? ? mail.unread_count(name, sysop: sysop?) : nil
      home
      live_strip
      puts rule_line
      items = menu_items
      index = items.index { |i| i.selectable? && i.value == @lit }
      @lit  = menu(
        items,
        columns: 2,
        height:  items.size / 2,
        index:   index,
        exits:   { 'x' => 'x', '*' => '*' },
        hint:    'crsr: choose  return: open  *: art'
      )
    end

    # The cells of the menu, down the left column, then down the right: a
    # section's band, its items, then the next section's band level with
    # the one beside it.
    def menu_items
      left, right = MENU.transpose.map { |sections| sections.map { |section| section_cells(*section) } }
      rows = left.zip(right).map { |l, r| [l.size, r.size].max }
      [left, right].flat_map do |column|
        column.each_with_index.flat_map { |cells, i| cells + Array.new(rows[i] - cells.size) { BBS::Selector.heading } }
      end
    end

    def section_cells(title, color, items)
      items += [SYSOP] if title == 'people' && sysop?
      [band(title, color), *items.map { |k, label, about| item(k, label, about, color) }]
    end

    # A section's name on a band of its colour.
    def band(title, color)
      BBS::Selector.heading("#{color}#{RV} #{title} #{RO}#{DG} #{'─' * (MENU_WIDTH / 2)}")
    end

    def item(key, label, about, color)
      if key == 'e' && @unread.to_i.positive?
        label = "#{label} #{GN}#{@unread}#{LG}"
        about = "#{@unread} new letter#{'s' unless @unread == 1}: #{about}"
      end
      BBS::Selector.item(label, key: key, value: key, about: about, color: color)
    end

    # Who is calling and what is happening, over the menu: the caller and
    # the nodes, the next event and the newest post, one line each. New
    # mail since the last look rings once, as on the old boards.
    def live_strip
      puts " #{WH}hi #{name}!#{LG} #{GR}·#{LG} #{YE}#{online.count}#{LG} on line#{new_mail}"
      next_event
      newest_post
    end

    def new_mail
      seen = context[:mail_seen] || @unread
      context[:mail_seen] = @unread
      return '' unless @unread.to_i.positive?

      bell if seen && @unread > seen
      " #{GR}·#{LG} #{GN}#{@unread} new mail#{LG}"
    end

    def next_event
      event = site.upcoming_events(1).first
      return unless event

      days = ((event.date - Time.now) / 86_400).ceil
      when_ = days <= 0 ? 'today' : "in #{days} day#{'s' unless days == 1}"
      puts " #{GR}next:#{LG} #{event.name[0, 38 - 7 - when_.length - 1]} #{CY}#{when_}#{LG}"
    end

    def newest_post
      _board, post = boards.latest(1).first
      return unless post

      text = "#{post.username}: #{post.text.to_s.gsub(/\s+/, ' ')}"
      puts " #{GR}new:#{LG}  #{YE}#{text[0, 38 - 7]}#{LG}"
    end

    def logoff?
      return Clubhouse.leave?(self) unless text_menu?

      choose("#{WH}log off now? (y/n)#{LG} ", %w[y n], back: 'n') == 'y'
    end

    # The text written in the full-screen editor under +heading+, at most
    # +max+ long; empty when the caller quit. The title bar stays.
    def write_text(heading, max)
      text = edit(title: heading, max: max).to_s
      title(heading)
      text
    end
  end
end

require_relative 'petscii/leaving'
require_relative 'petscii/messages'
require_relative 'petscii/chat'
require_relative 'petscii/content'
require_relative 'petscii/people'
require_relative 'petscii/more'
require_relative 'petscii/clubhouse'
