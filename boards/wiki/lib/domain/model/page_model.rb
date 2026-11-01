# frozen_string_literal: true

# One page of the wiki's index (an entry of /custom/sitemap.json): its route,
# title, depth in the tree, the day it was last updated, its tags, and
# whether it is private, by its own flag or by a private ancestor's.
class PageModel
  attr_reader :route, :title, :depth, :updated_at, :tags

  def self.from_json(entry)
    new(route:      entry['route'].to_s,
        title:      entry['title'].to_s,
        updated_at: entry['updatedAt'].to_s[0, 10],
        tags:       entry['tags'] || [],
        private:    entry['private'] == true)
  end

  def initialize(route:, title:, updated_at:, tags:, private:)
    @route      = route
    @title      = title
    @depth      = [route.count('/'), 1].max
    @updated_at = updated_at
    @tags       = tags
    @private    = private
    freeze
  end

  def private? = @private

  # The same page, private.
  def as_private = self.class.new(route: route, title: title, updated_at: updated_at, tags: tags, private: true)
end
