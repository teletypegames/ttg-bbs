# frozen_string_literal: true

# The badges of TTG Blog BBS (TTG::Badges): the bloggers. PostService
# reports :publish.
Rubbs.badges :'ttg-blog' do
  event :publish, ref: 'the post'

  badge :columnist do
    title  'Columnist'
    hint   'Publish posts on the TTG blog: 1, 10.'
    emblem 'B', :green
    on(:publish).distinct(:ref).tiers bronze: 1, silver: 10
  end
end
