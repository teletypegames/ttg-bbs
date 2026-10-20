# frozen_string_literal: true

require 'time'

class GameModel
  Asset = Struct.new(:kind, :path)

  attr_reader :name, :title, :platform, :category, :author, :desc, :story,
              :version, :released_at, :assets, :external_links

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
    @version        = latest['version'].to_s
    @released_at    = parse_time(latest['createdAt'])
    @assets         = (latest['assets'] || []).filter_map do |a|
      Asset.new(a['kind'].to_s, a['path'].to_s) unless a['path'].to_s.empty?
    end
    @external_links = (sw['externalLinks'] || []).filter_map do |l|
      { label: l['label'].to_s, url: l['url'].to_s } unless l['url'].to_s.empty?
    end
  end

  def released? = !@version.empty?
  def dev_build? = @version.start_with?('dev-')

  private

  def parse_time(value)
    value ? Time.parse(value) : nil
  rescue ArgumentError
    nil
  end
end
