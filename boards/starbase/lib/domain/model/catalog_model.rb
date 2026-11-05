# frozen_string_literal: true

# The whole catalog as the board holds it: the series and the episodes of a
# catalog file (Rubbs::Common::Storage::Snapshot), frozen.
CatalogModel = Data.define(:series, :episodes) do
  def self.from_records(records)
    new(
      series:   Array(records['series']).map { |r| SeriesModel.from_record(r) }.freeze,
      episodes: Array(records['episodes']).map { |r| EpisodeModel.from_record(r) }.freeze
    )
  end
end
