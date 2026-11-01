# frozen_string_literal: true

module UI
  module Modern
    module Discovery
      # A list of boards: the state mark, the name, the software, the country
      # and how long it has not answered, a page a screen. The arrows choose,
      # left and right (or PgUp, PgDn) turn the pages, RETURN opens the
      # board's page, / searches, F filters by state, Q or Esc goes back. The
      # list keeps its place while a board's page or a call is open.
      class ListView
        include Style

        # The F filter steps through these; nil shows every state the list has.
        FILTERS = [nil, 'online', 'flaky', 'down', 'unknown'].freeze

        # [path]   where the list is, for the top line
        # [loader] the boards, given the state filter (nil or a state)
        # [query]  the search text of a search list, else nil
        # [empty]  what an empty list says
        SEARCH_HINT = 'Words and tags: petscii hu online · synchronet · fidonet · all (the dead too)'

        # A list of the search +text+.
        def self.search(ctx, text)
          new(ctx, "SEARCH “#{text}”", query: text, empty: 'Nothing found. `all` takes the dead boards in too.') do |state|
            ctx.browse.search(text, state: state)
          end
        end

        def initialize(ctx, path, query: nil, empty: 'No board here.', &loader)
          @ctx     = ctx
          @session = ctx.session
          @path    = path
          @query   = query
          @empty   = empty
          @loader  = loader
          @state   = nil
          @index   = 0
          load
        end

        def run
          loop do
            draw
            case key
            when :up then @index = [@index - 1, 0].max
            when :down then @index = (@index + 1).clamp(0, [@boards.size - 1, 0].max)
            when :left, :page_up then @index = [@index - per_page, 0].max
            when :right, :page_down then @index = (@index + per_page).clamp(0, [@boards.size - 1, 0].max)
            when :home then @index = 0
            when :end then @index = [@boards.size - 1, 0].max
            when :enter then open
            when '/' then search
            when 'f', 'F' then filter
            when :escape, 'q', 'Q' then return
            end
          end
        end

        private

        def load
          id = @boards&.dig(@index)&.id
          @boards = @loader.call(@state)
          @twins  = @boards.group_by(&:title).select { |_, l| l.size > 1 }.transform_values { |l| l.map(&:port).tally }
          @index = (id && @boards.index { |b| b.id == id }) || @index.clamp(0, [@boards.size - 1, 0].max)
        end

        def per_page = [rows - 5, 3].max

        def open
          board = @boards[@index]
          return unless board

          BoardPage.new(@ctx, board.id, path: @path).run
          load
        end

        # In a search list, / edits the words; elsewhere it starts a search
        # of its own, and Q comes back here.
        def search
          text = Prompt.new(@session).read('Search:', @query.to_s, hint: SEARCH_HINT)
          return if text.nil? || text.empty?

          if @query
            @query = text
            @path  = "SEARCH “#{text}”"
            @index = 0
            @loader = ->(state) { @ctx.browse.search(@query, state: state) }
            load
          else
            ListView.search(@ctx, text).run
          end
        end

        def filter
          @state = FILTERS[(FILTERS.index(@state).to_i + 1) % FILTERS.size]
          @index = 0
          load
        end

        def draw
          pages = [(@boards.size + per_page - 1) / per_page, 1].max
          page  = @index / per_page
          right = "#{@boards.size} board#{'s' unless @boards.size == 1}" \
                  "#{"  ·  #{@state}" if @state}#{"  ·  page #{page + 1}/#{pages}" if pages > 1}"
          lines = [crumbs(@path, right), rule]
          if @boards.empty?
            lines.push('', "#{TEXT}#{@state ? "No #{@state} board here." : @empty}#{RESET}")
          else
            now = Time.now.to_i
            @boards[page * per_page, per_page].each_with_index do |b, i|
              lines << row(b, (page * per_page) + i == @index, now)
            end
          end
          lines.fill('', lines.size...(rows - 3))
          lines.push(rule, hints)
          paint(lines)
        end

        def row(board, lit, now)
          status = board.status(now)
          status = '' if status == 'flaky'
          cc     = board.country.to_s.upcase.ljust(2)
          rest   = width - 2 - 2 - 4 - 22
          name   = [rest * 3 / 5, 12].max
          soft   = [rest - name, 0].max
          bg     = lit ? SELECT : ''
          ports  = @twins[board.title]
          title  = if ports.nil? then board.title
                   elsif ports[board.port] > 1 then "#{board.title} · #{board.host}"
                   else "#{board.title} :#{board.port}"
                   end
          "#{bg}#{mark(board)}#{bg} #{lit ? GREEN + BOLD : TEXT}#{fit(title, name)}#{RESET}#{bg} " \
            "#{DIM}#{fit(board.software.to_s, soft)} #{TEXT}#{cc}#{RESET}#{bg}  " \
            "#{board.state == 'down' ? RED : DIM}#{fit(status, 22)}#{RESET}"
        end

        def hints
          "#{DIM}↑↓ choose  ←→ page  RETURN open  / search  F state  Q back#{RESET}"
        end
      end
    end
  end
end
