# frozen_string_literal: true

# The badges of TTG Gate BBS (TTG::Badges): Global Discovery and Today.
# DialService reports :dial, the Today tab :today.
Rubbs.badges :'ttg-gate' do
  event :dial, ref: 'the board of the catalog'
  event :today

  badge :explorer do
    title  'Explorer'
    hint   'Dial the telnet BBSes of the world from Global Discovery: 1, 10, 50.'
    emblem '@', :lightgreen
    on(:dial).distinct(:ref).tiers bronze: 1, silver: 10, gold: 50
  end

  badge :newsreader do
    title  'Newsreader'
    hint   'Read the gate\'s Today page seven days in a row.'
    emblem 'N', :white
    on(:today).streak(:days).reaches 7
  end
end
