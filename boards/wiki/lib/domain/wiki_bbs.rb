# frozen_string_literal: true

# The board itself, whatever terminal a caller has: the wiki's API
# (WIKI_BBS_URL) wired to the shared page index, the supervisor lock
# (WIKI_BBS_SUPERVISOR_PASSWORD) and the idle limit (WIKI_BBS_IDLE).
#
# The page index loads at boot, in the background, and keeps trying until
# the wiki answers: a stack deploy recreates grav together with this
# container, so the wiki is often not up yet when the board starts.
class WikiBBS
  include BBS::Domain

  INDEX_RETRY     = 10 # seconds, doubled after each failure up to INDEX_RETRY_MAX
  INDEX_RETRY_MAX = 300

  setting :url, 'http://localhost:9120'
  setting :supervisor_password, ''
  setting :idle_seconds, 900, env: 'IDLE'

  service(:wiki)       { WikiService.new(WikiRepository.new(url, token: supervisor_password)) }
  service(:supervisor) { SupervisorService.new(supervisor_password) }

  background('index', retry_after: INDEX_RETRY, max_retry: INDEX_RETRY_MAX) do
    wiki.refresh_index!
    BBS.log('index', "#{wiki.pages.size} pages from #{wiki.base_url}")
  end
end
