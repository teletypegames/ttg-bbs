# frozen_string_literal: true

# The Trophy Room of the gate (GATE_TROPHY_ROOM.md): what Teletype Games has
# done, on one screen. Trophies::Source fetches the numbers in the background
# with the Today tab's (Herald) into its cache, from Grafana's data sources
# (Trophies::Grafana) and the WarpEngine catalog; a caller's Trophies::Room
# is made from the cache, never from the web.
module Trophies
  # A number with a space between the thousands (5 761), or - when there is
  # none.
  def self.number(value)
    return '-' if value.nil?

    value.to_i.to_s.reverse.scan(/\d{1,3}/).join(' ').reverse.then { |s| value.to_i.negative? ? "-#{s}" : s }
  end
end

require_relative 'trophies/grafana'
require_relative 'trophies/model/queries'
require_relative 'trophies/source'
require_relative 'trophies/room'
