# frozen_string_literal: true

# One call to the debrief terminal as the board keeps it, and the rules of
# what a caller types into it: no control characters, no surrounding space,
# each field within its limit, and an email only when it is one (the game's
# contact list, so it is kept as typed, but never as junk).
class SessionModel < Data.define(:session_id, :timestamp, :player_name, :code, :feedback, :email)
  LIMITS = { player_name: 40, code: 12, feedback: 1000, email: 254 }.freeze
  EMAIL  = /\A[^@\s]+@[^@\s]+\.[^@\s]+\z/

  # The fields the board keeps of +raw+ (name => what was typed): cleaned,
  # trimmed and cut to LIMITS; an email that is not a valid address is left
  # out, as is any field the board does not know.
  def self.fields(**raw)
    raw.slice(*LIMITS.keys).filter_map { |name, value| field(name, value) }.to_h
  end

  def self.field(name, value)
    text = BBS::Text.utf8(value).strip
    if name == :email
      [name, text] if email?(text)
    else
      [name, BBS::Text.clean(text, keep_newlines: false).strip[0, LIMITS[name]]]
    end
  end
  private_class_method :field

  # Whether +text+ is an address the board keeps: printable characters
  # only (no control or bidirectional character), one @ and a dotted domain.
  def self.email?(text) = text.length <= LIMITS[:email] && !text.match?(BBS::Text::CONTROLS) && text.match?(EMAIL)

  # A model from a row of the sessions store (column name => value).
  def self.from_row(row) = new(**members.to_h { |name| [name, row[name.to_s]] })
end
