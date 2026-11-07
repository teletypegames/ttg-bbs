# frozen_string_literal: true

# The wiki as the board shows it: the page index every session shares, with
# the private flag carried down to the pages under a private one, and a page
# as markdown, its problems worded as markdown too, so the reader can show
# them as they are. A caller may re-read the index now and then, never so
# often that the wiki feels it.
class WikiService
  # Refreshes per caller, and for the whole board, a minute.
  CALLER_REFRESHES = 2
  BOARD_REFRESHES  = 10

  attr_reader :pages

  def initialize(
    repository,
    caller_refreshes: Rubbs::Common::Line::RateLimit.new(limit: CALLER_REFRESHES, per: 60),
    board_refreshes: Rubbs::Common::Line::RateLimit.new(limit: BOARD_REFRESHES, per: 60)
  )
    @repository       = repository
    @pages            = []
    @caller_refreshes = caller_refreshes
    @board_refreshes  = board_refreshes
  end

  def base_url = @repository.base_url

  # Reads the index again; every session sees the new one. Raises when the
  # wiki does not answer. The board's index loader calls it.
  def refresh_index!
    @pages = index(@repository.sitemap)
  end

  # A caller's refresh (+caller_key+, Rubbs::Common::Line::RateLimit.caller_key): forgets the
  # cached pages and reads the index again. Returns :refreshed, :limited when
  # the caller or the board has refreshed too often this minute, or :failed
  # when the wiki does not answer.
  def refresh(caller_key)
    return :limited unless Rubbs::Common::Line::RateLimit.allow_all?([[@caller_refreshes, caller_key],
                                                                      [@board_refreshes, :board]])

    @repository.clear_cache
    refresh_index!
    :refreshed
  rescue WikiRepository::Error => e
    Rubbs.log('refresh', e)
    :failed
  end

  # The markdown of +page+ (a PageModel), under its title as an H1. What went
  # wrong goes to the log; the caller only learns that it did.
  def page_markdown(page)
    data = @repository.page(page.route, private: page.private?)
    Rubbs.achieve(:page, ref: page.route.to_s) unless data['error']
    case data['error']
    when 'forbidden' then "# Forbidden\n\nThe wiki refused the supervisor access for `#{page.route}`."
    when nil         then "# #{data['title']}\n\n#{data['markdown']}"
    else                  "# Not found\n\nNo wiki page at `#{page.route}`."
    end
  rescue WikiRepository::Error => e
    Rubbs.log(page.route, e)
    "# Error\n\nThe wiki did not answer for `#{page.route}`. Try again in a minute."
  end

  private

  # The pages sorted by route (children follow their parents), a page under
  # a private one private too.
  def index(pages)
    private_roots = pages.select(&:private?).map(&:route)
    pages.map { |p| !p.private? && private_roots.any? { |r| p.route.start_with?("#{r}/") } ? p.as_private : p }
      .sort_by(&:route)
  end
end
