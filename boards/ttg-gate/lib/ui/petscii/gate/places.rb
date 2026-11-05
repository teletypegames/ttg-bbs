# frozen_string_literal: true

module UI
  module Petscii
    class Gate < Rubbs::Petscii::Kit::Frame
      # The places of the gate: our own boards, Help, and the lists, menus
      # and pages of Global Discovery, each a view for the Gate's stack.
      module Places
        private

        def section_view(key)
          case key
          when :own then own
          when :help then Views::TextView.help
          else
            return resting unless @browse

            catalog_view(key)
          end
        end

        def catalog_view(key)
          case key
          when :discover, :browse then browse_menu
          when :software, :country, :network then facets(key)
          when *FIXED.keys then fixed(key)
          when :random then random
          when :sources then Views::SourcesView.new(@browse.sources, @stats || {})
          end
        end

        def own = @own ||= Views::OwnView.new(@boards, on_dial: method(:dial_own))

        # Every board in every state, F starting from all; with +tag+
        # ('petscii', 'ascii') the boards of that terminal, else every
        # encoding, the ones a C64 cannot call dimmed.
        def all(tag = nil)
          Views::ListView.new(
            title:        "ALL #{tag&.upcase || 'BOARDS'}",
            color:        BANDS[:all],
            section:      :all,
            all_states:   true,
            any_terminal: tag.nil?,
            terminal:     tag.to_s.upcase,
            loader:       ->(state) { @browse.all(tags: [tag].compact, state: state) },
            on_open:      method(:open_page),
            details:      method(:latency)
          )
        end

        # A list of +section+, in the colour of +band+ (the section's own).
        def list(title, section, band: section, &loader)
          Views::ListView.new(
            title:   title,
            color:   BANDS.fetch(band, Canvas::ORANGE),
            section: section,
            loader:  loader,
            on_open: method(:open_page),
            details: method(:latency)
          )
        end

        # A list of its own: New this week, Recently died, the Graveyard.
        def fixed(key)
          title, chip, color, empty, reader = FIXED.fetch(key)
          Views::ListView.new(
            title:   title,
            color:   BANDS.fetch(key),
            section: key,
            filter:  false,
            chips:   [[chip, color]],
            loader:  ->(_) { @browse.public_send(reader, petscii: true) },
            empty:   empty,
            on_open: method(:open_page),
            details: method(:latency)
          )
        end

        def latency(id)
          @latency ||= {}
          @latency.fetch(id) { @latency[id] = @browse.page(id)&.latency_ms }
        end

        def browse_menu
          Views::MenuView.new(all_entries + axis_entries, title: 'BROWSE', color: BANDS[:browse], section: :browse)
        end

        # All, All PETSCII and All ASCII of Browse.
        def all_entries
          [Views::MenuView::Entry.new(
            name:   'All',
            count:  @browse.all.size,
            action: -> { push(all) },
            about:  ['ALL BOARDS', 'Every state, every terminal', 'Dimmed: no C64 call']
          ),
           Views::MenuView::Entry.new(
             name:   'All PETSCII',
             count:  @browse.all(petscii: true).size,
             action: -> { push(all('petscii')) },
             about:  ['ALL PETSCII', 'Every PETSCII board, every state']
           ),
           Views::MenuView::Entry.new(
             name:   'All ASCII',
             count:  @browse.all(tags: ['ascii']).size,
             action: -> { push(all('ascii')) },
             about:  ['ALL ASCII', 'Every ASCII board, every state', 'Translated for the C64']
           )]
        end

        # One entry an axis of Browse, its biggest facets as the about.
        def axis_entries
          @browse.axes(petscii: true).map do |axis, spec|
            facets = @browse.facets(axis, petscii: true)
            about = ["BY #{spec[:label].upcase}", *facets.first(3).map { |f| "#{f.label} #{f.count}" }]
            Views::MenuView::Entry.new(
              name:   "BY #{spec[:label]}",
              count:  facets.size,
              about:  about,
              action: -> { push(facets(axis)) }
            )
          end
        end

        def facets(axis)
          axis = axis.to_sym
          label = @browse.axes(petscii: true).dig(axis, :label).to_s
          entries = @browse.facets(axis, petscii: true).map do |f|
            Views::MenuView::Entry.new(
              name:   f.label,
              count:  f.count,
              about:  [f.label, "Tag #{f.tag}", "#{f.count} boards"],
              action: -> { push(tagged(f, axis)) }
            )
          end
          Views::MenuView.new(entries, title: "BY #{label.upcase}", color: BANDS[:browse], section: axis)
        end

        def tagged(facet, axis)
          list(facet.label, axis, band: :browse) { |state| @browse.tagged(facet.tag, petscii: true, state: state) }
        end

        def random
          board = @browse.random(petscii: true)
          return notice('RANDOM BOARD', ['No PETSCII board answered', 'our last call.'], section: :random) unless board

          page_view(board.id, :random)
        end

        def page_view(id, section)
          page = @browse.page(id)
          return notice('GONE', ['This board is gone from the list.'], section: section) unless page

          Views::PageView.new(page, section: section, on_dial: method(:dial_catalog), on_banner: method(:banner))
        end

        def open_page(listing)
          target = page_view(listing.id, view.section || @section)
          push(target)
        end

        def resting = notice('GLOBAL DISCOVERY', ['The catalog is resting.', 'Try again later.'])

        def notice(title, lines, section: nil)
          Views::TextView.new(title, lines.map { |l| [l, Canvas::YELLOW] }, color: Canvas::LIGHT_RED, section: section)
        end
      end
    end
  end
end
