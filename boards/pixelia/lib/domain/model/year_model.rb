# frozen_string_literal: true

# A year of the 16colo.rs archive and the number of art packs from it.
class YearModel
  attr_reader :year, :packs

  def initialize(year, packs)
    @year  = year
    @packs = packs
    freeze
  end
end
