# frozen_string_literal: true

require_relative 'logo'
require_relative 'wording'
require_relative 'picture'
require_relative 'modern/helpers'
require_relative 'modern/windows'

module UI
  # The board on a modern terminal (ANSI colours, UTF-8, a mouse): the search in a dialog, the
  # shelves as lists with the picked machine's card on the right, a machine's page in a reader with
  # its buttons, the Wikipedia leads, the family line, the memories and their form, the marks, two
  # machines side by side, and the network's wall and feedback (ttg-common).
  module Modern
    HELP = 'F2 search · F3 random · F4 legends · F5 machine of the week · F10 menu'

    APP = Rubbs::Modern::Application.define do
      theme :synchronet
      helpers { include Helpers }

      command(:search,    'Search…', key: 'F2') { search }
      command(:random,    'Random machine', key: 'F3', hint: 'Random') { random }
      command(:legends,   '&Legends', key: 'F4', hint: 'Legends') { list('Legends', catalog.legends) }
      command(:week, 'Machine of the &week', key: 'F5', hint: 'Week') { machine_of_the_week }
      command(:hungarian, '&Hungarian machines') { list('Hungarian machines', catalog.hungarian) }
      command(:kinds,     'By &kind')    { open_groups(:kind) }
      command(:decades,   'By &decade')  { open_groups(:decade) }
      command(:makers,    'By &maker')   { show(:letters) }
      command(:cpus,      'By &CPU')     { open_groups(:cpu) }
      command(:viewed,    'Most &viewed') do
        ranked('Most viewed', catalog.most_viewed, 'views', 'No machine was opened yet.')
      end
      command(:network, 'The network\'s &machines') do
        ranked('The network grew up on', collection.grew_up_on, 'callers', 'Nobody marked a machine yet. Be the first!')
      end
      command(:with_memories, 'With m&emories') { with_memories }
      command(:compare, 'C&ompare two…') { compare }
      command(:mine,      'My &machines') { my_machines }
      command(:wall,      'The &wall…', hint: 'Wall') { wall }
      command(:feedback,  'Write to the sys&ops…') { feedback }
      menu 'Museum',
           :search,
           :random,
           :week,
           :separator,
           :legends,
           :hungarian,
           :kinds,
           :decades,
           :makers,
           :cpus,
           :compare,
           :separator,
           :viewed,
           :network,
           :with_memories,
           :separator,
           :log_off
      menu 'Mine', :mine, :separator, :wall, :feedback
      help about: Wording::ABOUT, sources: Wording::SOURCES, keys: ['Enter        open the machine']
      status { "#{catalog.count} machines" }

      desktop do
        art  Logo.half_blocks, middle: -7
        line Wording::TAGLINE, style: :text, middle: -3
        line HELP, middle: -1
        on_show { list('Legends', catalog.legends) }
      end

      parts Windows::MachinesWindow,
            Windows::GroupsWindow,
            Windows::LettersWindow,
            Windows::MachineWindow,
            Windows::AboutWindow,
            Windows::PhotoWindow,
            Windows::CompareWindow,
            Windows::MemoriesWindow,
            Windows::AddMemoryWindow,
            Windows::MineWindow
    end
  end
end
