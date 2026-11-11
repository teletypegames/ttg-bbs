# frozen_string_literal: true

# The whole catalog as the board holds it: the films of a catalog file
# (Rubbs::Common::Storage::Snapshot), the best known first, frozen.
CatalogModel = Data.define(:films) do
  def self.from_records(records)
    new(films: Array(records['films']).map { |r| CatalogFilmModel.from_record(r) }.reject { |f| f.title.empty? }.freeze)
  end
end
