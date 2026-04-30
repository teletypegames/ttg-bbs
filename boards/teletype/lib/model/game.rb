# frozen_string_literal: true

class Game
  attr_reader :title, :platform, :author, :desc,
              :play_path, :download_path, :source_path, :docs_path,
              :release_count

  def initialize(entry)
    sw     = entry['software']      || {}
    latest = entry['latestRelease'] || {}
    @title         = sw['title'].to_s
    @platform      = sw['platform'].to_s
    @author        = sw['author'].to_s
    @desc          = sw['desc'].to_s
    @play_path     = latest['htmlFolderPath'].to_s
    @download_path = latest['cartridgePath'].to_s
    @source_path   = latest['sourcePath'].to_s
    @docs_path     = latest['docsFolderPath'].to_s
    @release_count = (entry['releases'] || []).length
  end
end
