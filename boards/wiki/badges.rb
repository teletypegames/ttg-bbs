# frozen_string_literal: true

# The badges of TTG Wiki BBS (TTG::Badges): the wiki. WikiService reports
# :page.
Rubbs.badges :wiki do
  event :page, ref: 'the route'

  badge :scholar do
    title  'Scholar'
    hint   'Read pages of the TTG wiki: 10, 50, 200.'
    emblem 'S', :cyan
    on(:page).distinct(:ref).tiers bronze: 10, silver: 50, gold: 200
  end
end
