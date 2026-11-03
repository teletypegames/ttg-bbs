# frozen_string_literal: true

module UI
  module Modern
    # The feed list: the feeds on the left, the one picked on the right.
    module FeedsWindow
      extend BBS::Part

      window :feeds, :master_detail do
        title 'Feeds'
        height     { rows - 8 }
        list_width { [30, cols / 3].max }
        items      { feeds.list }
        label      :name
        empty 'No feeds are configured.'
        detail do |feed|
          [bright(feed.name), accent([feed.group, feed.lang].reject(&:empty?).join(' · ')), '', feed.about, '',
           dim(feed.url)]
        end
        meta       { 'Enter opens the feed' }
        on_pick    { |feed| open_feed(feed) }
        action('Open') { |feed| open_feed(feed) }
      end
    end
  end
end
