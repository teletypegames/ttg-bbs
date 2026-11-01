# frozen_string_literal: true

module UI
  module Modern
    module Discovery
      # The Global Discovery side of the chooser: the logo, the chooser, and
      # the tree of TTG_DISCOVERY.md §7: every board, Search, Browse (by
      # Terminal, Software, Country, Network), New this week, a Random board,
      # Recently died, the Graveyard, and the Sources. TAB turns back to our
      # own boards, / searches at once, Q or Esc hangs up.
      class Home
        include Style

        SOURCES_NOTE = 'where the list comes from, and opting out'

        def initialize(session, browse, dials)
          @session = session
          @ctx     = Context.new(session: session, browse: browse, dials: dials)
          @index   = 0
        end

        # Runs until the caller hangs up (nil) or turns to the other side of
        # the chooser (:switch).
        def run
          return off unless @ctx.browse

          loop do
            items = self.items
            draw(items)
            case key
            when :up then @index = (@index - 1) % items.size
            when :down then @index = (@index + 1) % items.size
            when :enter then items[@index].action.call
            when '/' then search
            when :tab, :right, :left, 'g', 'G' then return :switch
            when :escape, 'q', 'Q' then return goodbye
            end
          end
        end

        private

        def browse = @ctx.browse

        def items
          all = browse.search('')
          online = all.count { |b| b.state == 'online' }
          [
            item('Every board', "#{all.size} listed · #{online} online, the dead ones apart") { every },
            item('Search…', 'words and tags: petscii hu online · synchronet · all') { search },
            item('Browse', 'by Terminal · Software · Country · Network') { browse_menu },
            item('New this week', count(browse.new_this_week.size)) { new_this_week },
            item('Random board', 'an online one, at random') { random },
            item('Recently died', count(browse.recently_died.size)) { recently_died },
            item('Graveyard', "#{count(browse.graveyard.size)}, never deleted") { graveyard },
            item('Sources', SOURCES_NOTE) { Sources.new(@session, browse).run }
          ]
        end

        def item(label, note, &action) = MenuView::Item.new(label: label, note: note, action: action)

        def count(n) = "#{n} board#{'s' unless n == 1}"

        def draw(items)
          lines = [*masthead(:discovery), '']
          items.each_with_index do |entry, i|
            lit = i == @index
            lines << "#{lit ? "#{SELECT}#{GREEN}▸ " : '  '}#{BOLD}#{fit(entry.label, 16)}#{RESET}" \
                     "#{SELECT if lit}#{DIM}#{fit(entry.note, width - 18)}#{RESET}"
          end
          lines.push('', "#{DIM}The world's telnet BBSes, called daily: " \
                         "#{GREEN}●#{DIM} online #{YELLOW}◐#{DIM} flaky #{RED}✗#{DIM} down † dead ? new#{RESET}")
          lines.fill('', lines.size...(rows - 3))
          lines.push(rule, "#{DIM}↑↓ choose   RETURN open   / search   TAB own servers   Q hang up#{RESET}")
          paint(lines)
        end

        def every = list('EVERY BOARD') { |state| browse.search('', state: state) }

        def search
          text = Prompt.new(@session).read('Search:', '', hint: ListView::SEARCH_HINT)
          ListView.search(@ctx, text).run if text && !text.empty?
        end

        def browse_menu
          items = browse.axes.map do |axis, spec|
            item("by #{spec[:label]}", browse.facets(axis).first(4).map { |f| "#{f.label} #{f.count}" }.join(' · ')) do
              facets(axis, spec[:label])
            end
          end
          MenuView.new(@session, 'BROWSE', items).run
        end

        def facets(axis, label)
          items = browse.facets(axis).map do |f|
            item(f.label, count(f.count)) { list("BY #{label.upcase} › #{f.label}") { |s| browse.tagged(f.tag, state: s) } }
          end
          return nothing("No board has a #{label.downcase} yet.") if items.empty?

          MenuView.new(@session, "BROWSE › BY #{label.upcase}", items).run
        end

        def new_this_week
          list('NEW THIS WEEK', empty: 'No board joined the lists this week.') do |s|
            browse.new_this_week.select { |b| s.nil? || b.state == s }
          end
        end

        def random
          board = browse.random
          return nothing('No board answered our last call.') unless board

          BoardPage.new(@ctx, board.id, path: 'RANDOM BOARD').run
        end

        def recently_died
          list('RECENTLY DIED', empty: 'No board died in the last 30 days.') do |s|
            browse.recently_died.select { |b| s.nil? || b.state == s }
          end
        end

        def graveyard
          list('GRAVEYARD', empty: 'The graveyard is empty.') { |s| browse.graveyard.select { |b| s.nil? || b.state == s } }
        end

        def list(path, empty: 'No board here.', &) = ListView.new(@ctx, path, empty: empty, &).run

        def nothing(text)
          paint([crumbs(''), rule, '', "#{TEXT}#{text}#{RESET}", '', "#{DIM}Press a key.#{RESET}"])
          key
        end

        def off
          paint([*masthead(:discovery), '', "#{TEXT}Global Discovery is resting: its catalog cannot be opened now.#{RESET}",
                 '', "#{DIM}TAB own servers   Q hang up#{RESET}"])
          loop do
            case key
            when :tab, :right, :left, 'g', 'G' then return :switch
            when :escape, 'q', 'Q' then return goodbye
            end
          end
        end

        def goodbye
          @session.write("#{RESET}\e[2J\e[H\r\n#{pad}#{GREEN}TTG GATE BBS#{RESET}#{DIM}: line closed. See you.#{RESET}\r\n\r\n")
          nil
        end
      end
    end
  end
end
