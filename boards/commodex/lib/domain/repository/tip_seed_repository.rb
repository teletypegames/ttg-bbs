# frozen_string_literal: true

require 'yaml'

# The tips the board ships with (config/tips.yml): a list of game (QID),
# key, handle and text, each approved from the start. A missing or broken
# file gives none.
class TipSeedRepository
  def initialize(path)
    @path = path
  end

  def all
    return [] unless File.exist?(@path)

    Array(YAML.safe_load_file(@path)).filter_map { |entry| seed(entry) if valid?(entry) }
  rescue StandardError => e
    Rubbs.log('tips', "reading #{@path}: #{e.class}: #{e.message}")
    []
  end

  private

  def valid?(entry)
    entry.is_a?(Hash) && entry['game'].to_s.match?(/\AQ\d+\z/) && !entry['key'].to_s.empty? &&
      !entry['text'].to_s.strip.empty?
  end

  def seed(entry)
    { game_id: entry['game'].to_s, seed: entry['key'].to_s, handle: entry['handle'].to_s, text: entry['text'].to_s.strip }
  end
end
