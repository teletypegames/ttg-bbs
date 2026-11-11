# frozen_string_literal: true

# The badges of Kinema BBS (TTG::Badges): FilmService reports :film (a
# film's page opened; The Hunt can send callers there), RatingService
# :rating and :seen.
Rubbs.badges :kinema do
  event :film, ref: 'the film', title: 'its title'
  event :rating, ref: 'the film', title: 'its title'
  event :seen, ref: 'the film', title: 'its title'

  badge :cinephile do
    title  'Cinephile'
    hint   'Open the pages of films in Kinema BBS: 10, 50, 200.'
    emblem 'K', :yellow
    on(:film).distinct(:ref).tiers bronze: 10, silver: 50, gold: 200
  end

  badge :critic do
    title  'Critic'
    hint   'Rate films in Kinema BBS: 1, 10, 50.'
    emblem 'R', :orange
    on(:rating).distinct(:ref).tiers bronze: 1, silver: 10, gold: 50
  end

  badge :film_buff do
    title  'Film buff'
    hint   'Mark films as seen in Kinema BBS: 10, 100, 500.'
    emblem 'M', :lightred
    on(:seen).distinct(:ref).tiers bronze: 10, silver: 100, gold: 500
  end
end
