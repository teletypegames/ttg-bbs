# frozen_string_literal: true

# The badges of Feedia BBS (TTG::Badges): the feeds. FeedService reports
# :feed.
Rubbs.badges :feedia do
  event :feed, ref: 'the feed'

  badge :subscriber do
    title  'Subscriber'
    hint   'Read different feeds in Feedia BBS: 5, 20.'
    emblem '≡', :orange
    on(:feed).distinct(:ref).tiers bronze: 5, silver: 20
  end
end
