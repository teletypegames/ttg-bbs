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

    Array(YAML.safe_load_file(@path)).filter_map do |t|
      next unless t.is_a?(Hash) && t['game'].to_s.match?(/\AQ\d+\z/) && !t['key'].to_s.empty? && !t['text'].to_s.strip.empty?

      { game_id: t['game'].to_s, seed: t['key'].to_s, handle: t['handle'].to_s, text: t['text'].to_s.strip }
    end
  rescue StandardError => e
    warn "commodex-bbs: reading #{@path}: #{e.class}: #{e.message}"
    []
  end
end
