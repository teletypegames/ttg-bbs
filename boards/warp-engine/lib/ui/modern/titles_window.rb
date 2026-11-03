# frozen_string_literal: true

module UI
  module Modern
    # A shelf's titles, the one picked on the right, and the buttons of the
    # three protocols.
    module TitlesWindow
      extend BBS::Part

      PROTOCOLS = { 'ZMODEM' => :zmodem, 'XMODEM-1&K' => :xmodem_1k, 'X&MODEM' => :xmodem }.freeze

      window :titles, :master_detail do
        title      { shelf.name }
        list_width { [30, cols / 3].max }
        items      { titles }
        label      :title
        empty      'This shelf is empty right now.'
        detail     { |title| title_card(title) }
        meta       { |title| "CRC-32 #{format('%08x', title.crc32)}" }
        on_pick    { |title| download(title, :zmodem) }
        height(-8)
        PROTOCOLS.each { |label, protocol| action(label) { |title| download(title, protocol) } }
        action('Reload') { reload_shelf(window, shelf) }
      end
    end
  end
end
