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

  # One entry of a year's pack list in the API; nil when it is not one.
  def self.from_api(hash)
    return nil unless hash.is_a?(Hash) && hash['name'].is_a?(String) && !hash['name'].empty?

    new(name: hash['name'], year: hash['year'].to_i, groups: Array(hash['groups']).map(&:to_s))
  end
end
