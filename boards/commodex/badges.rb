# frozen_string_literal: true

# The badges of Commodex BBS (TTG::Badges): the C64 games and their tips.
# TipService reports :tip, AboutService :game (what Wikipedia says of a game
# was read; The Hunt can send callers there).
Rubbs.badges :commodex do
  event :tip, ref: 'the game'
  event :game, ref: 'the game', title: 'its title'

  badge :tipster do
    title  'Tipster'
    hint   'Leave tips for C64 games in Commodex BBS: 1, 10.'
    emblem 'C', :lightblue
    on(:tip).distinct(:ref).tiers bronze: 1, silver: 10
  end
end
