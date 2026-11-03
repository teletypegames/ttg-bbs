# frozen_string_literal: true

# One entry of the Jargon File's lexicon: its id (the order of the file),
# its headword, what follows the headword on its line (the pronunciation,
# "/klooj/"), and its body as paragraphs, each [kind, text]: :text (a
# paragraph on one line) or :pre (lines kept, an example or a table). A
# {word} in the text is a link to the entry of that headword.
class JargonEntryModel < Data.define(:id, :headword, :pron, :paragraphs)
  # A link in the text.
  LINK = /\{([^{}]+)\}/

  # The key a link finds an entry by: the headword in lowercase.
  def self.key(headword) = headword.downcase.gsub(/\s+/, ' ').strip

  # The headwords the entry links to, in order, each once.
  def links = paragraphs.flat_map { |_, text| text.scan(LINK).flatten }.map { |w| w.gsub(/\s+/, ' ') }.uniq

  # The first paragraph on one line, without the braces of its links.
  def summary = paragraphs.find { |kind, _| kind == :text }&.last.to_s.gsub(LINK, '\1')
end
