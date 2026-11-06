# frozen_string_literal: true

# The board itself, whatever terminal a caller has: its services wired to
# their stores, its doors, and what a call does across several services
# (logging on, the bulletin, the statistics). The modern ANSI interface
# (lib/ui/modern) and the Commodore 64 one (lib/ui/petscii) both work on one
# instance of it, so a C64 caller and an ANSI caller see the same nodes and
# the same wall. What callers write each other and the sysops lives on the
# network's Central (ttg-common TTG::Wall and TTG::Feedback, on TTG Gate
# BBS); the posts, oneliners and letters to the sysop of before are handed
# over to it once (#export).
class TeletypeBBS
  include Rubbs::Common::Board::Domain

  STARTED_AT    = Time.now
  CONTENT_DIR   = File.expand_path('../content', __dir__)
  BULLETINS_DIR = File.join(CONTENT_DIR, 'bulletins')
  DOOR_NAMES    = TeletypeDoors::NAMES

  path :db, 'data/teletype.sqlite3'
  database :db, MIGRATIONS
  setting :ftp_host, 'ftp.teletypegames.org'

  # What the callers make here: the nodes, the calls, the people.
  # Each service that keeps something opens the database first (#store),
  # so its models are bound however the board is started.
  service(:online)       { OnlineService.new(OnlineUsersRepository.new) }
  service(:last_callers) { store && LastCallersService.new }
  service(:profile)      { store && ProfileService.new }
  service(:members)      { store && MemberService.new(directory: -> { directory }) }
  service(:trivia)       { store && TriviaScoreModel }
  service(:bulletins)    { BulletinRepository.new(BULLETINS_DIR) }

  # What comes from elsewhere: the wall and the feedback on the network's
  # Central, the catalog, the site, Gitea, the FTP server, and the content
  # files.
  service(:wall)       { WallService.new }
  service(:feedback)   { FeedbackCounter.new }
  service(:games)      { GamesService.new(CatalogRepository.new) }
  service(:site)       { SiteService.new(SiteRepository.new) }
  service(:dev_log)    { DevLogService.new(GiteaRepository.new) }
  service(:warp_sizes) { WarpSizes.new(FtpRepository.new(ftp_host)) }
  service(:network)    { NetworkService.new(NetworkRepository.new(File.join(CONTENT_DIR, 'network.yml'))) }
  service(:voting) do
    store && VotingService.new(path: File.join(CONTENT_DIR, 'polls.yml'), games: games, doors: DOOR_NAMES)
  end

  # The board's own characters and what the desktop draws from.
  service(:master)     { TtgMaster.new(games: games, site: site, client: llm) }
  service(:c64_master) { TtgMaster.new(games: games, site: site, client: llm, **TtgMaster::C64) }
  service(:taglines)   { TaglineService.new(site) }
  service(:scene) do
    SceneService.new(
      online:       online,
      wall:         wall,
      feedback:     feedback,
      last_callers: last_callers,
      site:         site,
      door_titles:  DOOR_NAMES
    )
  end

  # The posts, oneliners and letters to the sysop of before, handed over to
  # the network's Central once, tried again until it takes them.
  background('export', max_retry: 3600) { export }

  # Hands over to the network's wall and feedback what is left of before
  # (ExportService); raises when the Central does not take it. Returns the
  # counts, <tt>{ wall:, feedback: }</tt>.
  def export
    store
    ExportService.new.call
  end

  def doors
    @doors ||= TeletypeDoors.build(games: games, sizes: warp_sizes, site: site, scores: trivia, llm: llm)
  end

  # The model of the BBS's own characters (Characters.client):
  # TELETYPE_BBS_LLM_URL, _MODEL and _API_KEY, each one unset or empty
  # falling back to SERMO's (SERMO_LLM_*), the same service and key.
  def self.llm(env)
    setting = lambda do |name|
      own = env["TELETYPE_BBS_LLM_#{name}"].to_s
      own.empty? ? env.fetch("SERMO_LLM_#{name}", nil) : own
    end
    Characters.client(url: setting.call('URL'), model: setting.call('MODEL'), api_key: setting.call('API_KEY'))
  end

  def llm = @llm ||= TeletypeBBS.llm(ENV)

  # The accounts of the network (a Rubbs::Common::Auth::Directory or Remote, from
  # the board's +auth+), nil when the board has none.
  def directory = Rubbs.config.auth&.directory

  # Whether +identity+ (a Rubbs::Common::Auth::Identity) is a signed-in sysop.
  def sysop?(identity) = identity.signed_in? && identity.role?(:sysop)

  # ── a call ────────────────────────────────────────────────────────────

  # The caller of +identity+ (a Rubbs::Common::Auth::Identity) is on the board: a
  # member when signed in, a node and a place among the last callers when
  # +listed+ (a scanner looks around unlisted).
  def start_call(session_id, identity, listed:)
    name = identity.name || MemberService::ANONYMOUS
    members.remember(identity)
    return unless listed

    online.add(session_id, name, sysop: sysop?(identity))
    last_callers.start(name, session_id)
  end

  def end_call(session_id)
    online.remove(session_id)
    last_callers.finish(session_id)
  end

  # The node of +session_id+ is behind +door+ (a Rubbs::Common::Call::Door) now: the games
  # room's lamps and the Door Lobby count it.
  def enter_door(session_id, door, suffix = nil)
    online.activity(session_id, ["Door: #{door.label.delete('&')}", suffix].compact.join(' '))
  end

  # The welcome bulletin's news: the board in numbers, what is coming up,
  # who called last and the newest notes of the wall.
  def bulletin(name, registered:)
    {
      username:       name || MemberService::ANONYMOUS,
      registered:     registered,
      online_count:   online.count,
      recent_callers: last_callers.recent(3),
      events:         site.upcoming_events(2),
      wall:           wall.recent(5)
    }
  end

  # ── the users ─────────────────────────────────────────────────────────

  # [name, stats, location, online] of every member, most calls first.
  def user_rows
    stats = last_callers.all_stats
    rows = members.names.map do |name|
      [name, stats[Rubbs::Common::Auth::Names.key(name)], profile.find(name)&.location, online.online?(name)]
    end
    rows.sort_by { |_, st, _, _| -(st&.calls || 0) }
  end

  def my_stats(name, registered:, session_id:, caller_number:)
    {
      name:          name,
      registered:    registered,
      stats:         last_callers.user_stats(name),
      node:          online.node(session_id),
      caller_number: caller_number || last_callers.caller_number,
      ballots:       voting.polls.count { |p| voting.ballot(p, name) },
      member_since:  members.created_at(name)
    }
  end

  # The best of the board: [[name, number], ...] lists, eight each; the
  # wall's are the names with the most of its newest notes.
  def hall_of_fame
    {
      callers: last_callers.top_callers(8),
      wall:    wall.top_writers(8),
      trivia:  trivia.best(8).map { |score| [score.username, score.points] }
    }
  end

  private

  # The board's database (a Sequel::Database): opening it binds the models.
  def store = databases[:main]
end
