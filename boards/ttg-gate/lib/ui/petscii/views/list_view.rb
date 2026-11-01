# frozen_string_literal: true

require_relative 'picker'

module UI
  module Petscii
    module Views
      # A list of boards of Global Discovery: the filter chips, a header, a
      # board a row (its number, state mark, name, country and software),
      # eight a page, the lit one a light blue bar, and under a rule the lit
      # board's name, address, state, software and terminals, and the legend
      # of the marks. RETURN or its digit opens its page (+on_open+); F steps
      # through the states when the list can be filtered.
      class ListView < Picker
        PER_PAGE = 8
        # The state marks in the graphics set.
        MARKS = {
          'online' => ['●', Canvas::LIGHT_GREEN], 'flaky' => ['○', Canvas::YELLOW], 'down' => ['╳', Canvas::RED],
          'dead' => ['┼', Canvas::GREY], 'unknown' => ['?', Canvas::LIGHT_GREY]
        }.freeze
        # The F filter steps through these; nil is every board the list has.
        FILTERS = [nil, 'online', 'flaky', 'down', 'unknown'].freeze
        STATE_COLORS = { 'online' => Canvas::LIGHT_GREEN, 'flaky' => Canvas::YELLOW, 'down' => Canvas::LIGHT_RED,
                         'dead' => Canvas::GREY, 'unknown' => Canvas::LIGHT_GREY }.freeze
        # The software of a sw: tag in five or six letters.
        SOFTWARE = { 'synchronet' => 'SYNC', 'color64' => 'COL64', 'cbase' => 'CBASE', 'cnet' => 'CNET',
                     'image' => 'IMAGE', 'mystic' => 'MYSTIC', 'enigma' => 'ENIGMA', 'renegade' => 'RENEG',
                     'iniquity' => 'INIQ', 'wwiv' => 'WWIV', 'maximus' => 'MAX', 'searchlight' => 'SLIGHT',
                     'magicka' => 'MAGICK', 'spitfire' => 'SPITF', 'x84' => 'X/84', 'wildcat' => 'WCAT',
                     'pcboard' => 'PCB', 'telegard' => 'TGARD', 'citadel' => 'CITDL', 'ftn-mailer' => 'MAILER' }.freeze
        TERMINALS = { 'petscii' => Canvas::PURPLE, 'ansi' => Canvas::LIGHT_BLUE, 'ascii' => Canvas::LIGHT_GREY,
                      'atascii' => Canvas::ORANGE }.freeze

        attr_reader :title, :state, :section

        # [title]   the band's title
        # [color]   the band's colour
        # [loader]  the boards, given the state filter (nil or a state);
        #           +filter+ says whether F filters at all
        # [chips]   the chips of the filter row before the state's:
        #           [text, colour] each
        # [details] a board's latency in ms, given its id (or nil)
        # [section] the place of the sidebar it lights
        def initialize(title:, color:, loader:, on_open:, filter: true, chips: [], details: nil, section: :discover,
                       empty: 'NOTHING HERE.', now: -> { Time.now.to_i })
          @title   = title
          @color   = color
          @loader  = loader
          @on_open = on_open
          @filter  = filter
          @chips   = chips
          @details = details || ->(_id) {}
          @section = section
          @empty   = empty
          @now     = now
          @state   = nil
          super(loader.call(nil), per_page: PER_PAGE)
          @twins = twins
        end

        def take(listing) = -> { @on_open.call(listing) }

        def handle(key)
          return super unless @filter && %w[f F].include?(key)

          @state = FILTERS[(FILTERS.index(@state).to_i + 1) % FILTERS.size]
          @items = @loader.call(@state)
          @twins = twins
          @page = @index = 0
          :redraw
        end

        # Reloads the list, keeping its place: after a dial its states move.
        def reload
          replace(@loader.call(@state))
          @twins = twins
        end

        def hint
          return [['/', true], [' FIND', false]] if @items.empty?

          parts = [['RETURN', true], [' OPEN  ', false]]
          parts += [['F', true], [' FILTER  ', false]] if @filter
          parts += [['+/-', true], [' PAGE ', false]] if pages > 1
          parts + [['/', true], [' FIND', false]]
        end

        def self.mark(state) = MARKS.fetch(state, MARKS['unknown'])

        def draw(canvas)
          Layout.band(canvas, @title, [@items.size, page_mark].reject { |s| s.to_s.empty? }.join('  '), @color)
          chips(canvas, Layout.row(1))
          canvas.text(Layout.row(2), 0, "NR S #{'NAME'.ljust(16)}CC SOFT", Canvas::DARK_GREY)
          if @items.empty?
            canvas.text(Layout.row(4), 1, @state ? "NO #{@state.upcase} BOARD HERE." : @empty, Canvas::YELLOW)
            return
          end
          on_page.each_with_index { |listing, slot| row(canvas, Layout.row(3 + slot), listing, slot) }
          info(canvas, Layout.row(4 + PER_PAGE))
        end

        private

        def twins = @items.group_by(&:title).select { |_, l| l.size > 1 }.keys

        def chips(canvas, row)
          col = Layout.runs(canvas, row, 1, [['FILTER', Canvas::GREY]]) + 1
          col = Layout.chip(canvas, row, col, 'PETSCII', Canvas::PURPLE) + 1
          @chips.each { |text, color| col = Layout.chip(canvas, row, col, text, color) + 1 }
          return unless @filter

          Layout.chip(canvas, row, col, @state ? @state.upcase : 'ALIVE', @state ? STATE_COLORS[@state] : Canvas::GREEN)
        end

        def name(listing)
          name = Layout.plain(listing.title)
          return name[0, 15] unless @twins.include?(listing.title)

          "#{name[0, 15 - listing.port.to_s.length - 1]}:#{listing.port}"
        end

        def software(listing)
          tag = listing.tags.find { |t| t.start_with?('sw:') }&.delete_prefix('sw:')
          return SOFTWARE.fetch(tag) { Layout.plain(tag)[0, 6] } if tag

          Layout.plain(listing.software.to_s.split.first)[0, 6]
        end

        def row(canvas, row, listing, slot)
          mark, color = ListView.mark(listing.state)
          number = format('%02d', ((@page * PER_PAGE) + slot + 1) % 100)
          cc = (listing.country || '--').upcase
          if slot == @index
            canvas.text(row, 0, "#{number} #{mark} #{name(listing).ljust(16)}#{cc} #{software(listing)}".ljust(Layout::WIDTH),
                        Canvas::LIGHT_BLUE, rvs: true)
          else
            Layout.runs(canvas, row, 0, [[number, Canvas::YELLOW], [' ', nil], [mark, color], [' ', nil],
                                         [name(listing).ljust(16), Canvas::WHITE], [cc, Canvas::CYAN], [' ', nil],
                                         [software(listing), Canvas::LIGHT_BLUE]])
          end
        end

        def info(canvas, top)
          listing = selected
          return unless listing

          Layout.rule(canvas, top)
          canvas.text(top + 1, 1, Layout.plain(listing.title)[0, 28], Canvas::WHITE)
          Layout.runs(canvas, top + 2, 1, [[Layout.plain(listing.host), Canvas::CYAN], [':', Canvas::DARK_GREY],
                                           [listing.port.to_s, Canvas::CYAN]])
          state_line(canvas, top + 3, listing)
          terminals(canvas, top + 4, listing)
          legend(canvas, top + 6)
        end

        def state_line(canvas, row, listing)
          mark, color = ListView.mark(listing.state)
          status = listing.status(@now.call)
          words = Layout.plain(status.empty? ? listing.state : status)
          latency = @details.call(listing.id) if listing.state == 'online'
          extra = [("#{latency}MS" if latency), listing.country&.upcase].compact
          Layout.runs(canvas, row, 1, [[mark, color], [" #{words}", STATE_COLORS.fetch(listing.state, Canvas::GREY)],
                                       *extra.flat_map { |e| [[' / ', Canvas::DARK_GREY], [e, Canvas::LIGHT_GREY]] }])
        end

        def terminals(canvas, row, listing)
          soft = Layout.plain(listing.software.to_s)
          terms = TERMINALS.keys.select { |t| listing.tags.include?(t) }.sort_by { |t| t == 'petscii' ? 0 : 1 }
          parts = soft.empty? ? [] : [[soft[0, 16], Canvas::LIGHT_GREY], [' / ', Canvas::DARK_GREY]]
          terms.each_with_index do |t, i|
            parts << ['+', Canvas::DARK_GREY] if i.positive?
            parts << [t.upcase, TERMINALS[t]]
          end
          Layout.runs(canvas, row, 1, parts)
        end

        def legend(canvas, row)
          Layout.runs(canvas, row, 1, [['●', Canvas::LIGHT_GREEN], [' UP ', Canvas::LIGHT_GREY], ['○', Canvas::YELLOW],
                                       [' FLAKY ', Canvas::LIGHT_GREY], ['╳', Canvas::RED], [' DOWN ', Canvas::LIGHT_GREY],
                                       ['┼', Canvas::GREY], [' DEAD', Canvas::LIGHT_GREY]])
        end
      end
    end
  end
end
