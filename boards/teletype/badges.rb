# frozen_string_literal: true

# The badges of Teletype BBS (TTG::Badges): the games room. The Chat of Ra
# reports :riddle, TTG Trivia :trivia.
Rubbs.badges :teletype do
  event :riddle, ref: 'the riddle'
  event :trivia, correct: 'right answers', total: 'questions'

  badge :blessing_of_ra do
    title  'Blessing of Ra'
    hint   'Solve three riddles of Ra in the Chat of Ra.'
    emblem 'R', :yellow
    on(:riddle).distinct(:ref).reaches 3
  end

  badge :quiz_ace do
    title  'Quiz Ace'
    hint   'Answer eight of ten in TTG Trivia.'
    emblem 'Q', :cyan
    on(:trivia, correct: 8..10).once
  end

  badge :know_it_all, secret: true do
    title  'Know-it-all'
    hint   'Answer every question of a TTG Trivia game.'
    emblem '!', :yellow
    on(:trivia, correct: 10..).once
  end
end
