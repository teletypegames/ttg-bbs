# frozen_string_literal: true

module UI
  module Modern
    # What the caller does on the modern face: the feeds opened in windows,
    # a story's QR code, the messages to the admins.
    module Helpers
      NO_TEXT = '*(no text in the feed)*'
      ANSWERS = { ok: 'Sent to the admins. Thank you!',
                  limited: 'That is all the messages the admins can take for now. Thank you!' }.freeze

      def feed_list = show(:feeds)

      def open_feed(feed)
        channel = loading("Fetching #{feed.name}…",
                          failed: "#{feed.name} did not answer, or what it sent is not a feed. Try again later.",
                          title: 'Feed') do
          feeds.read(feed)
        end
        show(:channel, channel: channel)
      end

      def reload(window, channel)
        fresh = loading("Fetching #{channel.feed.name}…", failed: "#{channel.feed.name} did not answer. Try again later.",
                                                          title: 'Reload') do
          feeds.read(channel.feed, fresh: true)
        end
        window.replace_items(fresh.items, title: fresh.title)
      end

      # A story: its title, the byline, the text.
      def story(item, width)
        byline = [item.date&.localtime&.strftime('%Y-%m-%d %H:%M'), item.author].compact.reject(&:empty?).join(' · ')
        [*markdown("# #{item.title}", width), *(dim(byline) unless byline.empty?), '',
         *markdown(item.markdown.empty? ? NO_TEXT : item.markdown, width)]
      end

      def show_qr(item)
        return message('This story has no address.', title: 'QR code') unless item.link

        qr(item.link, title: 'Scan the address')
      end

      def suggest = can_send? && show(:suggest)

      def feedback = can_send? && show(:feedback)

      def can_send?
        return true if inbox.open?(caller_key)

        answer(:limited)
        false
      end

      # Tells the caller what the inbox answered; returns the answer.
      def answer(result) = report(result, ANSWERS, title: 'Admins')
    end
  end
end
