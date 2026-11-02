# frozen_string_literal: true

# The board itself, whatever terminal a caller has: the wiki's API wired to
# the shared page index, and the supervisor lock. The one place that reads
# ENV. Both faces (lib/ui/modern, lib/ui/petscii) work on one instance of it.
class WikiBBS
  INDEX_RETRY = 10 # seconds, doubled after each failure up to INDEX_RETRY_MAX
  INDEX_RETRY_MAX = 300
  USER_AGENT  = 'TTGWikiBBS/1.0 (TTG Wiki BBS, Teletype Games telnet BBS; https://git.teletypegames.org/bbs/wiki-bbs)'

  attr_reader :wiki, :supervisor, :idle_seconds

  def initialize(env = ENV)
    password      = env.fetch('WIKI_BBS_SUPERVISOR_PASSWORD', '').to_s
    repository    = WikiRepository.new(env.fetch('WIKI_BBS_URL', 'http://localhost:9120'),
                                       user_agent: USER_AGENT, token: password)
    @wiki         = WikiService.new(repository)
    @supervisor   = SupervisorService.new(password)
    @idle_seconds = env.fetch('WIKI_BBS_IDLE', 900).to_i
  end

  # The services by name.
  def services = { wiki: @wiki, supervisor: @supervisor }

  # Loads the page index in the background (BBS.background) and keeps trying
  # until the wiki answers. A stack deploy recreates grav together with this
  # container, so the wiki is often not up yet when the board starts. Callers
  # can also pull the index in with Wiki > Refresh index.
  def index_in_background
    BBS.background('index', retry_after: INDEX_RETRY, max_retry: INDEX_RETRY_MAX) do
      @wiki.refresh_index!
      BBS.log('index', "#{@wiki.pages.size} pages from #{@wiki.base_url}")
    end
  end
end
