# frozen_string_literal: true

module UI
  module Modern
    module Discovery
      # The Global Discovery side of the chooser: the logo, the chooser, and
      # the tree of TTG_DISCOVERY.md §7: every board, Search, Browse (by
      # Terminal, Software, Country, Network), New this week, a Random board,
      # Recently died, the Graveyard, and the Sources. TAB turns back to our
      # own boards, / searches at once, Q or Esc hangs up.
      class Home < Screen
        SOURCES_NOTE = 'where the list comes from, and opting out'
        # The most letters of a search.
        SEARCH_MAX = 60

        key(:up) { open? ? @index = (@index - 1) % @items.size : pass }
        key(:down) { open? ? @index = (@index + 1) % @items.size : pass }
        key(:enter) { open? ? @items[@index].action.call : pass }
        key('/') { open? ? search : pass }
        key(:tab, :right, :left, 'g', 'G') { pages.switch }
        key(:escape, 'q', 'Q') { quit }

        def initialize(ctx)
          super()
          @ctx   = ctx
          @index = 0
        end

        def lines
          return off unless open?

          @items = items
          lines = [*masthead(:discovery), '']
          @items.each_with_index { |entry, i| lines << menu_row(entry.label, entry.note, 16, lit: i == @index) }
          lines.push('', "#{DIM}The world's telnet BBSes, called daily: " \
                         "#{GREEN}●#{DIM} online #{YELLOW}◐#{DIM} flaky #{RED}✗#{DIM} down † dead ? new#{RESET}")
          lines.fill('', lines.size...(rows - 3))
          lines.push(rule, "#{DIM}↑↓ choose   RETURN open   / search   TAB own servers   Q hang up#{RESET}")
        end

        private

        # Whether the catalog could be opened: without it only TAB and Q work.
        def open? = !@ctx.browse.nil?

        def browse = @ctx.browse

        def items = finding_items + passing_items

        # Every board, Search, Browse and New this week.
        def finding_items
          all = browse.search('')
          online = all.count { |b| b.state == 'online' }
          [item('Every board', "#{all.size} listed · #{online} online, the dead ones apart") { every },
           item('Search…', 'words and tags: petscii hu online · synchronet · all') { search },
           item('Browse', 'by Terminal · Software · Country · Network') { browse_menu },
           item('New this week', count(browse.new_this_week.size)) { new_this_week }]
        end

        # A random board, the dead ones, and where the list comes from.
        def passing_items
          [item('Random board', 'an online one, at random') { random },
           item('Recently died', count(browse.recently_died.size)) { recently_died },
           item('Graveyard', "#{count(browse.graveyard.size)}, never deleted") { graveyard },
           item('Sources', SOURCES_NOTE) { show(Sources.new(browse)) }]
        end

        def item(label, note, &action) = MenuView::Item.new(label: label, note: note, action: action)

        def count(n) = "#{n} board#{'s' unless n == 1}"

        def every = list('EVERY BOARD') { |state| browse.search('', state: state) }

        def search
          text = read_line('Search:', max: SEARCH_MAX, hint: ListView::SEARCH_HINT)&.strip
          push(ListView.search(@ctx, text)) if text && !text.empty?
        end

        def browse_menu
          all = [item('All', 'every board, every state') { list('ALL BOARDS') { |s| browse.all(state: s) } },
                 item('All PETSCII', 'PETSCII only') { list('ALL PETSCII') { |s| browse.all(petscii: true, state: s) } }]
          push(MenuView.new('BROWSE', all + axis_items))
        end

        # One item an axis of Browse, its biggest facets as the note.
        def axis_items
          browse.axes.map do |axis, spec|
            item("by #{spec[:label]}", browse.facets(axis).first(4).map { |f| "#{f.label} #{f.count}" }.join(' · ')) do
              facets(axis, spec[:label])
            end
          end
        end

        def facets(axis, label)
          items = browse.facets(axis).map do |f|
            item(f.label, count(f.count)) { list("BY #{label.upcase} › #{f.label}") { |s| browse.tagged(f.tag, state: s) } }
          end
          return nothing("No board has a #{label.downcase} yet.") if items.empty?

          push(MenuView.new("BROWSE › BY #{label.upcase}", items))
        end

        def new_this_week
          list('NEW THIS WEEK', empty: 'No board joined the lists this week.') do |s|
            browse.new_this_week.select { |b| s.nil? || b.state == s }
          end
        end

        def random
          board = browse.random
          return nothing('No board answered our last call.') unless board

          BoardPage.open(self, @ctx, board.id, path: 'RANDOM BOARD')
        end

        def recently_died
          list('RECENTLY DIED', empty: 'No board died in the last 30 days.') do |s|
            browse.recently_died.select { |b| s.nil? || b.state == s }
          end
        end

        def graveyard
          list('GRAVEYARD', empty: 'The graveyard is empty.') { |s| browse.graveyard.select { |b| s.nil? || b.state == s } }
        end

        def list(path, empty: 'No board here.', &) = push(ListView.new(@ctx, path, empty: empty, &))

        def nothing(text)
          show(Lines.new([crumbs(''), rule, '', "#{TEXT}#{text}#{RESET}", '', "#{DIM}Press a key.#{RESET}"]))
        end

        def off
          [*masthead(:discovery), '', "#{TEXT}Global Discovery is resting: its catalog cannot be opened now.#{RESET}",
           '', "#{DIM}TAB own servers   Q hang up#{RESET}"]
        end
      end
    end
  end
end
