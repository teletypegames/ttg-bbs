# frozen_string_literal: true

require 'yaml'

# The feeds of config/feeds.yml (FeedModel), in the order a caller sees
# them; an entry without a name or an http(s) url is left out.
class FeedListRepository
  attr_reader :all

  def initialize(path)
    @all = Array(YAML.safe_load_file(path)).filter_map { |entry| FeedModel.from_entry(entry) }.freeze
  rescue SystemCallError, Psych::Exception => e
    Rubbs.log('feeds', "none from #{path}: #{e.class}: #{e.message}")
    @all = [].freeze
  end
end
