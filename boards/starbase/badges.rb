# frozen_string_literal: true

# The badges of Starbase BBS (TTG::Badges): Memory Alpha. LibraryService
# reports :article.
Rubbs.badges :starbase do
  event :article, ref: 'the title'

  badge :trekkie do
    title  'Trekkie'
    hint   'Read Memory Alpha articles in Starbase BBS: 10, 50, 200.'
    emblem 'T', :lightblue
    on(:article).distinct(:ref).tiers bronze: 10, silver: 50, gold: 200
  end
end
