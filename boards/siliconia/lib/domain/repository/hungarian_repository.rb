# frozen_string_literal: true

require 'yaml'

# The machines of Hungary kept by hand (config/hungarian.yml): { QID => kind } of the ones Wikidata
# does not mark Hungarian or does not put under the catalog's roots. A missing or broken file gives none.
class HungarianRepository
  KINDS = %w[handheld console home micro pc].freeze

  def initialize(path)
    @path = path
  end

  def kinds
    return {} unless File.exist?(@path)

    Array(YAML.safe_load_file(@path)).grep(Hash).filter_map do |row|
      id, kind = row.values_at('id', 'kind').map(&:to_s)
      [id, kind] if id.match?(/\AQ\d+\z/) && KINDS.include?(kind)
    end.to_h
  rescue StandardError => e
    Rubbs.log('hungarian', "reading #{@path}: #{e.class}: #{e.message}")
    {}
  end

  def ids = kinds.keys
end
