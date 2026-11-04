# frozen_string_literal: true

# The board itself, whatever terminal a caller has: its services wired to
# their stores, its doors, and what a call does across several services
# (logging on, posting, mail, paging the sysop, the statistics). The modern
# ANSI interface (lib/ui/modern) and the Commodore 64 one (lib/ui/petscii) both
# work on one instance of it, so a C64 caller and an ANSI caller see the same
# nodes, boards, mail and chat.
class TeletypeBBS
  include BBS::Domain

  STARTED_AT    = Time.now
  CONTENT_DIR   = File.expand_path('../content', __dir__)
  BULLETINS_DIR = File.join(CONTENT_DIR, 'bulletins')
  DOOR_NAMES    = TeletypeDoors::NAMES

  path :db, 'data/teletype.sqlite3'
  database :db, MIGRATIONS
  setting :ftp_host, 'ftp.teletypegames.org'
  setting :discord_webhook, ''
  setting :irc_server, 'irc.libera.chat', blank: true
  setting :irc_port, 6697
  setting :irc_channel, '#teletypegames'
  setting :irc_nick, 'ttgbbs'
  setting :irc_password, ''

  # What the callers make: boards, mail, the wall, the chat, the people.
  # Each service that keeps something opens the database first (#store),
  # so its models are bound however the board is started.
  service(:online)       { OnlineService.new(OnlineUsersRepository.new) }
  service(:boards)       { BoardService.new(store: store) }
  service(:chat)         { ChatService.new }
  service(:last_callers) { store && LastCallersService.new }
  service(:profile)      { store && ProfileService.new }
  service(:oneliners)    { OnelinerService.new(store: store) }
  service(:members)      { store && MemberService.new(directory: -> { directory }) }
  service(:mail)      { MailService.new(members: members, store: store) }
  service(:trivia)    { store && TriviaScoreModel }
  service(:bulletins) { BulletinRepository.new(BULLETINS_DIR) }

  # What comes from elsewhere: the catalog, the site, Gitea, the FTP
  # server, Discord, IRC, and the content files.
  service(:games)      { GamesService.new(CatalogRepository.new) }
  service(:site)       { SiteService.new(SiteRepository.new) }
  service(:dev_log)    { DevLogService.new(GiteaRepository.new) }
  service(:warp_sizes) { WarpSizes.new(FtpRepository.new(ftp_host)) }
  service(:discord)    { DiscordNotifier.new(discord_webhook) }
  service(:irc) do
    IrcRelay.new(server: irc_server, port: irc_port, channel: irc_channel, nick: irc_nick, password: irc_password)
  end
  service(:network) { NetworkService.new(NetworkRepository.new(File.join(CONTENT_DIR, 'network.yml'))) }
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
      chat:         chat,
      boards:       boards,
      mail:         mail,
      last_callers: last_callers,
      site:         site,
      oneliners:    oneliners,
      door_titles:  DOOR_NAMES
    )
  end

  # Every service made, and the IRC channel joined.
  def start
    super
    irc.start
    self
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

  # The accounts of the network (a BBS::Auth::Directory or Remote, from
  # the board's +auth+), nil when the board has none.
  def directory = BBS.config.auth&.directory

  # Whether +identity+ (a BBS::Auth::Identity) is a signed-in sysop.
  def sysop?(identity) = identity.signed_in? && identity.role?(:sysop)

  # ── a call ────────────────────────────────────────────────────────────

  # The caller of +identity+ (a BBS::Auth::Identity) is on the board: a
  # member when signed in, a node and a place among the last callers when
  # +listed+ (a scanner looks around unlisted), and the live chat.
  def start_call(session_id, identity, listed:)
    name = identity.name || MemberService::ANONYMOUS
    members.remember(identity)
    if listed
      online.add(session_id, name, sysop: sysop?(identity))
      last_callers.start(name, session_id)
    end
    chat.subscribe(session_id)
  end

  def end_call(session_id)
    online.remove(session_id)
    chat.unsubscribe(session_id)
    irc.unsubscribe(session_id)
    last_callers.finish(session_id)
  end

  # The node of +session_id+ is behind +door+ (a BBS::Door) now: the games
  # room's lamps and the Door Lobby count it.
  def enter_door(session_id, door, suffix = nil)
    online.activity(session_id, ["Door: #{door.label.delete('&')}", suffix].compact.join(' '))
  end

  # What the logon sequence tells a caller: who they are, then the scans of
  # the old boards (mail, message bases, voting booth).
  def logon_summary(name, registered:, sysop:, session_id:)
    {
      name:          name,
      node:          online.node(session_id)&.number,
      caller_number: last_callers.caller_number,
      stats:         last_callers.user_stats(name),
      registered:    registered,
      mail:          registered ? mail.unread_count(name, sysop: sysop) : nil,
      new_scan:      registered ? boards.new_scan(name) : nil,
      polls_open:    polls_open(name),
      quote:         taglines.of_the_day
    }
  end

  # The welcome bulletin's news: the board in numbers, the newest posts,
  # what is coming up, who called last and the wall.
  def bulletin(name, registered:)
    {
      username:       name || MemberService::ANONYMOUS,
      registered:     registered,
      online_count:   online.count,
      total_messages: boards.total_count,
      recent_callers: last_callers.recent(3),
      posts:          boards.latest(3),
      events:         site.upcoming_events(2),
      oneliners:      oneliners.recent(5)
    }
  end

  # ── messages ──────────────────────────────────────────────────────────

  # BoardService#post's answer; a post that went up is told on Discord too.
  def post_message(board, username, text, caller_key:)
    result = boards.post(board.id, username, text, caller_key: caller_key)
    discord.board_post(board.title, username, text) if result == :ok
    result
  end

  # MailService#send_letter's answer; feedback for the sysop rings on Discord.
  def send_letter(from, to, subject, body, registered:, caller_key:)
    result = mail.send_letter(from, to, subject, body, registered: registered, caller_key: caller_key)
    discord.feedback(from) if result == :ok && mail.recipient(to) == MailService::SYSOP
    result
  end

  # The sysop's bell: the chat and Discord hear it. True when a sysop is on
  # line to answer.
  def page_sysop(name)
    on_line = online.nodes.any?(&:sysop)
    chat.broadcast('[PAGE]', "#{name} is paging the sysop!")
    discord.page(name)
    on_line
  end

  # A line to every caller and to Discord, from a signed-in sysop only
  # (+sysop+): :ok, :forbidden or :empty.
  def sysop_broadcast(name, text, sysop:)
    return :forbidden unless sysop

    line = BBS::Text.line(text)
    return :empty if line.empty?

    chat.broadcast("[SYSOP] #{name}", line)
    discord.broadcast(name, line)
    :ok
  end

  # ── the users ─────────────────────────────────────────────────────────

  # [name, stats, location, online] of every member, most calls first.
  def user_rows
    stats = last_callers.all_stats
    rows = members.names.map do |name|
      [name, stats[BBS::Auth::Names.key(name)], profile.find(name)&.location, online.online?(name)]
    end
    rows.sort_by { |_, st, _, _| -(st&.calls || 0) }
  end

  def my_stats(name, registered:, session_id:, caller_number:, sysop:)
    {
      name:          name,
      registered:    registered,
      stats:         last_callers.user_stats(name),
      node:          online.node(session_id),
      caller_number: caller_number || last_callers.caller_number,
      posts:         boards.posts_by(name),
      ballots:       voting.polls.count { |p| voting.ballot(p, name) },
      letters:       registered ? mail.inbox(name, sysop: sysop).size : nil,
      member_since:  members.created_at(name)
    }
  end

  # The best of the board: [[name, number], ...] lists, eight each.
  def hall_of_fame
    {
      callers: last_callers.top_callers(8),
      posters: boards.top_posters(8),
      trivia:  trivia.best(8).map { |score| [score.username, score.points] }
    }
  end

  private

  # The board's database (a Sequel::Database): the rate limits are kept in
  # it, and opening it binds the models.
  def store = databases[:main]

  def polls_open(name)
    return 0 if name == MemberService::ANONYMOUS

    voting.polls.count { |poll| voting.ballot(poll, name).nil? }
  end
end
