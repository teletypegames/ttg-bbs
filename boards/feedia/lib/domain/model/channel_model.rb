# frozen_string_literal: true

# What a feed said when it was read: the FeedModel it came from, the
# channel's title, link and description, and its items (ItemModel).
ChannelModel = Data.define(:feed, :title, :link, :description, :items)
