# frozen_string_literal: true

require_relative 'picker'

module UI
  module Petscii
    module Views
      # A list of boards of Global Discovery: the title row, the filter
      # chips, a header, a board a row (its number, state mark, name, country
      # and software), ten a page, the lit one a light blue bar, and under a
      # rule the lit board's name, address, state, software and terminals,
      # and the legend of the marks. RETURN or its digit opens its page (+on_open+); F steps
      # through the states when the list can be filtered.
      class ListView < Picker
        PER_PAGE = 10
        NAME = 20
        # The state marks: a block in the state's colour.
        MARKS = {
          'online' => ['▌', Canvas::LIGHT_GREEN], 'flaky' => ['▌', Canvas::YELLOW], 'down' => ['▌', Canvas::RED],
          'dead' => ['▌', Canvas::GREY], 'unknown' => ['▌', Canvas::DARK_GREY]
        }.freeze
        # The F filter steps through these; nil is every board the list has.
        FILTERS = [nil, 'online', 'flaky', 'down', 'unknown'].freeze
        STATE_COLORS = { 'online' => Canvas::LIGHT_GREEN, 'flaky' => Canvas::YELLOW, 'down' => Canvas::LIGHT_RED,
                         'dead' => Canvas::GREY, 'unknown' => Canvas::LIGHT_GREY }.freeze
        # The software of a sw: tag in at most ten letters.
        SOFT = 10
        SOFTWARE = { 'synchronet' => 'Synchronet', 'color64' => 'Color 64', 'cbase' => 'C*Base', 'cnet' => 'C-Net',
                     'image' => 'Image BBS', 'mystic' => 'Mystic', 'enigma' => 'Enigma', 'renegade' => 'Renegade',
                     'iniquity' => 'Iniquity', 'wwiv' => 'WWIV', 'maximus' => 'Maximus', 'searchlight' => 'Searchlite',
                     'magicka' => 'Magicka', 'spitfire' => 'Spitfire', 'x84' => 'x/84', 'wildcat' => 'Wildcat!',
                     'pcboard' => 'PCBoard', 'telegard' => 'Telegard', 'citadel' => 'Citadel',
                     'ftn-mailer' => 'FTN mailer' }.freeze
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
        # [section] the place of the sub-menu it lights
        def initialize(title:, color:, loader:, on_open:, filter: true, chips: [], details: nil, section: :discover,
                       empty: 'Nothing here.', now: -> { Time.now.to_i })
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
          return [['/', true], [' Find', false]] if @items.empty?

          parts = [['RETURN', true], [' Open  ', false]]
          parts += [['F', true], [' Filter  ', false]] if @filter
          parts += [['+/-', true], [' Page ', false]] if pages > 1
          parts + [['/', true], [' Find', false]]
        end

        def self.mark(state) = MARKS.fetch(state, MARKS['unknown'])

        def draw(canvas)
          Layout.band(canvas, @title, [@items.size, page_mark].reject { |s| s.to_s.empty? }.join('  '), @color)
          chips(canvas, Layout.row(1))
          canvas.text(Layout.row(2), 0, "Nr S #{'Name'.ljust(NAME + 1)}CC Software", Canvas::DARK_GREY)
          if @items.empty?
            canvas.text(Layout.row(4), 1, @state ? "No #{@state} board here." : @empty, Canvas::YELLOW)
            return
          end
          on_page.each_with_index { |listing, slot| row(canvas, Layout.row(3 + slot), listing, slot) }
          info(canvas, Layout.row(3 + PER_PAGE))
        end

        private

        def twins = @items.group_by(&:title).select { |_, l| l.size > 1 }.keys

        def chips(canvas, row)
          col = Layout.runs(canvas, row, 1, [['Filter', Canvas::GREY]]) + 1
          col = Layout.chip(canvas, row, col, 'PETSCII', Canvas::PURPLE) + 1
          @chips.each { |text, color| col = Layout.chip(canvas, row, col, text, color) + 1 }
          return unless @filter

          Layout.chip(canvas, row, col, @state ? @state.capitalize : 'Alive', @state ? STATE_COLORS[@state] : Canvas::GREEN)
        end

        def name(listing)
          name = Layout.plain(listing.title)
          return name[0, NAME] unless @twins.include?(listing.title)

          "#{name[0, NAME - listing.port.to_s.length - 1]}:#{listing.port}"
        end

        def software(listing)
          tag = listing.tags.find { |t| t.start_with?('sw:') }&.delete_prefix('sw:')
          return SOFTWARE.fetch(tag) { Layout.plain(tag)[0, SOFT] } if tag

          Layout.plain(listing.software.to_s.split.first)[0, SOFT]
        end

        def row(canvas, row, listing, slot)
          mark, color = ListView.mark(listing.state)
          number = format('%02d', ((@page * PER_PAGE) + slot + 1) % 100)
          cc = (listing.country || '--').upcase
          if slot == @index
            canvas.text(row, 0, "#{number} #{mark} #{name(listing).ljust(NAME + 1)}#{cc} #{software(listing)}"
                                .ljust(Layout::WIDTH), Canvas::LIGHT_BLUE, rvs: true)
          else
            Layout.runs(canvas, row, 0, [[number, Canvas::YELLOW], [' ', nil], [mark, color], [' ', nil],
                                         [name(listing), Canvas::WHITE]])
            Layout.runs(canvas, row, 6 + NAME, [[cc, Canvas::CYAN], [' ', nil], [software(listing), Canvas::LIGHT_BLUE]])
          end
        end

        def info(canvas, top)
          listing = selected
          return unless listing

          Layout.rule(canvas, top)
          canvas.text(top + 1, 1, Layout.plain(listing.title)[0, Layout::EDGE - 1], Canvas::WHITE)
          down = Layout.address(canvas, top + 2, 1, listing.host, listing.port) - 1
          state_line(canvas, top + 3 + down, listing)
          terminals(canvas, top + 4 + down, listing)
          legend(canvas, top + 6 + down) if top + 6 + down <= Layout::BOTTOM
        end

        def state_line(canvas, row, listing)
          mark, color = ListView.mark(listing.state)
          status = listing.status(@now.call)
          words = Layout.plain(status.empty? ? listing.state : status).capitalize
          latency = @details.call(listing.id) if listing.state == 'online'
          extra = [("#{latency}ms" if latency), listing.country&.upcase].compact
          Layout.runs(canvas, row, 1, [[mark, color], [" #{words}", STATE_COLORS.fetch(listing.state, Canvas::GREY)],
                                       *extra.flat_map { |e| [[' / ', Canvas::DARK_GREY], [e, Canvas::LIGHT_GREY]] }])
        end

        def terminals(canvas, row, listing)
          soft = Layout.plain(listing.software.to_s)
          terms = TERMINALS.keys.select { |t| listing.tags.include?(t) }.sort_by { |t| t == 'petscii' ? 0 : 1 }
          parts = soft.empty? ? [] : [[soft[0, 22], Canvas::LIGHT_GREY], [' / ', Canvas::DARK_GREY]]
          terms.each_with_index do |t, i|
            parts << ['+', Canvas::DARK_GREY] if i.positive?
            parts << [t.upcase, TERMINALS[t]]
          end
          Layout.runs(canvas, row, 1, parts)
        end

        def legend(canvas, row)
          Layout.runs(canvas, row, 1, [['▌', Canvas::LIGHT_GREEN], [' Up ', Canvas::LIGHT_GREY], ['▌', Canvas::YELLOW],
                                       [' Flaky ', Canvas::LIGHT_GREY], ['▌', Canvas::RED], [' Down ', Canvas::LIGHT_GREY],
                                       ['▌', Canvas::GREY], [' Dead', Canvas::LIGHT_GREY]])
        end
      end
    end
  end
end
