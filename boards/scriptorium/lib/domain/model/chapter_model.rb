# frozen_string_literal: true

# One chapter of a book's cleaned text: its number (from 1), its title, and
# where its bytes are in the cached text file.
ChapterModel = Data.define(:number, :title, :offset, :length)
