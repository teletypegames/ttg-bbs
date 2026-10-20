# frozen_string_literal: true

require_relative 'http_json'
require_relative '../model/wiki_page_model'

# Reads the Grav wiki through its JSON endpoints. English is unprefixed,
# Hungarian lives under /hu. The BBS is public, so login-only pages are
# left out.
class WikiRepository
  include HttpJson

  BASE_URL = 'https://wiki.teletypegames.org'

  def list(tag, lang: 'en')
    cached([:tag, tag, lang]) do
      data = get_json("#{base(lang)}/custom/pages.json", tag: tag)
      (data['pages'] || []).reject { |p| p['private'] }.map { |p| model(p) }
    end
  rescue => e
    warn "WikiRepository list error: #{e}"
    []
  end

  # Every public page below a route prefix (not the section index itself),
  # in sitemap order.
  def section(prefix, lang: 'en')
    cached([:section, prefix, lang]) do
      data = get_json("#{base(lang)}/custom/sitemap.json")
      (data['pages'] || []).select do |p|
        p['route'].start_with?("#{prefix}/") && !p['private']
      end.map { |p| model(p) }
    end
  rescue => e
    warn "WikiRepository section error: #{e}"
    []
  end

  def content(path, lang: 'en')
    cached([:page, path, lang]) do
      get_json("#{base(lang)}/custom/page.json", route: "/#{path}")['markdown'] || ''
    end
  rescue => e
    warn "WikiRepository content error: #{e}"
    ''
  end

  def page_url(path, lang: 'en') = "#{base(lang)}/#{path}"

  private

  def base(lang) = lang == 'hu' ? "#{BASE_URL}/hu" : BASE_URL

  def model(p)
    WikiPageModel.new(
      id:          p['id'],
      path:        p['route'].to_s.delete_prefix('/'),
      title:       p['title'],
      description: p['description'],
      created_at:  p['createdAt'] || p['updatedAt'],
      locale:      p['locale']
    )
  end
end
