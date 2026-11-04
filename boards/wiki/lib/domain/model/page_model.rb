# frozen_string_literal: true

# One page of the wiki's index (an entry of /custom/sitemap.json): its route,
# title, depth in the tree, the day it was last updated, its tags, and
# whether it is private, by its own flag or by a private ancestor's. The
# texts of the wiki are cleaned of control characters.
class PageModel
  # Where the wiki is on the web, for a caller's browser: the board reads it
  # on the Docker network (WIKI_BBS_URL), under another address.
  PUBLIC_URL = 'https://wiki.teletypegames.org'

  attr_reader :route, :title, :depth, :updated_at, :tags

  def self.from_json(entry)
    new(
      route:      clean(entry['route']),
      title:      clean(entry['title']),
      updated_at: clean(entry['updatedAt'])[0, 10],
      tags:       Array(entry['tags']).map { |tag| clean(tag) },
      private:    entry['private'] == true
    )
  end

  def self.clean(text) = BBS::Text.clean(text.to_s, keep_newlines: false)
  private_class_method :clean

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

  # The page on the web; a private one asks for the wiki's login there.
  def public_url = "#{PUBLIC_URL}#{route}"

  # The same page, private.
  def as_private = self.class.new(route: route, title: title, updated_at: updated_at, tags: tags, private: true)
end
