# frozen_string_literal: true

require 'time'

# A title of the catalog, with what the doors and the TTG Master read of it:
# its name and platform, the latest release and that release's files.
class GameModel
  Asset = Struct.new(:kind, :path)

  attr_reader :name, :title, :platform, :desc, :version, :released_at, :assets

  def initialize(entry)
    sw     = entry['software']      || {}
    latest = entry['latestRelease'] || {}
    @name        = sw['name'].to_s
    @title       = sw['title'].to_s
    @platform    = sw['platform'].to_s
    @desc        = sw['desc'].to_s
    @version     = latest['version'].to_s
    @released_at = parse_time(latest['createdAt'])
    @assets      = assets_of(latest)
  end

  def released? = !@version.empty?
  def dev_build? = @version.start_with?('dev-')

  private

  def assets_of(release)
    (release['assets'] || []).filter_map do |a|
      Asset.new(a['kind'].to_s, a['path'].to_s) unless a['path'].to_s.empty?
    end
  end

  def parse_time(value)
    value ? Time.parse(value) : nil
  rescue ArgumentError
    nil
  end
end
