# frozen_string_literal: true

module TTG
  module Network
    # The words when a page has no link to our other boards.
    NONE = 'Nothing of it on our other boards yet.'

    # The links on a Commodore 64 face (a Rubbs::Petscii::Face includes it):
    # a menu of them under the page, and the one taken dials its board.
    module Petscii
      # Shows +links+ ([label, folder, place] each, the reachable ones) as a
      # menu and hands the caller to the board of the one taken; tells them
      # when there is none. Returns +nil+ once they are back.
      def network(links)
        links = Network.reachable(links)
        return alert(NONE.downcase, color: Rubbs::Petscii::Colors::GR) if links.empty?

        items = links.each_with_index.map do |(label, _folder, _place), i|
          Rubbs::Common::Screens::Selector.item(label.downcase, key: (i + 1).to_s, value: i)
        end
        puts
        index = menu(items, back: nil) or return nil
        _label, folder, place = links[index]
        Network.visit(@session, folder, place)
        nil
      end
    end

    # The links on a modern face: an Application's helpers include it, and
    # its +parts+ take Window.
    module Modern
      # Shows +links+ in the network window, or a message when there is none.
      def network(links)
        links = Network.reachable(links)
        return message(NONE, title: 'On the network') if links.empty?

        show(:network, links: links)
      end
    end

    # The window of the links: Enter hands the caller to the board, and the
    # caller comes back here when they leave it.
    module Window
      extend Rubbs::Modern::Part

      window :network, :master_detail do
        title      'On the network'
        height     10
        list_width 46
        items      { links }
        label      { |(label, _folder, _place)| label }
        detail     { |(_label, folder, _place), _width|
          [BOARDS.fetch(folder, folder), '', 'You come back here when you leave it.']
        }
        meta       { 'Enter takes you there' }
        on_pick    { |(_label, folder, place)| with_line { Network.visit(@session, folder, place) } }
      end
    end
  end
end
