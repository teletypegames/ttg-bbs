# frozen_string_literal: true

require 'time'

# A line of the oneliners wall of before the network's wall (ttg-common
# TTG::Wall), kept as the archive, with when it was handed over to the
# wall (+exported_at+).
class OnelinerModel < Rubbs::Common::Storage::Model
  table :oneliners

  # The lines not handed over yet, oldest first.
  def self.unexported = where(exported_at: nil).order(:id).all

  # The line as a row of TTG::Wall's import.
  def to_wall = { name: username, text: text, created_at: ExportService.utc(timestamp) }
end
