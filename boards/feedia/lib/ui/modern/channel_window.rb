# frozen_string_literal: true

module UI
  module Modern
    # One feed: its items on the left, the text of the one picked on the
    # right, its address under it.
    module ChannelWindow
      extend BBS::Part

      window :channel, :master_detail do
        title      { channel.title }
        height     { rows - 8 }
        list_width { [30, cols / 3].max }
        items      { channel.items }
        label      :title
        empty      'This feed has nothing in it right now.'
        detail     { |item, width| story(item, width) }
        meta       { |item| item.link.to_s }
        action('QR code') { |item| show_qr(item) }
        action('Reload') { reload(window, channel) }
      end
    end
  end
end
