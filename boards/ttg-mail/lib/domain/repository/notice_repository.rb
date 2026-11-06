# frozen_string_literal: true

require 'yaml'

# The notices of a YAML file, read once. A missing or broken file gives none.
class NoticeRepository
  attr_reader :all

  def initialize(path)
    @all = Array(YAML.safe_load_file(path)).map { |entry| NoticeModel.from_entry(entry) }.freeze
  rescue SystemCallError, Psych::Exception, KeyError => e
    Rubbs.log('notices', "none from #{path}: #{e.class}: #{e.message}")
    @all = [].freeze
  end
end
