# frozen_string_literal: true

# An art pack of the 16colo.rs archive: its name (the key of its pages and
# files), its year and the groups that released it.
class PackModel
  attr_reader :name, :year, :groups

  def initialize(name:, year:, groups:)
    @name   = name
    @year   = year
    @groups = groups
    freeze
  end

  def credits = @groups.join(', ')

  # One entry of a year's pack list in the API (its texts cleaned); nil when
  # it is not one.
  def self.from_api(hash)
    return nil unless hash.is_a?(Hash) && hash['name'].is_a?(String)

    name = clean(hash['name'])
    return nil if name.empty?

    new(name: name, year: hash['year'].to_i, groups: Array(hash['groups']).map { |g| clean(g) })
  end

  def self.clean(text) = BBS::Text.clean(text, keep_newlines: false).strip
end
