# frozen_string_literal: true

# The board itself, whatever terminal a caller has: its services wired to
# their stores, its doors, and what a call does across several services
# (logging on, posting, mail, paging the sysop, the statistics). The modern
# ANSI interface (lib/ui/modern) and the Commodore 64 one (lib/ui/petscii) both
# work on one instance of it, so a C64 caller and an ANSI caller see the same
# nodes, boards, mail and chat.
class TeletypeBBS
  STARTED_AT    = Time.now
  SYSOPS        = ENV.fetch('TELETYPE_BBS_SYSOPS', '').split(',').map { |name| name.strip.downcase }.reject(&:empty?)
  CONTENT_DIR   = File.expand_path('../content', __dir__)
  BULLETINS_DIR = File.join(CONTENT_DIR, 'bulletins')
  LOGON_ART     = ENV.fetch('TELETYPE_BBS_LOGON_ART', File.join(CONTENT_DIR, 'logon.ans'))
  DESKTOP_ART   = ENV.fetch('TELETYPE_BBS_DESKTOP_ART', 'data/art/teletype.ansi')
  NETWORK       = [
    ['Teletype BBS',   'teletypegames.org:2323', 'this board: messages, chat, news, catalog'],
    ['Impostor BBS',   'teletypegames.org:2324', 'post-game terminal of Definitely not an Impostor'],
    ['TTG Wiki BBS',   'teletypegames.org:2325', 'the whole wiki in a two-pane browser'],
    ['Alexandria BBS', 'teletypegames.org:2326', 'Wikipedia on a telnet line'],
    ['Feedia BBS',     'teletypegames.org:2327', 'an RSS reader: the news as text'],
    ['TTG Blog BBS',   'teletypegames.org:2328', 'the Teletype Games blog'],
    ['WarpEngine BBS', 'teletypegames.org:2329', 'the file area: C64 and Plus/4 titles'],
    ['Scriptorium BBS', 'teletypegames.org:2330', 'Project Gutenberg books, a chapter at a time'],
    ['Commodex BBS',   'teletypegames.org:2331', 'the C64 game compendium, with cheats and tips'],
    ['Pixelia BBS',    'teletypegames.org:2332', 'ANSI and PETSCII art and a shared canvas'],
    ['TTG Gate BBS',   'teletypegames.org:2399', 'one port for all of these: a dialing menu']
  ].freeze
  DOOR_NAMES    = ['SERMO', 'Commodore 64', 'Commodore Plus/4', 'Chat of Ra', 'TTG Trivia'].freeze
  WIKI_SECTIONS = {
    platforms: { prefix: '/platforms', title: 'Platform Guides' },
    engines:   { prefix: '/engines',   title: 'Engines' },
    dos:       { prefix: '/dos',       title: 'DOS Corner' }
  }.freeze

  # +cols+: the narrowest screen the program draws for; +petscii+: the same door
  # drawn for 40 columns, when the program itself needs more. +tag+ is a few
  # words for the C64's list, +hint+ the line of the modern statusbar, +about+
  # the Door Lobby's paragraph.
  Door = Struct.new(:name, :program, :label, :cols, :petscii, :tag, :hint, :about, keyword_init: true) do
    def title = label.delete('&')
    def c64? = cols <= 40 || !petscii.nil?
  end

  attr_reader :online, :boards, :wiki, :games, :chat, :irc, :last_callers, :profile, :accounts, :site,
              :discord, :oneliners, :files, :dev_log, :art, :master, :mail, :voting, :file_areas, :trivia,
              :taglines, :c64_master

  def initialize
    @online       = OnlineService.new(OnlineUsersRepository.new)
    @boards       = BoardService.new(BoardRepository.new(
                      ENV.fetch('TELETYPE_BBS_BOARDS_PATH', 'data/boards'),
                      legacy_path: ENV.fetch('TELETYPE_BBS_MESSAGES_PATH', 'data/messages.dat')),
                      last_read: LastReadRepository.new(ENV.fetch('TELETYPE_BBS_LAST_READ_PATH', 'data/last_read.csv')))
    @wiki         = WikiService.new(WikiRepository.new)
    @games        = GamesService.new(CatalogRepository.new)
    @chat         = ChatService.new
    @irc          = IrcRelay.new(server:   ENV.fetch('TELETYPE_BBS_IRC_SERVER', 'irc.libera.chat'),
                                 port:     ENV.fetch('TELETYPE_BBS_IRC_PORT', '6697'),
                                 channel:  ENV.fetch('TELETYPE_BBS_IRC_CHANNEL', '#teletypegames'),
                                 nick:     ENV.fetch('TELETYPE_BBS_IRC_NICK', 'ttgbbs'),
                                 password: ENV.fetch('TELETYPE_BBS_IRC_PASSWORD', '')).start
    @last_callers = LastCallersService.new(LastCallersRepository.new(
                      ENV.fetch('TELETYPE_BBS_LAST_CALLERS_PATH', 'data/last_callers.csv')))
    @profile      = ProfileService.new(ProfileRepository.new(ENV.fetch('TELETYPE_BBS_PROFILE_PATH', 'data/profiles.csv')))
    @site         = SiteService.new(SiteRepository.new)
    @discord      = DiscordNotifier.new(ENV['TELETYPE_BBS_DISCORD_WEBHOOK'])
    @oneliners    = OnelinerService.new(OnelinerRepository.new(ENV.fetch('TELETYPE_BBS_ONELINERS_PATH', 'data/oneliners.csv')))
    @files        = FileLibraryService.new(FtpRepository.new(ENV.fetch('TELETYPE_BBS_FTP_HOST', 'ftp.teletypegames.org')))
    @dev_log      = DevLogService.new(GiteaRepository.new)
    @master       = TtgMaster.new(games: @games, site: @site)
    @c64_master   = TtgMaster.new(games: @games, site: @site, **TtgMaster::C64)
    @accounts     = AccountService.new(AccountRepository.new(ENV.fetch('TELETYPE_BBS_ACCOUNTS_PATH', 'data/accounts.csv')),
                                       reserved: SYSOPS)
    @mail         = MailService.new(MailRepository.new(ENV.fetch('TELETYPE_BBS_MAIL_PATH', 'data/mail.csv')),
                                    accounts: @accounts, sysops: SYSOPS)
    @voting       = VotingService.new(VoteRepository.new(ENV.fetch('TELETYPE_BBS_VOTES_PATH', 'data/votes.csv')),
                                      path: File.join(CONTENT_DIR, 'polls.yml'), games: @games, doors: DOOR_NAMES)
    @file_areas   = FileAreaService.new(games: @games, files: @files)
    @trivia       = Trivia::Scores.new(ENV.fetch('TELETYPE_BBS_TRIVIA_SCORES_PATH', 'data/trivia_scores.csv'))
    @art          = ArtService.new(DESKTOP_ART, profile: @profile)
    @taglines     = TaglineService.new(@site)
  end

  # The services by name, the way an Application's windows reach them.
  def services
    { online: @online, boards: @boards, wiki: @wiki, games: @games, chat: @chat, irc: @irc,
      last_callers: @last_callers, profile: @profile, accounts: @accounts, site: @site, discord: @discord,
      oneliners: @oneliners, files: @files, dev_log: @dev_log, art: @art, master: @master, mail: @mail,
      voting: @voting, file_areas: @file_areas, trivia: @trivia, bbs: self, uptime: STARTED_AT }
  end

  # The doors, in the order of the Doors menu; each label marks its hotkey with &.
  def doors
    @doors ||= [
      Door.new(name: :sermo, program: Sermo::OS, label: '&SERMO', cols: 80,
               tag: 'neumatronic machine',
               hint: 'SERMO: a dual machine of the Neumatronic universe; type a command, or just talk to it',
               about: 'The Margittai machine of the Neumatronic universe, running SERMO. Type its commands, ' \
                      'or talk to it: its Lapis-ACP answers. EXIT brings you back.'),
      Door.new(name: :c64, program: Commodore.os(Commodore::C64, games: @games, files: @files),
               label: '&Commodore 64', cols: 40, tag: 'c64 + our games',
               hint: 'A Commodore 64 at READY., with our C64 games on its disk: LOAD"$",8 lists them',
               about: 'A Commodore 64 at its READY. prompt, with a small BASIC V2. The disk holds our C64 games: ' \
                      'LOAD"$",8 and LIST show the directory, LOAD"NAME",8 and RUN show a game. EXIT returns.'),
      Door.new(name: :plus4, program: Commodore.os(Commodore::PLUS4, games: @games, files: @files),
               label: 'Commodore &Plus/4', cols: 40, tag: 'plus/4 + our games',
               hint: 'A Commodore Plus/4 with our Plus/4 games on its disk: DIRECTORY lists them',
               about: 'The grey screen of the Plus/4 and its BASIC 3.5 habits: DIRECTORY and DLOAD work, and ' \
                      'the disk holds our Plus/4 games. EXIT returns.'),
      Door.new(name: :ra, program: Ra.os(games: @games), label: 'Chat of &Ra', cols: 80,
               tag: 'talk to the sun god',
               hint: 'Talk to Ra in the pyramid of Blessing of Ra; solve three riddles for his blessing',
               about: 'You are the worker sealed in the pyramid of Blessing of Ra, and the sun god answers from ' \
                      'above. RIDDLE asks one of the pyramid\'s riddles; three solved earn his blessing.'),
      Door.new(name: :trivia, program: Trivia.door(games: @games, site: @site, scores: @trivia),
               label: '&TTG Trivia', cols: 80, tag: 'quiz, high scores',
               hint: 'Ten questions, 20 seconds each, A to D: quick answers and streaks score more',
               about: 'A door game of the old kind: ten questions about our games, the team and old computers, ' \
                      '20 seconds each. A quick answer is worth more, three in a row earn a bonus, and the best ' \
                      'ten games are in the Hall of Fame.')
    ]
  end

  def sysop?(name, authenticated) = authenticated == true && SYSOPS.include?(name.to_s.downcase)

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
  # the old boards (mail, message bases, voting booth, new files).
  def logon_summary(name, registered:, session_id:)
    sysop      = sysop?(name, registered)
    fresh      = Time.now - (FileAreaService::NEW_DAYS * 86_400)
    new_files  = @games.latest_releases(5).select { |g| g.released_at > fresh }.map { |g| "#{g.title} #{g.version}" }
    polls_open = name == AccountService::ANONYMOUS ? 0 : @voting.polls.count { |p| @voting.ballot(p, name).nil? }
    {
      name:          name,
      node:          @online.node(session_id)&.number,
      caller_number: @last_callers.caller_number,
      stats:         @last_callers.user_stats(name),
      registered:    registered,
      mail:          registered ? @mail.unread_count(name, sysop: sysop) : nil,
      new_scan:      registered ? @boards.new_scan(name) : nil,
      polls_open:    polls_open,
      new_files:     new_files,
      quote:         @taglines.of_the_day
    }
  end

  # The welcome bulletin's news: the board in numbers, the latest releases,
  # what is coming up, who called last and the wall.
  def bulletin(name, registered:)
    {
      username:       name || AccountService::ANONYMOUS,
      registered:     registered,
      online_count:   @online.count,
      total_messages: @boards.total_count,
      recent_callers: @last_callers.recent(3),
      releases:       @games.latest_releases(3),
      events:         @site.upcoming_events(2),
      oneliners:      @oneliners.recent(5)
    }
  end

  # ── messages ──────────────────────────────────────────────────────────

  # BoardService#post's answer; a post that went up is told on Discord too.
  def post_message(board, username, text, session_id:)
    result = @boards.post(board.id, username, text, session_id: session_id)
    @discord.board_post(board.title, username, text) if result == :ok
    result
  end

  # MailService#send_letter's answer; feedback for the sysop rings on Discord.
  def send_letter(from, to, subject, body, registered:, session_id:)
    result = @mail.send_letter(from, to, subject, body, registered: registered, session_id: session_id)
    @discord.feedback(from) if result == :ok && @mail.recipient(to) == MailService::SYSOP
    result
  end

  # The sysop's bell: the chat and Discord hear it. True when a sysop is on
  # line to answer.
  def page_sysop(name)
    online = @online.nodes.any? { |n| SYSOPS.include?(n.name.downcase) }
    @chat.broadcast('[PAGE]', "#{name} is paging the sysop!")
    @discord.page(name)
    online
  end

  def sysop_broadcast(name, text)
    @chat.broadcast("[SYSOP] #{name}", text)
    @discord.broadcast(name, text)
  end

  # ── the users ─────────────────────────────────────────────────────────

  # [name, stats, location, online] of every registered name, most calls first.
  def user_rows
    rows = @accounts.names.map do |name|
      [name, @last_callers.user_stats(name), @profile.find(name)&.fetch('location', nil), @online.online?(name)]
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
      posts:         @boards.top_posters(1000).find { |n, _| n.casecmp?(name) }&.last || 0,
      ballots:       @voting.polls.count { |p| @voting.ballot(p, name) },
      letters:       registered ? @mail.inbox(name, sysop: sysop).size : nil,
      member_since:  @accounts.created_at(name)
    }
  end

  # The best of the board: [[name, number], ...] lists, eight each.
  def hall_of_fame
    {
      downloads: @games.top_downloads(8).map { |g| [g.title, g.downloads] },
      callers:   @last_callers.top_callers(8),
      posters:   @boards.top_posters(8),
      trivia:    @trivia.best(8).map { |sc| [sc.username, sc.points.to_i] }
    }
  end
end
