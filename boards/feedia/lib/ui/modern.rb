# frozen_string_literal: true

require_relative 'logo'
require_relative 'modern/helpers'
require_relative 'modern/feeds_window'
require_relative 'modern/channel_window'
require_relative 'modern/suggest_window'
require_relative 'modern/feedback_window'

module UI
  # The reader on a modern terminal (ANSI colours, UTF-8, a mouse): a
  # newspaper's masthead on the desktop, the feeds in a two-pane window, a
  # feed's items with the one picked on the right, and two forms that write
  # to the admins.
  module Modern
    ABOUT = 'Feedia BBS — an RSS reader on a telnet line, from Teletype Games, powered by rubbs. ' \
            'Pick a feed, then an item: its text opens on the right, its links numbered under it. ' \
            'A feed missing from the list? Suggest it in the Admins menu.'
    TAGLINE = '─── All the news that fits in 80 columns ───'

    APP = BBS::Application.define do
      theme :synchronet
      helpers { include Helpers }

      command(:feeds,    'Feed list',       key: 'F2', hint: 'Feeds') { feed_list }
      command(:suggest,  'Suggest a feed…', key: 'F7', hint: 'Suggest') { suggest }
      command(:feedback, 'Send &feedback…', key: 'F8', hint: 'Feedback') { feedback }
      menu 'Feeds', :feeds, :separator, :log_off
      menu 'Admins', :suggest, :feedback
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

      parts FeedsWindow, ChannelWindow, SuggestWindow, FeedbackWindow
    end
  end
end
