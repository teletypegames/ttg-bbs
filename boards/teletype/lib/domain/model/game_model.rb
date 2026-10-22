# frozen_string_literal: true

require 'time'

class GameModel
  Asset   = Struct.new(:kind, :path)
  Release = Struct.new(:version, :released_at, :downloads, :assets)

  attr_reader :name, :title, :platform, :category, :author, :desc, :story,
              :version, :released_at, :assets, :external_links,
              :status, :license, :downloads, :releases, :platform_links

  def initialize(entry)
    sw     = entry['software']      || {}
    latest = entry['latestRelease'] || {}
    @name           = sw['name'].to_s
    @title          = sw['title'].to_s
    @platform       = sw['platform'].to_s
    @category       = sw['category'].to_s
    @author         = sw['author'].to_s
    @desc           = sw['desc'].to_s
    @story          = sw['story'].to_s
    @status         = sw['status'].to_s
    @license        = sw['license'].to_s
    @version        = latest['version'].to_s
    @released_at    = parse_time(latest['createdAt'])
    @assets         = assets_of(latest)
    @downloads      = entry['totalDownloads'].to_i
    @releases       = (entry['releases'] || []).map { |r| release(r) }.sort_by { |r| r.released_at || Time.at(0) }
    @external_links = links(sw['externalLinks'], :label)
    @platform_links = links(sw['platformLinks'], :name)
  end

  def released? = !@version.empty?
  def dev_build? = @version.start_with?('dev-')

  private

  def release(entry)
    Release.new(entry['version'].to_s, parse_time(entry['createdAt']), entry['downloadCount'].to_i, assets_of(entry))
  end

  def assets_of(release)
    (release['assets'] || []).filter_map do |a|
      Asset.new(a['kind'].to_s, a['path'].to_s) unless a['path'].to_s.empty?
    end
  end

  def links(list, label_key)
    (list || []).filter_map do |l|
      { label: l[label_key.to_s].to_s, url: l['url'].to_s } unless l['url'].to_s.empty?
    end
  end

  def parse_time(value)
    value ? Time.parse(value) : nil
  rescue ArgumentError
    nil
  end
end
