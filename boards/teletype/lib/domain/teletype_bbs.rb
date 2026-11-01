# frozen_string_literal: true

# The board itself, whatever terminal a caller has: its services wired to
# their stores, its doors, and what a call does across several services
# (logging on, posting, mail, paging the sysop, the statistics). The modern
# ANSI interface (lib/ui/modern) and the Commodore 64 one (lib/ui/petscii) both
# work on one instance of it, so a C64 caller and an ANSI caller see the same
# nodes, boards, mail and chat. The only place that reads the environment
# (TELETYPE_BBS_*).
class TeletypeBBS
  STARTED_AT    = Time.now
  CONTENT_DIR   = File.expand_path('../content', __dir__)
  BULLETINS_DIR = File.join(CONTENT_DIR, 'bulletins')
  DOOR_NAMES    = TeletypeDoors::NAMES

  attr_reader :online, :boards, :games, :chat, :irc, :last_callers, :profile, :accounts, :site,
              :discord, :oneliners, :warp_sizes, :dev_log, :master, :mail, :voting, :trivia,
              :taglines, :c64_master, :scene, :network, :bulletins

  def initialize(env: ENV)
    @env    = env
    @sysops = setting('SYSOPS', '').split(',').map { |name| name.strip.downcase }.reject(&:empty?)
    @db     = Database.open(setting('DB', 'data/teletype.sqlite3'))
    open_community
    open_outside
    open_characters
  end

  # The services by name, the way an Application's windows reach them.
  def services
    { online: @online, boards: @boards, games: @games, chat: @chat, irc: @irc,
      last_callers: @last_callers, profile: @profile, accounts: @accounts, site: @site, discord: @discord,
      oneliners: @oneliners, dev_log: @dev_log, master: @master, mail: @mail, voting: @voting, trivia: @trivia,
      scene: @scene, network: @network, bulletins: @bulletins, bbs: self, uptime: STARTED_AT }
  end

  def doors
    @doors ||= TeletypeDoors.build(games: @games, sizes: @warp_sizes, site: @site, scores: @trivia)
  end

  def sysop?(name, authenticated) = authenticated == true && @sysops.include?(name.to_s.downcase)

  # ── a call ────────────────────────────────────────────────────────────

  # The caller is on the board: a node and a place among the last callers
  # when +listed+ (a scanner looks around unlisted), and the live chat.
  def start_call(session_id, name, listed:)
    if listed
      @online.add(session_id, name)
      @last_callers.start(name, session_id)
    end
    @chat.subscribe(session_id)
  end

  def end_call(session_id)
    @online.remove(session_id)
    @chat.unsubscribe(session_id)
    @irc.unsubscribe(session_id)
    @last_callers.finish(session_id)
  end

  # What the logon sequence tells a caller: who they are, then the scans of
  # the old boards (mail, message bases, voting booth).
  def logon_summary(name, registered:, session_id:)
    {
      name:          name,
      node:          @online.node(session_id)&.number,
      caller_number: @last_callers.caller_number,
      stats:         @last_callers.user_stats(name),
      registered:    registered,
      mail:          registered ? @mail.unread_count(name, sysop: sysop?(name, registered)) : nil,
      new_scan:      registered ? @boards.new_scan(name) : nil,
      polls_open:    polls_open(name),
      quote:         @taglines.of_the_day
    }
  end

  # The welcome bulletin's news: the board in numbers, the newest posts,
  # what is coming up, who called last and the wall.
  def bulletin(name, registered:)
    {
      username:       name || AccountService::ANONYMOUS,
      registered:     registered,
      online_count:   @online.count,
      total_messages: @boards.total_count,
      recent_callers: @last_callers.recent(3),
      posts:          @boards.latest(3),
      events:         @site.upcoming_events(2),
      oneliners:      @oneliners.recent(5)
    }
  end

  # ── messages ──────────────────────────────────────────────────────────

  # BoardService#post's answer; a post that went up is told on Discord too.
  def post_message(board, username, text, caller_key:)
    result = @boards.post(board.id, username, text, caller_key: caller_key)
    @discord.board_post(board.title, username, text) if result == :ok
    result
  end

  # MailService#send_letter's answer; feedback for the sysop rings on Discord.
  def send_letter(from, to, subject, body, registered:, caller_key:)
    result = @mail.send_letter(from, to, subject, body, registered: registered, caller_key: caller_key)
    @discord.feedback(from) if result == :ok && @mail.recipient(to) == MailService::SYSOP
    result
  end

  # The sysop's bell: the chat and Discord hear it. True when a sysop is on
  # line to answer.
  def page_sysop(name)
    online = @online.nodes.any? { |n| @sysops.include?(n.name.downcase) }
    @chat.broadcast('[PAGE]', "#{name} is paging the sysop!")
    @discord.page(name)
    online
  end

  # A line to every caller and to Discord, from a logged-on sysop only:
  # :ok, :forbidden or :empty.
  def sysop_broadcast(name, text, registered:)
    return :forbidden unless sysop?(name, registered)

    line = BBS::Text.clean(text, keep_newlines: false).strip
    return :empty if line.empty?

    @chat.broadcast("[SYSOP] #{name}", line)
    @discord.broadcast(name, line)
    :ok
  end

  # ── the users ─────────────────────────────────────────────────────────

  # [name, stats, location, online] of every registered name, most calls first.
  def user_rows
    stats = @last_callers.all_stats
    rows = @accounts.names.map do |name|
      [name, stats[Names.key(name)], @profile.find(name)&.fetch('location', nil), @online.online?(name)]
    end
    rows.sort_by { |_, st, _, _| -(st&.calls || 0) }
  end

  def my_stats(name, registered:, session_id:, caller_number:, sysop:)
    {
      name:          name,
      registered:    registered,
      stats:         @last_callers.user_stats(name),
      node:          @online.node(session_id),
      caller_number: caller_number || @last_callers.caller_number,
      posts:         @boards.posts_by(name),
      ballots:       @voting.polls.count { |p| @voting.ballot(p, name) },
      letters:       registered ? @mail.inbox(name, sysop: sysop).size : nil,
      member_since:  @accounts.created_at(name)
    }
  end

  # The best of the board: [[name, number], ...] lists, eight each.
  def hall_of_fame
    {
      callers: @last_callers.top_callers(8),
      posters: @boards.top_posters(8),
      trivia:  @trivia.best(8).map { |score| [score.username, score.points] }
    }
  end

  private

  def setting(name, default) = @env.fetch("TELETYPE_BBS_#{name}", default)

  def polls_open(name)
    return 0 if name == AccountService::ANONYMOUS

    @voting.polls.count { |poll| @voting.ballot(poll, name).nil? }
  end

  # What the callers make: boards, mail, the wall, the chat, the people.
  def open_community
    @online       = OnlineService.new(OnlineUsersRepository.new)
    @boards       = BoardService.new(BoardRepository.new(@db), last_read: LastReadRepository.new(@db))
    @chat         = ChatService.new
    @last_callers = LastCallersService.new(LastCallersRepository.new(@db))
    @profile      = ProfileService.new(ProfileRepository.new(@db))
    @oneliners    = OnelinerService.new(OnelinerRepository.new(@db))
    @accounts     = AccountService.new(AccountRepository.new(@db), reserved: @sysops)
    @mail         = MailService.new(MailRepository.new(@db), accounts: @accounts, sysops: @sysops)
    @trivia       = TriviaScoreRepository.new(@db)
    @bulletins    = BulletinRepository.new(BULLETINS_DIR)
  end

  # What comes from elsewhere: the catalog, the site, Gitea, the FTP
  # server, Discord, IRC, and the content files.
  def open_outside
    @games      = GamesService.new(CatalogRepository.new)
    @site       = SiteService.new(SiteRepository.new)
    @dev_log    = DevLogService.new(GiteaRepository.new)
    @warp_sizes = WarpSizes.new(FtpRepository.new(setting('FTP_HOST', 'ftp.teletypegames.org')))
    @discord    = DiscordNotifier.new(setting('DISCORD_WEBHOOK', nil))
    @irc        = open_irc
    @network    = NetworkService.new(NetworkRepository.new(File.join(CONTENT_DIR, 'network.yml')))
    @voting     = VotingService.new(VoteRepository.new(@db), path: File.join(CONTENT_DIR, 'polls.yml'),
                                                             games: @games, doors: DOOR_NAMES)
  end

  def open_irc
    IrcRelay.new(server: setting('IRC_SERVER', 'irc.libera.chat'), port: setting('IRC_PORT', '6697'),
                 channel: setting('IRC_CHANNEL', '#teletypegames'), nick: setting('IRC_NICK', 'ttgbbs'),
                 password: setting('IRC_PASSWORD', '')).start
  end

  def open_characters
    @master     = TtgMaster.new(games: @games, site: @site)
    @c64_master = TtgMaster.new(games: @games, site: @site, **TtgMaster::C64)
    @taglines   = TaglineService.new(@site)
    @scene      = SceneService.new(online: @online, chat: @chat, boards: @boards, mail: @mail,
                                   last_callers: @last_callers, site: @site, oneliners: @oneliners,
                                   door_titles: DOOR_NAMES)
  end
end
