# frozen_string_literal: true

require 'yaml'

# The board's own shelves (config/shelves.yml): each a name, a line on it,
# and its RFCs in order, each with the number, the title (so the shelf
# stands before the index is imported) and a note.
#
#   - name: Telnet
#     about: The protocol this board talks.
#     rfcs:
#       - { rfc: 854, title: Telnet Protocol Specification, note: the protocol }
class ShelvesRepository
  Shelf = Data.define(:name, :about, :entries)

  def initialize(path)
    @shelves = YAML.safe_load_file(path).map do |s|
      Shelf.new(
        name:    s.fetch('name').to_s,
        about:   s['about'].to_s,
        entries: s.fetch('rfcs').map { |e| [Integer(e.fetch('rfc')), e['title'].to_s, e['note']&.to_s] }
      )
    end.freeze
  rescue SystemCallError, Psych::Exception, KeyError, ArgumentError, NoMethodError, TypeError => e
    BBS.log('shelves', "#{path}: #{e.class}: #{e.message}")
    @shelves = [].freeze
  end

  def all = @shelves

  def [](index) = @shelves[index]
end
