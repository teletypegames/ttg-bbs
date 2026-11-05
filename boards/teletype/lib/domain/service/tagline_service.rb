# frozen_string_literal: true

require 'yaml'

# The board's quotes: the taglines of lib/content/taglines.yml and the
# team's mottos, as [text, who] pairs (who is nil for a tagline).
class TaglineService
  PATH = File.expand_path('../../content/taglines.yml', __dir__)
  LIST = YAML.safe_load_file(PATH).freeze

  def initialize(site) = @site = site

  # A tagline or one of the team's mottos.
  def pick
    (LIST.map { |t| [t, nil] } + mottos).sample
  end

  private

  def mottos = @site.members.reject { |m| m.motto.to_s.strip.empty? }.map { |m| [m.motto, m.nick] }
end
