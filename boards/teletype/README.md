# Teletype BBS Server

Telnet-accessible Synchronet-style community BBS server built on the
[rubbs](https://git.teletypegames.org/engines/rubbs) gem. It keeps the habits of the
old boards: a modem handshake and a logon matrix, caller numbers, a logon
sequence that scans your mail and the message bases, nodes, private mail,
feedback to the sysop and a page bell, a voting booth, file areas with
FILE_ID.DIZ, numbered bulletins, a hall of fame, a door game, and NO CARRIER at
the end. Around them the work of Teletype Games: news from teletypegames.org,
the team's dev log from Gitea, the game catalog with its release history, the
FTP server with ZMODEM downloads, the wiki guides and tech how-tos, an ANSI
gallery, the TTG Master who answers callers' questions (F1), and doors: SERMO,
a Commodore 64, a Plus/4, the Impostor terminal, Chat of Ra, TTG Trivia, and
telnet gateways to Alexandria BBS, Feedia and TTGBLOG.

The board has two faces on one port: the **modern** one for ANSI terminals
(windows, menus, mouse) and a **Commodore 64** one in PETSCII, 40×25, with
single-key menus. Both work on the same board: a C64 caller and a PC caller
share the nodes, the boards, the mail and the live chat.

## Running

**Docker Compose:**

```bash
docker compose up --build
```

**Directly (Ruby 3.x):**

```bash
bundle install
ruby bbs.rb
```

Connect:

```bash
telnet localhost 2323
```

Compose starts one container, `teletype-bbs`. The model behind SERMO's
Lapis-ACP, Qwen3.5 0.8B, runs in the server's shared model service,
[infra/llm](https://git.teletypegames.org/infra/llm), reached as
`http://llm:8080` on the `interstack` network; its key, one of that stack's
`LLM_API_KEYS`, is `SERMO_LLM_API_KEY` in `.env`. Until the model is up, or
without it, SERMO answers with canned replies.

`docker-compose.dev.yaml` keeps the model next to the BBS: a `teletype-bbs-acp`
container with llama.cpp's `llama-server` and the same model, no key, no
`interstack`.

## Configuration

Copy `env-example` to `.env`:

| Variable | Default | Description |
|---|---|---|
| `BBS_PORT` | `2323` | TCP port to listen on |
| `BBS_SYSOPS` | empty | Comma-separated sysop names. Sysop rights need the name's password; these accounts are created only with `bin/account` |
| `BBS_DISCORD_WEBHOOK` | empty | Discord webhook for new board posts and sysop broadcasts; empty = off |
| `BBS_IRC_SERVER` | `irc.libera.chat` | IRC server of the read-only channel window (TLS); empty = off |
| `BBS_IRC_PORT` | `6697` | Its TLS port |
| `BBS_IRC_CHANNEL` | `#teletypegames` | The channel the board listens on |
| `BBS_IRC_NICK` | `ttgbbs` | The board's nick there; taken at login → `ttgbbs_` |
| `BBS_IRC_PASSWORD` | empty | NickServ password of the nick (SASL PLAIN); empty = no login |
| `ACCOUNTS_PATH` | `data/accounts.csv` | Registered names with salted PBKDF2-SHA256 password hashes |
| `BOARDS_PATH` | `data/boards` | Directory of per-board CSV files |
| `MESSAGES_PATH` | `data/messages.dat` | Legacy single-board file; auto-migrated into the General board on first run |
| `LAST_CALLERS_PATH` | `data/last_callers.csv` | Finished calls (see *Last callers* below) |
| `PROFILE_PATH` | `data/profiles.csv` | User profile CSV (with the favourite desktop art) |
| `ONELINERS_PATH` | `data/oneliners.csv` | The oneliners wall |
| `IMPOSTOR_SESSIONS_PATH` | `data/impostor_sessions.csv` | Codes, feedback and addresses left in the Impostor door |
| `MAIL_PATH` | `data/mail.csv` | Private mail and the feedback to the sysop (mode 600) |
| `LAST_READ_PATH` | `data/last_read.csv` | How far each registered name has read each board (the new-message scan) |
| `VOTES_PATH` | `data/votes.csv` | The ballots of the Voting Booth, a log: a name's later ballot wins |
| `TRIVIA_SCORES_PATH` | `data/trivia_scores.csv` | Every finished TTG Trivia game, for its hall of fame |
| `BBS_GATEWAY_HOST` | `host.docker.internal` | Where the Alexandria (:2326), Feedia (:2327) and TTGBLOG (:2328) gateway doors connect; compose maps it to the host |
| `BBS_LOGON_ART` | `lib/content/logon.ans` | The art of the logon matrix, above the name prompt |
| `BBS_FTP_HOST` | `ftp.teletypegames.org` | The FTP server of the FTP Browser (anonymous, passive) |
| `BBS_ARCHIVE_URL` | `http://archive.teletypegames.org` | The FTP tree on plain HTTP: the C64 face gives these addresses, as a C64 cannot take a ZMODEM download or speak TLS |
| `BBS_FTP_DOWNLOAD_MAX` | `16777216` | The largest file (bytes) the FTP Browser sends by ZMODEM; a bigger one only gets its FTP (and for WARP, HTTPS) address |
| `SERMO_LLM_URL` | set by compose | SERMO's model, `http://llm:8080`; empty = canned replies only |
| `SERMO_LLM_MODEL` | set by compose | the model's name in infra/llm, `qwen3.5-0.8b` |
| `SERMO_LLM_API_KEY` | empty | SERMO's key to infra/llm, one of its `LLM_API_KEYS`; without it SERMO gets a 401 and answers with canned replies |
| `BBS_LLM_URL`, `BBS_LLM_MODEL`, `BBS_LLM_API_KEY` | SERMO's | The model of the BBS's own characters (Ra, the TTG Master); each one unset or empty falls back to its `SERMO_LLM_*` |
| `BBS_DESKTOP_ART` | `data/art/teletype.ansi` | Path to a single ANSI art file (`.ans`, `.ansi`, `.asc`, `.nfo`, `.txt`) **or** a directory containing them. Its folder is the ANSI Gallery. A file is every caller's desktop; with a directory a random one is shown per session. A registered caller's favourite wins over both. CP437 / SAUCE-aware |

## Interface

A call starts with one question, before the name: which terminal is calling.
The board guesses first: it waits up to 1.5 seconds for the telnet answers, and
a terminal that reports a window wider than 40 columns is a modern one; 40
columns, or no answer at all (a C64 behind a WiFi modem speaks plain TCP), is
taken for a Commodore. The question is rubbs' `BBS::Terminal`, plain ASCII in
capitals, readable on both: `1` (or `M`) picks the modern face (ANSI/xterm, 256
colours), `2` (or `C`) the C64 (PETSCII), and RETURN takes the pick, or the
guess when nothing is picked.
Whatever the caller types before the question is dropped (a bot's `root`), and
mouse reporting is switched on only after the choice, so the C64 never gets
its escape sequence.

### The modern face

A call starts the old way: the modem dials and connects (`CONNECT
38400/ARQ/V42BIS`), the logon matrix shows the TTG art with the caller number
and the nodes in use, and asks for a name (and a registered name's password).
Then the logon sequence: *Welcome back*, your caller number, your calls, and
the scans — new letters in your mailbox, new messages on the boards since your
last read, open polls in the voting booth, new files this month — and the quote
of the day (a member's motto). ENTER opens the full-screen Synchronet-style
shell with the Welcome window on top: the latest releases, what is coming up,
the last callers and the oneliners. Continue (or Esc) closes it, **Ask the
TTG Master** opens the Master; File > Welcome opens it again. File > Log off
(Alt-X) ends the call with the logoff screen: the call's length, a tagline,
`+++`, `ATH0`, `NO CARRIER`.

The statusbar shows the node, the clock and the time on line on the right. The desktop
has a **F1 ▸ Lost? Ask the TTG Master** button in its bottom right corner. It does not come back when a caller returns from a
door.

#### Keys

| Key | Action |
|---|---|
| `Alt+letter` | Open the matching top menu |
| `F10` | Open the leftmost menu |
| `Tab` / `Shift-Tab` | Move focus inside a window |
| `Enter` | Activate the focused button / submit input |
| letter / `Alt+letter` | Press the window button with that hotkey (Alt in a text field) |
| `Esc` | Close the top window / menu |
| `F5` / `Alt-Enter` | Full screen and back, for the windows with much to read (also `[↑]` / `[↕]` on the title bar, or a double click on it) |
| `F6` / `Shift-F6` | Bring the next / previous window to the front; a click on a window does it too |
| `Alt-1` … `Alt-9` | Bring the window with that number (on the right of its top frame) to the front |
| `Ctrl-F5` | Move the window with the arrows, size it with Shift+arrows (Tab switches), Enter ends (F6 too while it is the only window); with the mouse, drag the title bar or the `┘` corner |
| `F1` | Ask the TTG Master |
| `F2` | Message Boards |
| `F3` | Quick post |
| `F4` | Chat |
| `F7` | Mail |
| `Alt-X` | Log off |

#### Menus

| Menu | Items |
|---|---|
| **TTG Master** | Ask a question… · What is new? · What is coming up? · Where do I start? · How do I download files? · Which doors are there? |
| **File** | Welcome · Bulletins… · News · Dev Log · System Info · BBS Network (our other BBSes and bbsweb) · Log off |
| **Messages** | Boards… · New Post… · Mail… · Oneliners · Live Chat · IRC #teletypegames · Feedback to the Sysop… · Page the Sysop |
| **Content** | File Areas · FTP Browser · Game Catalog · Platform Guides · Engines · DOS Corner · Tech HowTos · ANSI Gallery |
| **Users** | Who is Online · Last Callers · User Listing · Your Stats · Hall of Fame · Voting Booth · Team · Profile… · Register… · Language EN/HU |
| **Doors** | SERMO · Commodore 64 · Commodore Plus/4 · Impostor · Chat of Ra · TTG Trivia · Alexandria · Feedia · TTGBLOG |
| **Sysop** | Console (logged-in sysops only) |
| **Help** | Ask the TTG Master · New to BBSes? · About · Keys |

#### Features

- **Multi-board messaging** — separate sub-boards (General / Tech / Off-Topic / Sysop), each in its own CSV file under `data/boards/`.
- **Multi-line composer** — `TextArea` widget, up to 1000 chars per post, one post per 30 seconds from a call.
- **Oneliners** — a wall of one-line messages (64 characters, a name needed, not Anonymous); the last five are in the Welcome window.
- **Live chat** — broadcast hub, 1 Hz polling, history replay on join; at most two lines a second from one caller, and a caller who does not read keeps the last 200 lines.
- **IRC #teletypegames** — a read-only window on the channel at Libera.Chat: one connection for the whole board under the nick `ttgbbs` (TLS, reconnects with a growing pause), the last 200 lines replayed, the member count and the topic; the window tells how to join, and the input line only repeats it. mIRC formatting and control characters are stripped. The board never speaks on the channel.
- **Bulletin on login** — the latest releases and upcoming events from teletypegames.org, message count, last callers and the last oneliners.
- **Logon sequence** — caller numbers (every logged call before this one, plus one), a name's calls, first and last call and time on line, and the scans: unread mail, the new messages of each board since the name last opened it (registered names; `LAST_READ_PATH`), polls without the caller's vote, releases of the last 30 days. The quote of the day is a member's motto, the same for everyone until midnight; the logoff screen picks a tagline (`lib/content/taglines.yml`) or a motto.
- **Nodes** — every caller gets the lowest free node number. Users > Who is Online lists the nodes with the name, what the caller is doing (the title of the top window, *At the main menu*, or the door) and the time on line.
- **Mail** (Messages > Mail…, F7) — private letters between registered names: Write, Reply, Delete; `•` marks the unread ones. **Feedback to the Sysop…** is a letter to `Sysop`, which anyone with a name may write and every sysop reads in their own mailbox; the Discord feed gets only that a letter came, never what it says. A letter arriving during a call rings the bell and says so. One letter every 30 seconds from a call.
- **Page the Sysop** — once a call: the bell, a line in the live chat and on Discord; when no sysop is on line it offers to leave a letter.
- **Voting Booth** (Users) — the polls of `lib/content/polls.yml`; `options: catalog` fills one with the released games, `options: doors` with the doors. Results as bars; a name (not Anonymous) votes and can change its vote.
- **File Areas** (Content) — the catalog as the file areas of the old boards: one area per platform, a file per asset of each game's latest release (web builds as their `.html.zip`), sizes from the FTP server's WARP folder, the release's download count, `*` for the files of the last 30 days, and a FILE_ID.DIZ box from the game's card. **Enter** or **Download** sends the file by ZMODEM, like the FTP Browser.
- **Bulletins** (File > Bulletins…, Help > New to BBSes?) — numbered: the logon bulletin, About Teletype Games (the wiki's home page), the story so far (every release of every game by month), what is coming up, the board rules and New to BBSes? (`lib/content/bulletins/*.md`), and the BBS network.
- **Tech HowTos** (Content) — the how-tos of teletypegames.org/howtos (its RSS feed), each read from its wiki page.
- **Hall of Fame** (Users) — top lists with bars: the most downloaded games (the catalog's `totalDownloads`), the top callers, the top posters and the TTG Trivia high scores. **User Listing** has the registered names with their calls, last call and location; **Your Stats** the caller's own numbers.
- **Dev Log** — the public activity of every organisation on git.teletypegames.org (pushes with their commit messages, tags, releases, new repositories), newest first, read anonymously from the Gitea API, so private repositories never show.
- **News** — the latest releases with catalog links, upcoming events, and the wiki's `blog` posts once there are any (the same source as teletypegames.org/blog).
- **Game catalog** — every catalog entry (all pages of the API), sorted by platform; the **Platform** button cycles a platform filter. The card shows version, release date, status, license and downloads, the catalog link, the downloadable kinds, the release history and the external links.
- **FTP Browser** — an FTP client on the FTP server, from its root (`APPS`, `WARP`, `WIKI`): **Enter** opens a folder, `..` or **Up** goes back. A file shows its size, date, `ftp://` address (and for WARP its `https://teletypegames.org/file/…` mirror) and, for a text file under 64 KB (`.md`, `.txt`, `.ini`, `.lst`, `.bat`, `.nfo`, …), its contents. **Enter** or **Download** sends it to the caller's terminal by ZMODEM (rubbs' `BBS::Zmodem`): SyncTERM, NetRunner and Qodem start receiving by themselves, `rz` by hand, and bbsweb saves it as a browser download. Files over `BBS_FTP_DOWNLOAD_MAX` get only their addresses. Listings are cached for a minute; the last folder is kept for the call.
- **Wiki sections** — Platform Guides (`/platforms`), Engines (`/engines`) and the DOS Corner (`/dos`, with an FTP/DOSINST intro), read from the Grav JSON API; private pages are left out. Users > Language switches them to Hungarian.
- **Team** — the members of teletypegames.org with their mottos.
- **Doors** — full-line programs the BBS hands the telnet line to and takes it back from when they exit (rubbs' `BBS::Door`). **SERMO** ([sermo-bbs](https://git.teletypegames.org/bbs/sermo-bbs), pulled in as the `sermo` gem) is a dual machine running SERMO, from the Neumatronic universe: type a command, or just talk to it; `EXIT` returns to the BBS. Natural language goes to its Lapis-ACP, the Qwen3.5 0.8B model in the shared `infra/llm` service. See *Doors* below.
- **Telnet gateways** — Doors > Alexandria, Doors > Feedia and Doors > TTGBLOG hand the caller's line on to [Alexandria BBS](https://git.teletypegames.org/bbs/alexandria) (:2326), [Feedia](https://git.teletypegames.org/bbs/feedia) (:2327) and [TTGBLOG](https://git.teletypegames.org/bbs/ttgblog) (:2328) as it is, with rubbs' `BBS::Gateway`: those boards run their own code on their own ports, and the caller comes back when they hang up (Alt-X, or Q on a C64). The gateway reports the caller's window size; a C64 caller reports none, so the other board answers in PETSCII.
- **Registered names** — a caller can register the name they logged in with (Users > Register…); from then on that name asks for its password, with a 2-second wait after each wrong one. Profiles belong to registered names only. `accounts.csv` is read again whenever it changes, so `bin/account` works on a running server.
- **Sysop console** — stats + broadcast, for names in `BBS_SYSOPS` that logged in with their password.
- **Discord feed** — new board posts and sysop broadcasts go to `BBS_DISCORD_WEBHOOK`, mentions disabled.
- **Last callers** — a call is logged when it ends, and only if the terminal reported its window size (telnet NAWS) and stayed at least 10 seconds. Telnet password-guessing bots never get listed, and neither do they show up as online.
- **ANSI Gallery** — the art files of the desktop folder with their SAUCE record and a preview. **Enter** or **View** shows a piece on the full screen (rubbs' `AnsiArt.view`: scrolled with the arrows and PgUp/PgDn when taller than the screen, any other key returns), **Desktop** puts it on the desktop for the call, **Favourite** keeps it for every call of a registered name (the `art` column of the profile). `data/art` has the TTG pieces: `sunset.ans`, `pyramid.ans` (80×40, Blessing of Ra), `c64.ans`, `impostor.ans`, `floppy.ans` (the DOS tools), `ttg.ans`, `ttg-logo.ans` (the TTG logo, 80×40, converted to 16-colour half blocks), all CP437 with SAUCE, next to the older `.ansi` files.
- **TTG Master** (the first menu, F1, the desktop button, the Welcome window, Help) — the sysop who answers callers' questions about the board; the menu also has ready questions. See *Characters* below.
- **Full screen** — the windows with much to read (Welcome, News, Team, Oneliners, Boards and the composer, the wiki sections, Game Catalog, FTP Browser, Dev Log, ANSI Gallery, Live Chat, IRC, the TTG Master) can fill the screen and go back: `F5`, `Alt-Enter`, the `[↑]` gadget or a double click on the title bar (rubbs' `maximizable`). The small info windows and dialogs cannot.
- **xterm mouse** — click menus, buttons, list items; wheel-scroll lists.
- **Idle disconnect** at 10 minutes.
- **Configurable desktop art** — drop `.ans` / `.ansi` / `.asc` / `.nfo` / `.txt` files into `data/art/` (or wherever `BBS_DESKTOP_ART` points). Classic CP437 BBS art is auto-decoded; SAUCE metadata is stripped. With a directory, a different file is shown per session.

### The C64 face

The board as the C64 boards had it (`lib/ui/c64`), on a C64 terminal program
(CCGMS, StrikeTerm, SyncTERM in C64 mode) in the lowercase character set: the
TELETYPE logo in reversed blocks, the name and the password, the logon scans,
then the main menu, one key for each line:

```
 MESSAGES            CONTENT
 M message boards    F file areas
 E e-mail            B ftp browser
 O oneliners         G game catalog
 L live chat         W wiki & how-tos
 I irc channel       N news
 P page the sysop    U bulletins
                     D dev log
 PEOPLE              MORE
 C callers & users   R doors
 V voting booth      T ttg master
 S you & your name   Y system info
 H hall of fame      ? help
 Z sysop console     Q log off
```

Lists are numbered: the number and RETURN opens one, RETURN alone turns the
page, `Q` or `←` (RUN/STOP too) goes back. Long texts stop at every
screenful. Posts and letters take several lines; an empty line ends them. In
the live chat the others' lines show up above the one being typed. Wiki pages
are the same Markdown, rendered 38 columns wide. Files cannot come down the
line, so the file areas and the FTP browser give each file's plain HTTP
address (`BBS_ARCHIVE_URL`) and its FTP one. The doors are the ones that fit 40
columns (the Commodore 64 and the Plus/4, Impostor, and the Alexandria, Feedia and
TTGBLOG gateways, which those boards answer in PETSCII); the others are on the modern face.
The ANSI Gallery is on the modern face only. Mail rings when it arrives during
the call, and `Q` ends the call with `NO CARRIER`.

The screen is rubbs' PETSCII line (`session.petscii!`, see the rubbs README):
the C64 face writes UTF-8 with ANSI colours, and the line makes PETSCII of it,
so the shared parts (Markdown, the doors' FakeOS) work there unchanged.

## Project structure

```
bbs.rb                                 entry point: the terminal question, then a face
lib/
  domain.rb                            loads the domain (and the doors and characters)
  domain/teletype_bbs.rb               the board: services wired to their stores, the
                                       doors, and what a call does across services
                                       (logon, posting, mail, paging, statistics)
  domain/repository/
    online_users_repository.rb         the nodes: who, since when, doing what
    board_repository.rb                multi-board CSV store
    wiki_repository.rb                 Grav wiki JSON client
    catalog_repository.rb              games API client
    last_callers_repository.rb         finished-call log
    profile_repository.rb              per-user persistent profile
    account_repository.rb              registered names, PBKDF2 hashes
    site_repository.rb                 teletypegames.org events + members
    oneliner_repository.rb             the oneliners wall
    ftp_repository.rb                  anonymous FTP: folder listings, file bytes
    gitea_repository.rb                public activity of the Gitea organisations
    mail_repository.rb                 private mail and feedback
    last_read_repository.rb            how far each name has read each board
    vote_repository.rb                 the voting booth's ballots
    http_json.rb                       JSON GET + 5-minute cache
  domain/service/
    online_service.rb, board_service.rb, wiki_service.rb,
    games_service.rb, chat_service.rb, irc_relay.rb, last_callers_service.rb,
    profile_service.rb, account_service.rb, site_service.rb,
    oneliner_service.rb, file_library_service.rb, dev_log_service.rb,
    art_service.rb, discord_notifier.rb, mail_service.rb,
    voting_service.rb, file_area_service.rb, tagline_service.rb
  domain/model/                        value objects (MessageModel, GameModel, …)
  doors/commodore.rb                   the C64 and Plus/4 doors
  doors/commodore/basic.rb             their BASIC V2 interpreter
  doors/ra.rb                          Chat of Ra
  doors/trivia.rb                      TTG Trivia
  content/                             polls.yml, trivia.yml, taglines.yml,
                                       bulletins/*.md, logon.ans
  characters/                          Ra and the TTG Master: personas, riddles,
                                       the Master's knowledge (modern and C64),
                                       eval questions, the shared model client
  ui/modern.rb                         the modern face: modem, logon matrix,
                                       the Application (windows, menus, doors)
  ui/modern/formatters.rb              view helpers: bulletin, news, game card,
                                       team, network, DOS intro, users, sysop,
                                       oneliners, FTP browser, dev log, gallery
  ui/modern/classic_formatters.rb      logon/logoff, nodes, mail, voting,
                                       file areas, history, hall of fame
  ui/c64.rb                            the C64 face: logo, logon, NO CARRIER
  ui/c64/screen.rb                     title bar, pages, numbered lists, editor,
                                       chat line on the 40×25 screen
  ui/c64/board.rb                      the main menu, doors, Master, help, sysop
  ui/c64/messages.rb, content.rb,      its sections
  ui/c64/people.rb
bin/persona-eval                       count a character's slips over many runs
data/
  boards/<id>.csv                      per-board messages (auto-created)
  last_callers.csv                     finished calls
  profiles.csv                         persistent user profiles
  accounts.csv                         registered names (mode 600)
  oneliners.csv                        the oneliners wall
  impostor_sessions.csv                what callers left in the Impostor door
  mail.csv                             private mail and feedback (mode 600)
  last_read.csv                        the new-message scan's marks
  votes.csv                            the voting booth's ballots
  trivia_scores.csv                    TTG Trivia games
  art/                                 the desktop art and the ANSI Gallery
bin/account                            create an account / reset a password
```

## Doors

A door is one line of `TeletypeBBS#doors` (`lib/domain/teletype_bbs.rb`): its
name, the program, the label with its hotkey, the narrowest screen it draws
for, and optionally the same door drawn for 40 columns. The modern face
declares them all in its Application, and its Doors menu (`doors` in the
menubar block) lists them by itself; the C64 face offers the ones of 40
columns and the ones with a C64 version (Impostor).

```ruby
Door.new(:sermo,    Sermo::OS, '&SERMO', 80),
Door.new(:c64,      Commodore.os(Commodore::C64, games: @games, files: @files), '&Commodore 64', 40),
Door.new(:plus4,    Commodore.os(Commodore::PLUS4, games: @games, files: @files), 'Commodore &Plus/4', 40),
Door.new(:impostor, Impostor.flow(sessions: @impostor_sessions), '&Impostor', 80,
         Impostor.flow(sessions: @impostor_sessions, c64: true)),
```

The program is a `BBS::FakeOS` definition, a `BBS::Flow` or a callable `(session, context)`.
rubbs runs it on a clean screen and rebuilds the BBS when it returns, with the
same context, so the caller's session survives the trip.

**Commodore 64 / Plus/4** (`lib/doors/commodore.rb`) — the machine at its
`READY.` prompt: blue C64 screen, grey Plus/4 screen, 40 columns. It has a
small BASIC V2 (`lib/doors/commodore/basic.rb`: PRINT, LET, GOTO, GOSUB, IF,
FOR/NEXT, INPUT, POKE/PEEK, LIST, RUN, NEW, the numeric and string
functions), so `10 PRINT CHR$(205.5+RND(1)); : GOTO 10` draws the maze; any
key is RUN/STOP. The disk holds our games for that machine from the catalog:
`LOAD"$",8` and `LIST` show the directory (the block counts come from the
`.prg` sizes on the FTP server), `LOAD"NAME",8` (wildcards work) loads a game
as a BASIC program, `LIST` shows it and `RUN` prints its card with the catalog
link. The Plus/4 also knows `DIRECTORY` and `DLOAD`. `SYS 64738` resets the
C64; `EXIT` returns to the BBS.

**Chat of Ra** (`lib/doors/ra.rb`) — the caller is the worker sealed in the
pyramid of Blessing of Ra, and the sun god answers from above, in gold. Words
go to the model as Ra; `RIDDLE` asks one of the riddles of the pyramid
(`lib/characters/ra_riddles.yml`), which the code asks and checks (`HINT`,
`SKIP`); three solved earn the blessing, and the way to the game. `GAME`
tells where the game is, from the catalog. See *Characters* below.

**TTG Trivia** (`lib/doors/trivia.rb`) — a door game of the old kind: ten
questions, 20 seconds each, A–D to answer; a quick answer is worth more (50 +
10 a second left) and three right in a row earn a streak bonus. Some questions
are made from the catalog and the team (a game's platform, a real title among
made-up ones, whose motto), the rest come from `lib/content/trivia.yml` (the
first answer is the right one). A finished game of a named caller goes to
`TRIVIA_SCORES_PATH`; the best ten are its hall of fame.

**Impostor** ([impostor-bbs](https://git.teletypegames.org/bbs/impostor-bbs),
the `impostor` gem) — the debrief terminal of Definitely not an Impostor, the
same flow as the standalone Impostor BBS on port 2324. Its sessions go to
`IMPOSTOR_SESSIONS_PATH`. When it ends, ENTER returns to the BBS.

The `sermo` and `impostor` gems are pinned to a revision in `Gemfile.lock`;
the entrypoint updates only rubbs on start. After a change in sermo-bbs or
impostor-bbs:

```bash
bundle lock --update sermo      # or impostor
```

then commit and redeploy.

### Sysop accounts

Names in `BBS_SYSOPS` cannot be registered over telnet, so nobody can take one
first. Create the account (or reset any password) from the server shell:

```bash
docker exec -it teletype-bbs bin/account Tasi
```

## Characters

Ra and the TTG Master talk through the shared model service (infra/llm,
Qwen3.5 0.8B), with rubbs' `BBS::AI`. A model this small is good at a short
reply in a voice and bad at facts, so the code keeps the facts:

- **Personas** — `lib/characters/ra.yml` and `master.yml`: the system prompt,
  example turns, sampling (`temperature`, `max_tokens`, `stop` on a blank line
  or a code fence), `deflect` rules the code answers without the model (code,
  poems, "are you a bot"), and canned replies for when the model is down.
- **Ra** — the riddles and the game's whereabouts are answered by the code;
  only free talk goes to the model.
- **TTG Master** (`lib/characters/master.rb`) — the code looks up the facts
  for each question: up to two entries of `master_knowledge.yml` (keys are
  words or phrases of the question; generic words like board or game weigh
  half) and the live releases, events and game list. The model only words
  them, and the code checks the wording: it must keep one of the facts'
  anchors (a menu path, a game or event name) and name no menu path that is not
  in them, else the caller gets the fact itself. A question with no facts never
  reaches the model. The answer is made in a thread and shows up on the
  window's next tick. On the C64 face the same Master works from
  `master_c64.yml` and `master_knowledge_c64.yml`, which tell the way around in
  the keys of its menus.

Change a persona by measuring it, not by single replies. `bin/persona-eval`
asks the questions of `lib/characters/eval/<name>.yml` several times and
counts the slips: out of character, markdown, emoji, too long, and for the
Master a miss (none of the question's `expect` phrases):

```bash
BBS_LLM_URL=http://localhost:8080 bundle exec bin/persona-eval master 3
docker exec teletype-bbs bundle exec bin/persona-eval ra 3      # on the server, with infra/llm
```

At the last tuning (2026-10-21): Ra 1 slip in 48 replies, the Master 0 in 48.
To add a fact, add an entry to `master_knowledge.yml` and a question to the
eval.

## Data

All persisted state lives under `data/` which is mounted as a volume in Docker
so it survives container restarts.
