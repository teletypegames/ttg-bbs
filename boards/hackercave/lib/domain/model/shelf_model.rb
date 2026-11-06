# frozen_string_literal: true

# A shelf of RFCs. +kind+ says where its RFCs come from: :curated (a list of
# config/shelves.yml, +key+ its index there), :series (+key+ "STD", "BCP" or
# "FYI"), :status (+key+ a status of the index, "INTERNET STANDARD"),
# :decade (+key+ its first year) or :newest. +about+ is a line on it, +count+
# how many RFCs stand on it.
ShelfModel = Data.define(:kind, :key, :name, :about, :count) do
  def curated? = kind == :curated
end
