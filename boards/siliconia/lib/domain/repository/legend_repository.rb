# frozen_string_literal: true

require 'yaml'

# The QIDs of the Legends shelf (config/legends.yml). A missing or broken file gives none.
class LegendRepository
  def initialize(path)
    @path = path
  end

  def ids
    return [] unless File.exist?(@path)

    Array(YAML.safe_load_file(@path)).map(&:to_s).grep(/\AQ\d+\z/)
  rescue StandardError => e
    Rubbs.log('legends', "reading #{@path}: #{e.class}: #{e.message}")
    []
  end
end
