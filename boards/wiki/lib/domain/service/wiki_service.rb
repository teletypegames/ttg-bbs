# frozen_string_literal: true

# The wiki as the board shows it: the page index every session shares, with
# the private flag carried down to the pages under a private one, and a page
# as markdown, its problems worded as markdown too, so the reader can show
# them as they are.
class WikiService
  attr_reader :pages

  def initialize(repository)
    @repository = repository
    @pages      = []
  end

  def base_url = @repository.base_url

  # Reads the index again; every session sees the new one. Raises when the
  # wiki does not answer.
  def refresh_index!
    @pages = index(@repository.sitemap)
  end

  # The markdown of the page at +route+, under its title as an H1.
  def page_markdown(route)
    data = @repository.page(route)
    case data['error']
    when 'forbidden'
      "# Forbidden\n\nThe wiki refused the supervisor token for `#{route}` — " \
      'check that SUPERVISOR_PASSWORD matches on both services.'
    when nil
      "# #{data['title']}\n\n#{data['markdown']}"
    else
      "# Not found\n\nNo wiki page at `#{route}`."
    end
  rescue StandardError => e
    "# Error\n\nCould not fetch `#{route}`:\n\n`#{e.class}: #{e.message}`"
  end

  def clear_cache = @repository.clear_cache

  private

  # The pages sorted by route (children follow their parents), a page under
  # a private one private too.
  def index(pages)
    private_roots = pages.select(&:private?).map(&:route)
    pages.map { |p| !p.private? && private_roots.any? { |r| p.route.start_with?("#{r}/") } ? p.as_private : p }
         .sort_by(&:route)
  end
end
