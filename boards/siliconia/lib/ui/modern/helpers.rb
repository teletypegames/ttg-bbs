# frozen_string_literal: true

module UI
  module Modern
    # What the caller does on the modern face: the searches, the shelves, a machine's page, its
    # stories, family, memories and marks.
    module Helpers
      SHOWN = 40

      def search
        ask('A machine, a maker or a CPU:', title: 'Search', width: 60) { |text| find(text) }
      end

      def find(query)
        found = catalog.search(query)
        return note(Wording.search(found, query), 'Search') unless found.is_a?(Array) && found.any?

        list("Search: #{query.strip}", found)
      end

      def list(caption, machines, counts: nil, unit: nil)
        show(:machines, caption: caption, entries: machines, counts: counts, unit: unit)
      end

      # [machine, n] pairs as a list whose labels carry n and +unit+.
      def ranked(caption, pairs, unit, empty)
        return note(empty, caption) if pairs.empty?

        list(caption, pairs.map(&:first), counts: pairs.to_h { |m, n| [m.id, n] }, unit: unit)
      end

      def open_machine(machine)
        catalog.viewed(machine)
        show(:machine, machine: machine)
      end

      def random = open_machine(catalog.random)

      def groups_of(kind)
        case kind
        when :kind then ['Kinds', catalog.kinds]
        when :decade then ['Decades', catalog.decades]
        else ['CPUs', catalog.cpus]
        end
      end

      def open_groups(kind)
        caption, groups = groups_of(kind)
        show(:groups, caption: caption, kind: kind, groups: groups)
      end

      def machines_of(kind, name)
        case kind
        when :kind then catalog.of_kind(name)
        when :decade then catalog.in_decade(name)
        when :cpu then catalog.of_cpu(name)
        else catalog.of_maker(name)
        end
      end

      def group_name(kind, name)
        case kind
        when :kind then MachineModel::KINDS.fetch(name, name).capitalize
        when :decade then Wording.decade(name)
        else name.to_s
        end
      end

      def open_group(kind, name) = list(group_name(kind, name), machines_of(kind, name))

      def open_letter(letter)
        show(:groups, caption: "Makers: #{letter.upcase}", kind: :maker, groups: catalog.makers(letter))
      end

      def my_machines
        return note(Wording::ACCOUNT, 'My machines') unless signed_in?

        pairs = collection.of(identity)
        return note('No machine is marked yet. Open one and press Mine.', 'My machines') if pairs.empty?

        list('My machines', pairs.map(&:first))
      end

      def with_memories
        found = memories.machines_with_memories
        return note('No machine has an approved memory yet. Be the first!', 'Memories') if found.empty?

        list('Machines with memories', found)
      end

      def read_about(machine, language)
        found = loading('Asking Wikipedia…') { about.summary(machine, language) }
        return note(Wording.about(found, language), 'Wiki') if found.is_a?(Symbol)

        show(:about, machine: machine, summary: found)
      end

      def photo(machine)
        found = loading('Asking Wikimedia Commons…') { pictures.picture(machine) }
        return note(Wording.picture(found), 'Photo') if found.is_a?(Symbol)

        show(:photo, machine: machine, picture: found)
      end

      def machine_of_the_week
        machine = catalog.machine_of_the_week
        return note('No machine this week.', 'Machine of the week') unless machine

        open_machine(machine)
      end

      # The photo in half blocks, centred, its credit under it.
      def photo_body(picture)
        inner = about_width - 5
        pad   = ' ' * [(inner - picture.modern.width) / 2, 0].max
        [*Picture.modern_lines(picture.modern).map { |l| pad + l }, '',
         *wrap("Photo: #{picture.credit}", inner).map { |l| dim(l) },
         *[picture.license_url, picture.page].reject { |u| u.to_s.empty? }.map { |u| dim(u) }]
      end

      def family(machine)
        line = catalog.family(machine)
        return note('Wikidata knows no machine before or after it.', 'Family') if line.size == 1

        list("Family: #{machine.name}", line)
      end

      def same_cpu(machine)
        found = catalog.same_cpu(machine)
        return note('Wikidata knows no other machine with its CPU.', 'Same CPU') if found.empty?

        list("Same CPU: #{machine.cpus.join(', ')}", found)
      end

      def show_memories(machine) = show(:memories, machine: machine, entries: memories.memories(machine))

      def add_memory(machine)
        return note(Wording::MEMORY[:account], 'A memory') unless signed_in?

        show(:add_memory, machine: machine)
      end

      def mine(machine)
        return note(Wording::ACCOUNT, 'Mine') unless signed_in?

        show(:mine, machine: machine)
      end

      # Sets the marks ticked in +values+ and takes back the others.
      def save_marks(machine, values)
        MarkModel::KINDS.each do |kind|
          on = values[kind.to_sym] ? true : false
          collection.toggle(identity, machine, kind) if on != collection.marked?(identity, machine, kind)
        end
        :ok
      end

      # Two machines side by side, each asked for by name (the best match of a search).
      def compare
        ask('The first machine:', title: 'Compare', width: 60) do |first|
          a = compared(first)
          next unless a

          ask("Compare #{a.name} with:", title: 'Compare', width: 60) do |second|
            b = compared(second)
            show(:compare, first: a, second: b) if b
          end
        end
      end

      def compared(query)
        found = catalog.search(query)
        return found.first if found.is_a?(Array) && found.any?

        note(Wording.search(found, query), 'Compare')
        nil
      end

      # Something for the sysops (ttg-common TTG::Feedback), about the machine open, if any.
      def feedback = with_line { TTG::Feedback.open(@session, context: window(:machine) && "Machine: #{window(:machine).title}") }

      # The board's wall (ttg-common TTG::Wall).
      def wall = with_line { TTG::Wall.open(@session) }

      def note(text, title) = message(text, title: title, width: 64)

      def wrap(text, width) = Rubbs::Modern::FrameBuffer.wrap_ansi(text.to_s, [width, 10].max)

      def about_width = [cols - 4, 84].min

      # The lines of a machine's page.
      def machine_lines(machine, width)
        rows = Wording.facts(machine, catalog) + [['Callers', Wording.marks(collection.counts(machine))],
                                                  ['Memories', Wording.memories(memories.count(machine))]]
        mine = Wording::MARKS.filter_map { |kind, name| name if collection.marked?(identity, machine, kind) }
        rows << ['Yours', mine.join(', ')] if mine.any?
        [bright(machine.name), *(machine.sparse? ? [dim('Wikidata says little of this one.')] : []), '',
         *card(rows, width), '', dim(Wording.edit_hint(machine))]
      end

      # The facts of a machine in the right pane of a list.
      def short_card(machine, width)
        rows = Wording.facts(machine, catalog).first(6)
        [bright(machine.name), '', *card(rows, width), '', dim('Enter opens it')]
      end

      # A group and the first SHOWN of its machines.
      def group_card(kind, name, count, width)
        machines = machines_of(kind, name)
        [bright(group_name(kind, name)), accent("#{count} machine#{'s' unless count == 1}"), '',
         *machines.first(SHOWN).map { |m| Rubbs::Modern::FrameBuffer.clip_ansi(m.label, width - 1) },
         *(machines.size > SHOWN ? [dim("… and #{machines.size - SHOWN} more")] : [])]
      end

      # The lead of a Wikipedia article with its licence and address.
      def about_body(summary)
        inner = about_width - 5
        [bright(summary.title), '', *summary.paragraphs.flat_map { |p| [*wrap(p, inner), ''] },
         dim(SummaryModel::LICENSE), *wrap(dim(summary.url), inner)]
      end

      # Two machines' facts in two columns under their names.
      def compare_body(first, second)
        rows = Wording.compare(first, second, catalog)
        pad  = rows.map { |k, _, _| k.size }.max.to_i + 2
        col  = [(about_width - 5 - pad - 2) / 2, 10].max
        [compare_head(first, second, pad, col), '',
         *rows.flat_map { |label, a, b| compare_row(label, wrap(a, col), wrap(b, col), pad, col) }]
      end

      def compare_head(first, second, pad, col)
        "#{' ' * pad}#{bright(first.name[0, col].ljust(col))}  #{bright(second.name[0, col])}"
      end

      # One fact of two machines, its lines side by side.
      def compare_row(label, left, right, pad, col)
        Array.new([left.size, right.size].max) do |i|
          "#{dim((i.zero? ? label : '').ljust(pad))}#{left[i].to_s.ljust(col)}  #{right[i]}"
        end
      end

      # [label, value] rows as lines, the labels dim in a column of their own.
      def card(rows, width)
        pad = rows.map { |k, _| k.size }.max.to_i + 2
        rows.flat_map do |key, value|
          lines = wrap(value.to_s, width - pad - 1)
          lines.each_with_index.map { |l, i| "#{dim((i.zero? ? key : '').ljust(pad))}#{l}" }
        end
      end
    end
  end
end
