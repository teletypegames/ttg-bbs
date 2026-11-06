# frozen_string_literal: true

# The lead of a game's English Wikipedia article as plain text: its
# paragraphs, the article's title and address. The text is Wikipedia's,
# under CC BY-SA 4.0.
SummaryModel = Data.define(:title, :url, :paragraphs)
SummaryModel::LICENSE = 'Text from Wikipedia, CC BY-SA 4.0'
