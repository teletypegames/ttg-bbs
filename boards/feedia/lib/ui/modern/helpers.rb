# frozen_string_literal: true

module UI
  module Modern
    # The methods of the modern face's Application: opening the windows,
    # the loading dialogs, the answers to a message.
    module Helpers
      def feed_list = open_window(:feeds)

      def open_feed(feed)
        channel = with_loading("Fetching #{feed.name}…") { services[:feeds].read(feed) }
        return open_window(:channel, channel: channel) if channel

        BBS::Dialogs.message(self, "#{feed.name} did not answer, or what it sent is not a feed. Try again later.",
                             title: ' Feed ')
      end

      def reload(window, channel)
        fresh = with_loading("Fetching #{channel.feed.name}…") { services[:feeds].read(channel.feed, fresh: true) }
        return window.replace_items(fresh.items, title: " #{fresh.title} ") if fresh

        BBS::Dialogs.message(self, "#{channel.feed.name} did not answer. Try again later.", title: ' Reload ')
      end

      # Who is calling, as the inbox counts messages.
      def caller_key = BBS::RateLimit.caller_key(session)

      def suggest = can_send? && open_window(:suggest)

      def feedback = can_send? && open_window(:feedback)

      def can_send?
        return true if services[:inbox].open?(caller_key)

        limited
        false
      end

      def limited
        BBS::Dialogs.message(self, 'That is all the messages the admins can take for now. Thank you!', title: ' Admins ')
      end

      def sent = BBS::Dialogs.message(self, 'Sent to the admins. Thank you!', title: ' Admins ')

      def status_text = "#{services[:feeds].list.size} feeds │ #{Time.now.strftime('%H:%M')}"

      def desktop_label(text, style, x, y, width, align: :left)
        label = BBS::Widgets::Label.new(text: text, align: align, style_key: style)
        label.layout(x, y, width, 1)
        add(label)
      end

      def markdown(text, width) = BBS::Markdown.to_lines(text, width: width - 1, theme: theme)
    end
  end
end
