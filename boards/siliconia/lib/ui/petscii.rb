# frozen_string_literal: true

require_relative 'logo'
require_relative 'wording'
require_relative 'picture'
require_relative 'petscii/photo'

module UI
  # The board on a Commodore 64: PETSCII on a 40×25 screen. A cursor main menu, the shelves and the
  # machines as numbered cursor lists, a machine on a page of its own with its actions on one row
  # and the rest in a menu under "more", the Wikipedia leads and the memories as pages that wait
  # for RETURN, and a line for a search, a comparison and a memory.
  class Petscii < Rubbs::Petscii::Face
    include Photo

    LOGO_COLORS = [GN, GN, CY, CY, WH].freeze
    BOARD       = "#{DG} ::::::::::::::::::::::::::::::::::::::#{LG}".freeze

    title('SILICONIA BBS') { "#{catalog.count} machines" }

    masthead do
      gap
      art BOARD
      gap
      art Logo.petscii(LOGO_COLORS)
      gap
      art BOARD
      gap
      line " #{Wording::TAGLINE}", color: WH
    end

    main_menu do
      item('s', 'search', 'a machine, a maker or a cpu') { search }
      item('l', 'legends', 'the machines everyone knows') { machines('LEGENDS', catalog.legends) }
      item('b', 'browse', 'kinds, decades, makers, cpus') { browse }
      item('h', 'hungarian machines', 'tvc, primo, ht-1080z…') { machines('HUNGARIAN MACHINES', catalog.hungarian) }
      item('r', 'random machine', 'whatever is on the next stand') { machine(catalog.random) }
      item('e', 'machine of the week', -> { catalog.machine_of_the_week&.name.to_s[0, 30] }) do
        machine(catalog.machine_of_the_week)
      end
      item('t', 'top lists', 'most viewed, the network\'s') { tops }
      item('m', 'my machines', 'the ones you had') { my_machines }
      item('w', 'the wall', 'talk machines with the others') { TTG::Wall.open(@session) }
      item('f', 'write to the sysops', 'a wrong fact, an idea') { TTG::Feedback.open(@session) }
      item('i', 'about siliconia bbs', 'where the machines come from') do
        page('ABOUT SILICONIA BBS', [Wording::ABOUT, '', Wording::SOURCES])
      end
      log_off
    end

    private

    def search
      title('SEARCH')
      say('A machine, a maker or a cpu (6502, z80). Return alone goes back.', color: GR)
      puts
      query = ask(" #{WH}search?#{LG} ", max: 30)
      return if query.empty?

      found = catalog.search(query)
      return machines("SEARCH: #{query.upcase}"[0, 30], found) if found.is_a?(Array) && found.any?

      alert(Wording.search(found, query))
    end

    def browse
      options = [['by kind', -> { groups('KINDS', catalog.kinds, :kind) }],
                 ['by decade', -> { groups('DECADES', catalog.decades, :decade) }],
                 ['by maker', -> { makers }],
                 ['by cpu', -> { groups('CPUS', catalog.cpus, :cpu) }]]
      each_pick('BROWSE', options, label: :first) { |option| option.last.call }
    end

    def tops
      options = [['most viewed', -> { ranked('MOST VIEWED', catalog.most_viewed, 'views') }],
                 ['the network grew up on', -> { ranked('THE NETWORK GREW UP ON', collection.grew_up_on, 'callers') }],
                 ['machines with memories', -> { machines('WITH MEMORIES', memories.machines_with_memories) }]]
      each_pick('TOP LISTS', options, label: :first) { |option| option.last.call }
    end

    def my_machines
      return alert(Wording::ACCOUNT) unless signed_in?

      machines('MY MACHINES', collection.of(identity).map(&:first), empty: 'none yet. open a machine, more, mark it.')
    end

    # A list of [name, count] groups, then the machines of the one picked.
    def groups(heading, list, kind)
      label = ->((name, count)) { "#{group_name(kind, name)} #{GR}#{count}#{LG}" }
      each_pick(heading, list, right: list.size.to_s, label: label) do |(name, _count)|
        machines(group_name(kind, name).upcase[0, 30], machines_of(kind, name))
      end
    end

    def group_name(kind, name)
      case kind
      when :kind then MachineModel::KINDS.fetch(name, name)
      when :decade then Wording.decade(name)
      else name.to_s
      end
    end

    def machines_of(kind, name)
      case kind
      when :kind then catalog.of_kind(name)
      when :decade then catalog.in_decade(name)
      else catalog.of_cpu(name)
      end
    end

    def makers
      letters = catalog.letters
      loop do
        title('MAKERS')
        say('The first letter of the name:')
        puts
        k = menu(
          letters.map { |l, count| Rubbs::Common::Screens::Selector.item(count.to_s, key: l, value: l) },
          columns: 6,
          hint:    'crsr or letter, return  stop: back'
        )
        return unless k

        each_pick("MAKERS: #{k.upcase}", catalog.makers(k), label: lambda { |(name, count)|
          "#{name} #{GR}#{count}#{LG}"
        }) do |(name, _)|
          machines(name.upcase[0, 30], catalog.of_maker(name))
        end
      end
    end

    def ranked(heading, pairs, unit)
      label = ->((m, n)) { "#{m.label} #{GR}#{n} #{unit}#{LG}" }
      each_pick(heading, pairs, empty: 'nothing here yet.', label: label) { |(m, _)| machine(m) }
    end

    def machines(heading, list, empty: 'no machines here.')
      loop do
        picked = pick(heading, list, empty: empty, right: "#{list.size} machines") { |m|
          m.sparse? ? "#{m.label} #{GR}?#{LG}" : m.label
        }
        return unless picked

        machine(picked)
        return if list.size == 1
      end
    end

    def machine(machine)
      return unless machine

      catalog.viewed(machine)
      loop do
        page('MACHINE', machine_lines(machine), right: machine.id, wait: false, room: 2)
        case actions(%w[w wiki], %w[p photo], %w[m more], %w[q back])
        when 'w' then read_about(machine, 'en')
        when 'p' then photo(machine)
        when 'm' then more(machine)
        else return
        end
      end
    end

    def machine_lines(machine)
      rows = Wording.facts(machine, catalog) + [['Callers', Wording.marks(collection.counts(machine))],
                                                ['Memories', Wording.memories(memories.count(machine))]]
      [*wrap(machine.name).map { |l| " #{WH}#{l}#{LG}" }, *rows.flat_map { |k, v| row(k, v) },
       " #{GR}#{Wording.edit_hint(machine).downcase}#{LG}"]
    end

    def row(key, value)
      first, *rest = wrap(value.to_s, WIDTH - 3)
      [" #{CY}#{key.downcase}#{LG}", "   #{first}", *rest.map { |l| "   #{l}" }]
    end

    def more(machine)
      case menu(more_items(machine), back: nil)
      when 'h' then read_about(machine, 'hu')
      when 'f' then family(machine)
      when 'c' then same_cpu(machine)
      when 'e' then show_memories(machine)
      when 'a' then add_memory(machine)
      when 'o' then mark(machine, 'owned')
      when 'g' then mark(machine, 'grew_up')
      when 'v' then compare(machine)
      end
    end

    def more_items(machine)
      on = ->(kind) { collection.marked?(identity, machine, kind) ? 'unmark' : 'mark' }
      [['h', 'wikipedia in hungarian'], ['f', 'its family line'], ['c', 'machines with its cpu'], ['e', 'memories of it'],
       ['a', 'write a memory'],
       ['o', "#{on.call('owned')}: i had one"], ['g', "#{on.call('grew_up')}: i grew up on it"],
       ['v', 'compare with another']].map { |key, label|
        Rubbs::Common::Screens::Selector.item(label, key: key, value: key)
      }
    end

    def read_about(machine, language)
      say('asking wikipedia…', color: GR)
      found = about.summary(machine, language)
      if found.is_a?(Symbol)
        say(Wording.about(found, language), color: RD)
        return pause
      end

      page("ABOUT (#{language})", [" #{WH}#{found.title}#{LG}", '', *found.paragraphs.flat_map { |p| [" #{p}", ''] },
                                   " #{GR}#{SummaryModel::LICENSE.downcase}:#{LG}", " #{GR}#{found.url}#{LG}"])
    end

    def family(machine)
      line = catalog.family(machine)
      return alert('Wikidata knows no machine before or after it.') if line.size == 1

      machines("FAMILY: #{machine.name.upcase}"[0, 30], line)
    end

    def same_cpu(machine)
      found = catalog.same_cpu(machine)
      return alert('Wikidata knows no other machine with its cpu.') if found.empty?

      machines("SAME CPU: #{machine.cpus.first.to_s.upcase}"[0, 30], found)
    end

    def show_memories(machine)
      lines = memories.memories(machine).flat_map { |m| [" #{CY}#{m.handle}#{GR} #{m.date}#{LG}", " #{m.text}", ''] }
      lines = [" #{GR}no memories yet. more, then a, writes one.#{LG}"] if lines.empty?
      page("MEMORIES: #{machine.name.upcase}"[0, 30], lines)
    end

    def add_memory(machine)
      return alert(Wording::MEMORY[:account]) unless signed_in?

      title("A MEMORY: #{machine.name.upcase}"[0, 30])
      say(Wording::MEMORY_RULES, color: GR)
      say('An empty memory goes back.', color: GR)
      puts
      text = edit('', title: "YOUR MEMORY OF #{machine.name.upcase}"[0, 30], single_line: true, max: MemoryService::MAX_TEXT)
      return alert('Nothing sent.', color: GR) if text.to_s.strip.empty?

      report(memories.submit(machine, identity: identity, text: text, caller: caller_key), Wording::MEMORY)
    end

    def mark(machine, kind)
      return alert(Wording::ACCOUNT) unless signed_in?

      say(Wording.mark(collection.toggle(identity, machine, kind), kind), color: GR)
      pause
    end

    def compare(machine)
      title('COMPARE')
      say("#{machine.name} with which machine? Return alone goes back.", color: GR)
      puts
      query = ask(" #{WH}machine?#{LG} ", max: 30)
      return if query.empty?

      found = catalog.search(query)
      return alert(Wording.search(found, query)) unless found.is_a?(Array) && found.any?

      other = found.first
      page('COMPARE', [" #{WH}#{machine.name}#{LG}", " #{YE}#{other.name}#{LG}", '', *compare_lines(machine, other)])
    end

    # The facts of two machines, the second's in yellow under the first's.
    def compare_lines(machine, other)
      Wording.compare(machine, other, catalog).flat_map do |label, a, b|
        [" #{CY}#{label.downcase}#{LG}", *wrap(a, WIDTH - 3).map { |l| "   #{l}" }, *wrap(b, WIDTH - 3).map { |l|
          "   #{YE}#{l}#{LG}"
        }]
      end
    end
  end
end
