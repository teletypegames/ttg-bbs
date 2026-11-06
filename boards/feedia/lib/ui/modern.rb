# frozen_string_literal: true

require_relative 'logo'
require_relative 'modern/helpers'
require_relative 'modern/feeds_window'
require_relative 'modern/channel_window'

module UI
  # The reader on a modern terminal (ANSI colours, UTF-8, a mouse): a
  # newspaper's masthead on the desktop, the feeds in a two-pane window, a
  # feed's items with the one picked on the right, and the network's
  # feedback and wall (ttg-common TTG::Feedback, TTG::Wall).
  module Modern
    ABOUT = 'Feedia BBS — an RSS reader on a telnet line, from Teletype Games, powered by rubbs. ' \
            'Pick a feed, then an item: its text opens on the right, its links numbered under it. ' \
            'A feed missing from the list? Suggest it in the Editors menu. Talk about the news on the Wall.'
    TAGLINE = '─── All the news that fits in 80 columns ───'

    APP = Rubbs::Modern::Application.define do
      theme :synchronet
      helpers { include Helpers }

      command(:feeds,    'Feed list',       key: 'F2', hint: 'Feeds') { feed_list }
      command(:suggest,  'Suggest a feed…', key: 'F7', hint: 'Suggest') { suggest }
      command(:feedback, 'Write to the &editors…', key: 'F8', hint: 'Editors') { feedback }
      command(:wall,     'The &wall…', hint: 'Wall') { wall }
      menu 'Feeds', :feeds, :wall, :separator, :log_off
      menu 'Editors', :suggest, :feedback
      help about: ABOUT

      status { "#{feeds.list.size} feeds" }

      # A newspaper's masthead: the name between its two ears, three rows
      # free above the feed windows and three below.
      desktop do
        art  Logo::HALF_BLOCKS, top: 1
        line 'VOL. I · NO. 2327', top: 1, align: :left, margin: 2
        line 'THE TELNET EDITION', top: 2, align: :left, margin: 2
        line(top: 1, align: :right, margin: 1) { Time.now.strftime('%A %-d %b %Y').upcase }
        line(top: 2, align: :right, margin: 1) { "#{feeds.list.size} FEEDS · NO CHARGE" }
        line TAGLINE, bottom: 1
        on_show { feed_list }
      end

      parts FeedsWindow, ChannelWindow
    end
  end
end
