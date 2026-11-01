# frozen_string_literal: true

# A board of the Teletype Games BBS Network as a building of the town (see
# lib/content/network.yml): +place+ is {modern: [col, row], c64: [col, row]},
# +accent+ a #rrggbb, +c64+ a C64 colour name.
NetworkBoardModel = Struct.new(:id, :name, :port, :building, :about, :short, :words, :accent, :c64, :place,
                               keyword_init: true) do
  def address = "teletypegames.org:#{port}"
end
