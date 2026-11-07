# frozen_string_literal: true

# The badges of the whole network (TTG::Badges): every board counts for
# them. The events of the Wall, the feedback and the letters come from
# ttg-common's own screens (TTG::Wall, TTG::Feedback, TTG::PrivateMessage).
Rubbs.badges :network do
  event :wall_note
  event :feedback
  event :letter

  badge :first_light do
    title  'First Light'
    hint   'Call any board of the network while logged in.'
    emblem '·', :white
    on(:call).once
  end

  badge :tourist do
    title  'Tourist'
    hint   'Call five different boards of the network.'
    emblem '♦', :cyan
    on(:call).distinct(:board).reaches 5
  end

  badge :globetrotter do
    title  'Globetrotter'
    hint   'Call every board of the network.'
    emblem '☼', :yellow
    on(:call).distinct(:board).reaches :all_boards
  end

  badge :regular do
    title  'Regular'
    hint   'Call the network on days in a row: 7, 30, 100.'
    emblem '♥', :red
    on(:call).streak(:days).tiers bronze: 7, silver: 30, gold: 100
  end

  badge :night_owl do
    title  'Night Owl'
    hint   'Call between midnight and four in the morning.'
    emblem '☾', :blue
    on(:call, hour: 0...4).once
  end

  badge :early_bird do
    title  'Early Bird'
    hint   'Call at dawn.'
    emblem '¤', :orange
    on(:call, time_of_day: :dawn).once
  end

  badge :commodore do
    title  'Commodore'
    hint   'Call on a Commodore 64.'
    emblem 'C', :lightblue
    on(:call, face: :petscii).once
  end

  badge :both_worlds do
    title  'Both Worlds'
    hint   'Call on a modern terminal and on a Commodore 64.'
    emblem '≈', :lightgreen
    on(:call).distinct(:face).reaches 2
  end

  badge :marathon do
    title  'Marathon'
    hint   'Stay an hour in one call.'
    emblem '∞', :green
    on(:hangup).sum(:minutes).within(:call).reaches 60
  end

  badge :graffiti do
    title  'Graffiti'
    hint   'Write on the walls of different boards: 1, 5, 10.'
    emblem '#', :orange
    on(:wall_note).distinct(:board).tiers bronze: 1, silver: 5, gold: 10
  end

  badge :pen_pal do
    title  'Pen Pal'
    hint   'Send a letter to another caller.'
    emblem '✉', :white
    on(:letter).once
  end

  badge :suggestion_box do
    title  'Suggestion Box'
    hint   'Send feedback to the sysops.'
    emblem '?', :yellow
    on(:feedback).once
  end

  badge :pumpkin_head, secret: true do
    title  'Pumpkin Head'
    hint   'Call on a night of the pumpkin, at the end of October.'
    emblem 'Ö', :orange
    on(:call, season: :pumpkin, time_of_day: :night).once
  end

  badge :snowman, secret: true do
    title  'Snowman'
    hint   'Call while the snow falls on the clubhouse.'
    emblem '*', :white
    on(:call, season: :snow).once
  end

  badge :fireworks, secret: true do
    title  'Fireworks'
    hint   'Call on New Year\'s Eve.'
    emblem '✦', :yellow
    on(:call, season: :fireworks).once
  end

  badge :pioneer, manual: true do
    title  'Pioneer'
    hint   'Had an account before the badges came, 8 November 2026.'
    emblem '!', :yellow
  end

  badge :completionist do
    title  'Completionist'
    hint   'Tourist, Regular and Graffiti.'
    emblem '★', :yellow
    all_of :tourist, :regular, :graffiti
  end
end
