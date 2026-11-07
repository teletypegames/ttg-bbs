# frozen_string_literal: true

# The badges of Scriptorium BBS (TTG::Badges): the books of Project
# Gutenberg. ReadingService reports :book when a book is opened.
Rubbs.badges :scriptorium do
  event :book, ref: 'the Gutenberg id'

  badge :bookworm do
    title  'Bookworm'
    hint   'Open books in Scriptorium BBS: 1, 10, 50.'
    emblem '¶', :brown
    on(:book).distinct(:ref).tiers bronze: 1, silver: 10, gold: 50
  end
end
