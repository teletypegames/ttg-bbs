# Teletype BBS

Telnet-accessible Synchronet-style community BBS server built on the
[rubbs](https://git.teletypegames.org/engines/rubbs) gem: the clubhouse of the
Teletype Games BBS Network. It keeps the habits of the old boards: a modem
handshake and a logon matrix, caller numbers, a logon sequence that scans your
mail and the message bases, nodes, message boards, private mail, feedback to
the sysop and a page bell, oneliners, a live chat, a voting booth, numbered
bulletins, a hall of fame, and NO CARRIER at the end. Around them the team's
dev log from Gitea, the IRC channel, the TTG Master who answers callers'
questions (F1), and the doors that live only here: SERMO, a Commodore 64, a
Plus/4, Chat of Ra and TTG Trivia.

What another board of the network carries is not repeated here: our games and
files are on [WarpEngine BBS](https://git.teletypegames.org/bbs/warp-engine-bbs)
(2329), the wiki on [TTG Wiki BBS](https://git.teletypegames.org/bbs/wiki-bbs)
(2325), the blog on [TTG Blog BBS](https://git.teletypegames.org/bbs/ttg-blog-bbs)
(2328), the art on [Pixelia BBS](https://git.teletypegames.org/bbs/pixelia-bbs)
(2332), the Impostor debrief on [Impostor BBS](https://git.teletypegames.org/bbs/impostor-bbs)
(2324), and [TTG Gate BBS](https://git.teletypegames.org/bbs/ttg-gate-bbs) (2399)
dials them all. Board > BBS Network (N on the C64) tells a caller where each
thing is, and so does the TTG Master.

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
| `TELETYPE_BBS_SYSOPS` | empty | Comma-separated sysop names. Sysop rights need the name's password; these accounts are created only with `bin/account` |
| `TELETYPE_BBS_DISCORD_WEBHOOK` | empty | Discord webhook for new board posts and sysop broadcasts; empty = off |
| `TELETYPE_BBS_IRC_SERVER` | `irc.libera.chat` | IRC server of the read-only channel window (TLS); empty = off |
| `TELETYPE_BBS_IRC_PORT` | `6697` | Its TLS port |
| `TELETYPE_BBS_IRC_CHANNEL` | `#teletypegames` | The channel the board listens on |
| `TELETYPE_BBS_IRC_NICK` | `ttgbbs` | The board's nick there; taken at login → `ttgbbs_` |
| `TELETYPE_BBS_IRC_PASSWORD` | empty | NickServ password of the nick (SASL PLAIN); empty = no login |
| `TELETYPE_BBS_ACCOUNTS_PATH` | `data/accounts.csv` | Registered names with salted PBKDF2-SHA256 password hashes |
| `TELETYPE_BBS_BOARDS_PATH` | `data/boards` | Directory of per-board CSV files |
| `TELETYPE_BBS_MESSAGES_PATH` | `data/messages.dat` | Legacy single-board file; auto-migrated into the General board on first run |
| `TELETYPE_BBS_LAST_CALLERS_PATH` | `data/last_callers.csv` | Finished calls (see *Last callers* below) |
| `TELETYPE_BBS_PROFILE_PATH` | `data/profiles.csv` | User profile CSV (its old `art` column stays in the file, unread) |
| `TELETYPE_BBS_ONELINERS_PATH` | `data/oneliners.csv` | The oneliners wall |
| `TELETYPE_BBS_MAIL_PATH` | `data/mail.csv` | Private mail and the feedback to the sysop (mode 600) |
| `TELETYPE_BBS_LAST_READ_PATH` | `data/last_read.csv` | How far each registered name has read each board (the new-message scan) |
| `TELETYPE_BBS_VOTES_PATH` | `data/votes.csv` | The ballots of the Voting Booth, a log: a name's later ballot wins |
| `TELETYPE_BBS_TRIVIA_SCORES_PATH` | `data/trivia_scores.csv` | Every finished TTG Trivia game, for its hall of fame |
| `TELETYPE_BBS_LOGON_ART` | `lib/content/logon.ans` | The art of the logon matrix, above the name prompt |
| `TELETYPE_BBS_FTP_HOST` | `ftp.teletypegames.org` | The FTP server whose `/WARP` sizes give the Commodore doors the blocks of each game (anonymous, passive); the catalog API carries no sizes |
| `SERMO_LLM_URL` | set by compose | SERMO's model, `http://llm:8080`; empty = canned replies only |
| `SERMO_LLM_MODEL` | set by compose | the model's name in infra/llm, `qwen3.5-0.8b` |
| `SERMO_LLM_API_KEY` | empty | SERMO's key to infra/llm, one of its `LLM_API_KEYS`; without it SERMO gets a 401 and answers with canned replies |
| `TELETYPE_BBS_LLM_URL`, `TELETYPE_BBS_LLM_MODEL`, `TELETYPE_BBS_LLM_API_KEY` | SERMO's | The model of the BBS's own characters (Ra, the TTG Master); each one unset or empty falls back to its `SERMO_LLM_*` |

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
last read, open polls in the voting booth — and the quote
of the day (a member's motto). The board's logo heads it: TTG BBS in a
three-by-five pixel font (`lib/ui/logo.rb`), yellow to red like the logon art,
the same on the C64 face. ENTER opens the full-screen Synchronet-style shell
on the **dashboard**: the logo and the greeting, the TTG Gate BBS banner, four
live panels (who is on line now, what is new — the newest posts and your
unread letters —, the last callers, what is coming up, with the days to go)
and the oneliners running along the bottom (`lib/ui/modern/desktop.rb`).
It refreshes itself every few seconds; Board > Dashboard closes every window
and brings it back. Board > Log off (Alt-X) ends the call with the logoff
screen: the call's length, a tagline, `+++`, `ATH0`, `NO CARRIER`.

The statusbar shows the node, the clock and the time on line on the right;
while a menu is open it tells what the highlighted item does instead. The
desktop has a **F1 ▸ Lost? Ask the TTG Master** button in its bottom right
corner.

Every window wears the colour of its menu on its frame and its title: Board
pale teal, Messages green, People pink, Doors salmon, You grey, Help yellow (`UI::Modern::Accent`). The dashboard's panels wear the
colour of what they show.

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

The menus go by what a caller wants to do; every item has a hint, shown on the
statusbar while it is highlighted.

| Menu | Items |
|---|---|
| **Board** | Dashboard · Bulletins… · Dev Log · System Info · BBS Network (our boards and what each carries) · Log off |
| **Messages** | Boards… · New Post… · Mail… · Oneliners · Live Chat · IRC #teletypegames · Voting Booth · Feedback to the Sysop… · Page the Sysop |
| **People** | Who is Online · Last Callers · User Listing · Hall of Fame · Team |
| **Doors** | Door Lobby… · SERMO · Commodore 64 · Commodore Plus/4 · Chat of Ra · TTG Trivia |
| **You** | Your Stats · Profile… · Register… · Sysop Console (logged-in sysops only) |
| **Help** | Ask the TTG Master… · What is coming up? · Where do I start? · Where are the games, files, wiki? (the BBS Network) · Which doors are there? · New to BBSes? · Keys · About |

#### Features

- **Multi-board messaging** — separate sub-boards (General / Tech / Off-Topic / Sysop), each in its own CSV file under `data/boards/`.
- **Multi-line composer** — `TextArea` widget, up to 1000 chars per post, one post per 30 seconds from a call.
- **Oneliners** — a wall of one-line messages (64 characters, a name needed, not Anonymous); the newest run along the bottom of the dashboard.
- **Live chat** — broadcast hub, 1 Hz polling, history replay on join; at most two lines a second from one caller, and a caller who does not read keeps the last 200 lines.
- **IRC #teletypegames** — a read-only window on the channel at Libera.Chat: one connection for the whole board under the nick `ttgbbs` (TLS, reconnects with a growing pause), the last 200 lines replayed, the member count and the topic; the window tells how to join, and the input line only repeats it. mIRC formatting and control characters are stripped. The board never speaks on the channel.
- **Dashboard** — the desktop, live: the nodes, the newest posts of the boards and the caller's unread letters, the last callers, the coming events with their countdown, the message count and the oneliners ticker, refreshed every five seconds.
- **Door Lobby** (Doors) — every door with what it is, the screen it needs (and whether the C64 face has it) and how many callers are inside; Enter or Open steps in.
- **Logon sequence** — caller numbers (every logged call before this one, plus one), a name's calls, first and last call and time on line, and the scans: unread mail, the new messages of each board since the name last opened it (registered names; `TELETYPE_BBS_LAST_READ_PATH`), polls without the caller's vote. The quote of the day is a member's motto, the same for everyone until midnight; the logoff screen picks a tagline (`lib/content/taglines.yml`) or a motto.
- **Nodes** — every caller gets the lowest free node number. People > Who is Online lists the nodes with the name, what the caller is doing (the title of the top window, *At the main menu*, or the door) and the time on line.
- **Mail** (Messages > Mail…, F7) — private letters between registered names: Write, Reply, Delete; `•` marks the unread ones. **Feedback to the Sysop…** is a letter to `Sysop`, which anyone with a name may write and every sysop reads in their own mailbox; the Discord feed gets only that a letter came, never what it says. A letter arriving during a call rings the bell and says so. One letter every 30 seconds from a call.
- **Page the Sysop** — once a call: the bell, a line in the live chat and on Discord; when no sysop is on line it offers to leave a letter.
- **Voting Booth** (Messages) — the polls of `lib/content/polls.yml`; `options: catalog` fills one with the released games, `options: doors` with the doors. Results as bars; a name (not Anonymous) votes and can change its vote.
- **Bulletins** (Board > Bulletins…, Help > New to BBSes?) — numbered: the logon bulletin (the board in numbers, the newest posts, what is coming up, the last callers, the wall), About Teletype Games, what is coming up, the board rules and New to BBSes? (`lib/content/bulletins/*.md`), and the BBS network.
- **Hall of Fame** (People) — top lists with bars: the top callers, the top posters and the TTG Trivia high scores. **User Listing** has the registered names with their calls, last call and location; **Your Stats** the caller's own numbers.
- **Dev Log** — the public activity of every organisation on git.teletypegames.org (pushes with their commit messages, tags, releases, new repositories), newest first, read anonymously from the Gitea API, so private repositories never show.
- **Team** — the members of teletypegames.org with their mottos.
- **Doors** — full-line programs the BBS hands the telnet line to and takes it back from when they exit (rubbs' `BBS::Door`). **SERMO** ([sermo-bbs](https://git.teletypegames.org/bbs/sermo-bbs), pulled in as the `sermo` gem) is a dual machine running SERMO, from the Neumatronic universe: type a command, or just talk to it; `EXIT` returns to the BBS. Natural language goes to its Lapis-ACP, the Qwen3.5 0.8B model in the shared `infra/llm` service. See *Doors* below.
- **BBS Network** (Board > BBS Network, Help > Where are the games, files, wiki?, N on the C64) — every board of the network with its port and what it carries, the TTG Gate BBS that dials them all, bbsweb, and the FTP tree on plain HTTP at archive.teletypegames.org. This board has no gateway doors: a caller goes to another board by calling it, or through TTG Gate BBS.
- **Registered names** — a caller can register the name they logged in with (You > Register…); from then on that name asks for its password, with a 2-second wait after each wrong one. Profiles belong to registered names only. `accounts.csv` is read again whenever it changes, so `bin/account` works on a running server.
- **Sysop console** — stats + broadcast, for names in `TELETYPE_BBS_SYSOPS` that logged in with their password.
- **Discord feed** — new board posts and sysop broadcasts go to `TELETYPE_BBS_DISCORD_WEBHOOK`, mentions disabled.
- **Last callers** — a call is logged when it ends, and only if the terminal reported its window size (telnet NAWS) and stayed at least 10 seconds. Telnet password-guessing bots never get listed, and neither do they show up as online.
- **TTG Master** (F1, the desktop button, Help) — the sysop who answers callers' questions about the board; the menu also has ready questions. See *Characters* below.
- **Full screen** — the windows with much to read (Team, Oneliners, Boards and the composer, Mail, Bulletins, Dev Log, Hall of Fame, Live Chat, IRC, the TTG Master) can fill the screen and go back: `F5`, `Alt-Enter`, the `[↑]` gadget or a double click on the title bar (rubbs' `maximizable`). The small info windows and dialogs cannot.
- **xterm mouse** — click menus, buttons, list items; wheel-scroll lists.
- **Idle disconnect** at 10 minutes.
### The C64 face

The board as the C64 boards had it (`lib/ui/petscii`), on a C64 terminal program
(CCGMS, StrikeTerm, SyncTERM in C64 mode) in the lowercase character set: the
TTG BBS logo in reversed blocks (yellow, orange and red, the modern face's
logo), the name and the password, the logon scans, then the main menu: who is
calling and what is happening (the callers on line, new mail, the next event
with its days to go, the newest post), then the sections in two columns, a
cursor menu of rubbs (`BBS::Selector`). Each section is a band of its colour,
and its keys and its bar wear it. CRSR moves the bar (left and right to the
column beside), RETURN opens the lit item, and the letter in front of an item
opens it at once, as before; under the menu a line about the lit item.

```
 TELETYPE BBS              node 2 13:32
 hi tasi! · 3 on line · 2 new mail
 next: TTG Game Jam in 3 days
 new:  Tasi: who is up for a jam?
 ──────────────────────────────────────
 [messages] ───────  [board] ───────────
 M message boards   U bulletins
 E e-mail 2         D dev log
 O oneliners        N network
 L live chat
 I irc channel
 P page the sysop
 [people] ─────────  [more] ────────────
 C callers & users  R doors
 V voting booth     T ttg master
 S you & your name  Y system info
 H hall of fame     ? help
 Z sysop console    Q log off
 read and post on the boards
 crsr: choose  return: open  q: off
```

The doors list gives each door a few words of what it is.

Lists are numbered cursor menus: CRSR or the number typed lights one, RETURN
opens it, CRSR left and right turn the pages, `Q` or `←` (RUN/STOP too) goes
back. The keys under a post, a letter or the wall are a row the cursor moves
along, their letters working as well. Long texts stop at every
screenful. Every line is typed in a field of rubbs (`BBS::Field`: the cursor
keys move in it, DEL deletes, RETURN ends it, RUN/STOP or `←` goes back);
posts and letters are written in its full-screen editor (`BBS::Editor`):
RUN/STOP or `←`, then `S` sends them, `Q` drops them. In
the live chat the others' lines show up above the one being typed. Bulletins
are the same Markdown, rendered 38 columns wide. `N` is the BBS Network, 40
columns wide: our games and files come to a C64 by XMODEM from the WarpEngine
BBS. The doors are the ones that fit 40 columns (the Commodore 64 and the
Plus/4); SERMO, Chat of Ra and TTG Trivia are on the modern face. Mail rings
when it arrives during the call, and `Q` ends the call with `NO CARRIER`.

The screen is rubbs' PETSCII line (`session.petscii!`, see the rubbs README):
the PETSCII face writes UTF-8 with ANSI colours, and the line makes PETSCII of it,
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
    catalog_repository.rb              games API client (the doors, the Master)
    last_callers_repository.rb         finished-call log
    profile_repository.rb              per-user persistent profile
    account_repository.rb              registered names, PBKDF2 hashes
    site_repository.rb                 teletypegames.org events + members
    oneliner_repository.rb             the oneliners wall
    ftp_repository.rb                  anonymous FTP: the file sizes of a folder
    gitea_repository.rb                public activity of the Gitea organisations
    mail_repository.rb                 private mail and feedback
    last_read_repository.rb            how far each name has read each board
    vote_repository.rb                 the voting booth's ballots
    http_json.rb                       JSON GET + 5-minute cache
  domain/service/
    online_service.rb, board_service.rb, games_service.rb,
    chat_service.rb, irc_relay.rb, last_callers_service.rb,
    profile_service.rb, account_service.rb, site_service.rb,
    oneliner_service.rb, warp_sizes.rb, dev_log_service.rb,
    discord_notifier.rb, mail_service.rb, voting_service.rb,
    tagline_service.rb
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
  ui/logo.rb                           the board's logo (TTG BBS, BBS::BlockFont) for both faces
  ui/modern/desktop.rb                 the dashboard and the colours of the menus
  ui/modern/formatters.rb              view helpers: bulletin, events, posts, doors,
                                       team, network, users, sysop, oneliners,
                                       dev log, the Master's quick questions
  ui/modern/classic_formatters.rb      logon/logoff, nodes, mail, voting,
                                       bulletins, hall of fame
  ui/petscii.rb                        the PETSCII face: logo, logon, NO CARRIER
  ui/petscii/screen.rb                 the 40×25 screen (BBS::Petscii::Screen of
                                       rubbs) and its chat line
  ui/petscii/board.rb                  the main menu, doors, Master, help, sysop
  ui/petscii/messages.rb, content.rb,  its sections (content.rb: bulletins,
                                       the network, dev log)
  ui/petscii/people.rb
bin/persona-eval                       count a character's slips over many runs
data/
  boards/<id>.csv                      per-board messages (auto-created)
  last_callers.csv                     finished calls
  profiles.csv                         persistent user profiles
  accounts.csv                         registered names (mode 600)
  oneliners.csv                        the oneliners wall
  mail.csv                             private mail and feedback (mode 600)
  last_read.csv                        the new-message scan's marks
  votes.csv                            the voting booth's ballots
  trivia_scores.csv                    TTG Trivia games
bin/account                            create an account / reset a password
```

## Doors

A door is one entry of `TeletypeBBS#doors` (`lib/domain/teletype_bbs.rb`):
its name, the program, the label with its hotkey, the narrowest screen it
draws for, optionally the same door drawn for 40 columns, and three texts:
`tag` (a few words for the C64's list), `hint` (the statusbar line of its menu
item) and `about` (its paragraph in the Door Lobby). The modern face declares
them all in its Application, and its Doors menu (`doors` in the menubar block)
lists them by itself under the Door Lobby; the PETSCII face offers the ones of
40 columns and the ones with a C64 version (`petscii:`).

Only the programs that live here are doors: SERMO, the Commodore 64 and
Plus/4, Chat of Ra and TTG Trivia. The other boards of the network are no
doors here (no `BBS::Gateway`): TTG Gate BBS dials them.

```ruby
Door.new(name: :c64, program: Commodore.os(Commodore::C64, games: @games, sizes: @warp_sizes),
         label: '&Commodore 64', cols: 40, tag: 'c64 + our games',
         hint: 'A Commodore 64 at READY., with our C64 games on its disk: LOAD"$",8 lists them',
         about: 'A Commodore 64 at its READY. prompt, with a small BASIC V2. …'),
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
`.prg` sizes in the FTP server's `/WARP`, `WarpSizes`), `LOAD"NAME",8` (wildcards work) loads a game
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
`TELETYPE_BBS_TRIVIA_SCORES_PATH`; the best ten are its hall of fame.

The `sermo` gem is pinned to a revision in `Gemfile.lock`; the entrypoint
updates only rubbs on start. After a change in sermo-bbs:

```bash
bundle lock --update sermo
```

then commit and redeploy.

### Sysop accounts

Names in `TELETYPE_BBS_SYSOPS` cannot be registered over telnet, so nobody can take one
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
  window's next tick. On the PETSCII face the same Master works from
  `master_c64.yml` and `master_knowledge_c64.yml`, which tell the way around in
  the keys of its menus.

Change a persona by measuring it, not by single replies. `bin/persona-eval`
asks the questions of `lib/characters/eval/<name>.yml` several times and
counts the slips: out of character, markdown, emoji, too long, and for the
Master a miss (none of the question's `expect` phrases):

```bash
TELETYPE_BBS_LLM_URL=http://localhost:8080 bundle exec bin/persona-eval master 3
docker exec teletype-bbs bin/persona-eval ra 3            # on the server, with infra/llm
docker exec teletype-bbs bin/persona-eval master_c64 3    # the Master of the C64 face
```

The Master names a menu path only for what is on this board; for what
another board of the network carries he names that board and its port
(the games on WarpEngine BBS 2329, the wiki on TTG Wiki BBS 2325, …). At the
slimming down (2026-11-01), on the new questions: the modern Master went from
44 slips in 90 replies (27 misses) with the old knowledge to 9 (5 misses),
the C64 Master from 34 in 87 (27 misses) to 17 (10 misses); the misses left
are mostly the live game list winning over Commodex BBS for "cheats for C64
games". Ra, at the last tuning (2026-10-21): 1 slip in 48 replies.
To add a fact, add an entry to `master_knowledge.yml` (and its C64 twin) and
a question to the eval.

## Data

All persisted state lives under `data/` which is mounted as a volume in Docker
so it survives container restarts.
