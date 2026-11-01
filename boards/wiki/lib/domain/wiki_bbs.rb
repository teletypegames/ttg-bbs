# frozen_string_literal: true

# The board itself, whatever terminal a caller has: the wiki's API wired to
# the shared page index, and the supervisor lock. The one place that reads
# ENV. Both faces (lib/ui/modern, lib/ui/petscii) work on one instance of it.
class WikiBBS
  INDEX_RETRY = 10 # seconds

  attr_reader :wiki, :supervisor, :idle_seconds

  def initialize
    password     = ENV.fetch('SUPERVISOR_PASSWORD', '').to_s
    repository   = WikiRepository.new(ENV.fetch('WIKI_URL', 'http://localhost:9120'), token: password)
    @wiki        = WikiService.new(repository)
    @supervisor  = SupervisorService.new(password)
    @idle_seconds = ENV.fetch('BBS_IDLE', 900).to_i
  end

  # The services by name.
  def services = { wiki: @wiki, supervisor: @supervisor }

  # Loads the page index in the background and keeps trying until the wiki
  # answers. A stack deploy recreates grav together with this container, so
  # the wiki is often not up yet when the board starts. Callers can also pull
  # the index in with Wiki > Refresh index.
  def index_in_background
    Thread.new do
      attempts = 0
      begin
        @wiki.refresh_index!
        puts "wiki-bbs: indexed #{@wiki.pages.size} pages from #{@wiki.base_url}"
      rescue StandardError => e
        attempts += 1
        if attempts == 1 || (attempts % 30).zero?
          warn "wiki-bbs: could not load wiki index (#{e.class}: #{e.message}), " \
               "retrying every #{INDEX_RETRY}s"
        end
        sleep INDEX_RETRY
        retry
      end
    end
  end
end
