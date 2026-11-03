# frozen_string_literal: true

# A part of the Jargon File that is not the lexicon: the welcome, a chapter
# of the introduction, an appendix (Hacker Folklore, A Portrait of J. Random
# Hacker, …) or the bibliography. +paragraphs+ as in JargonEntryModel, plus
# :heading for a heading inside it ("The Story of Mel").
JargonSectionModel = Data.define(:id, :title, :paragraphs)
