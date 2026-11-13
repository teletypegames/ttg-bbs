# frozen_string_literal: true

module UI
  module Modern
    # The windows of the modern face.
    module Windows
      # A list of machines, the short card of the picked one on the right; Enter opens its page.
      # With +counts+ ({ id => n }) each label carries its number and +unit+.
      module MachinesWindow
        extend Rubbs::Modern::Part

        window :machines, :master_detail do
          empty 'No machines here.'
          height(-6)
          title      { caption }
          list_width { [36, cols * 2 / 5].max }
          items      { entries }
          label      { |m| counts ? "#{m.label} · #{counts[m.id]} #{unit}" : m.label }
          detail     { |m, width| short_card(m, width) }
          meta       { |m| m.sparse? ? 'little data · Enter opens it' : 'Enter opens the machine' }
          on_pick    { |m| open_machine(m) }
          action('&Open') { |m| open_machine(m) }
        end
      end

      # The kinds, decades, makers of a letter or CPUs, each with its count; the right pane lists
      # the first machines of the one picked.
      module GroupsWindow
        extend Rubbs::Modern::Part

        window :groups, :master_detail do
          empty 'Nothing here.'
          height(-6)
          title      { caption }
          list_width { [32, cols / 3].max }
          items      { groups }
          label      { |(name, count)| "#{group_name(kind, name)} (#{count})" }
          detail     { |(name, count), width| group_card(kind, name, count, width) }
          meta       { 'Enter lists the machines' }
          on_pick    { |(name, _count)| open_group(kind, name) }
        end
      end

      # The makers by their first letter.
      module LettersWindow
        extend Rubbs::Modern::Part

        window :letters, :master_detail do
          title 'Makers'
          height(-6)
          list_width 20
          items      { catalog.letters }
          label      { |(letter, count)| "#{letter.upcase}  (#{count})" }
          detail     { |(letter, _count), width|
            [bright(letter.upcase), '', *wrap(catalog.makers(letter).map(&:first).join(' · '), width - 1)]
          }
          meta       { 'Enter lists the makers' }
          on_pick    { |(letter, _count)| open_letter(letter) }
        end
      end

      # A machine's page: its facts, the callers' marks and memories; the buttons read its
      # Wikipedia stories, show its family and its CPU's other machines, its memories, and mark it.
      module MachineWindow
        extend Rubbs::Modern::Part

        window :machine, :reader do
          title     { machine.label }
          max_width 90
          lines     { |width| machine_lines(machine, width) }
          where     { machine.wikipedia_url || machine.wikidata_url }
          action('&Wiki')      { read_about(machine, 'en') }
          action('&Magyar')    { read_about(machine, 'hu') }
          action('&Family')    { family(machine) }
          action('Same &CPU')  { same_cpu(machine) }
          action('M&emories')  { show_memories(machine) }
          action('M&ine…')     { mine(machine) }
        end
      end

      # The lead of a Wikipedia article, scrolling, with its licence and address.
      module AboutWindow
        extend Rubbs::Modern::Part

        window :about, :info do
          maximizable true
          scroll      true
          height(-6)
          title       { "#{machine.name} (#{summary.language})" }
          width       { about_width }
          body        { about_body(summary) }
        end
      end

      # Two machines side by side.
      module CompareWindow
        extend Rubbs::Modern::Part

        window :compare, :info do
          maximizable true
          scroll      true
          height(-6)
          title       { "#{first.name} · #{second.name}" }
          width       { about_width }
          body        { compare_body(first, second) }
        end
      end

      # The approved memories of a machine: who and when on the left, the memory on the right.
      module MemoriesWindow
        extend Rubbs::Modern::Part

        window :memories, :master_detail do
          empty 'No memories yet. Write the first one!'
          height(-6)
          title      { "Memories: #{machine.name}" }
          list_width 26
          items      { entries }
          label      { |m| "#{m.handle} · #{m.date}" }
          detail     { |m, width| ["#{accent(m.handle)}#{dim(" · #{m.date}")}", '', *wrap(m.text, width - 1)] }
          meta       { |m| "memory ##{m.id}" }
          action('&Write one') { add_memory(machine) }
        end
      end

      # The form for a new memory. MemoryService decides whether it goes in.
      module AddMemoryWindow
        extend Rubbs::Modern::Part

        window :add_memory, :form do
          title { "A memory of #{machine.name}" }
          width 72
          hint  "#{Wording::MEMORY_RULES} Alt-S sends."
          field :text, type: :textarea, rows: 6, max_length: MemoryService::MAX_TEXT
          submit_label '&Send'
          errors Wording::MEMORY.except(:ok)
          on_submit do |values|
            result = memories.submit(machine, identity: identity, text: values[:text], caller: caller_key)
            note(Wording::MEMORY[:ok], 'Thanks') if result == :ok
            result
          end
        end
      end

      # A machine among the caller's: a box for each mark.
      module MineWindow
        extend Rubbs::Modern::Part

        window :mine, :form do
          title { "Mine: #{machine.name}" }
          width 56
          hint  'Tick what is true. The marks show in My machines and count for the network.'
          field :owned, type: :checkbox, label: Wording::MARKS['owned'], value: -> { collection.marked?(identity, machine, 'owned') }
          field :grew_up,
                type:  :checkbox,
                label: Wording::MARKS['grew_up'],
                value: -> { collection.marked?(identity, machine, 'grew_up') }
          submit_label '&Save'
          on_submit { |values| save_marks(machine, values) }
        end
      end
    end
  end
end
