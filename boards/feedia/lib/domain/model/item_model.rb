# frozen_string_literal: true

# One item of a feed: its title, link, date (a Time or nil), author and its
# text in Markdown.
ItemModel = Data.define(:title, :link, :date, :author, :markdown)
