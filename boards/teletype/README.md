# Teletype BBS

Telnet-accessible Synchronet-style community BBS server built on the
[rubbs](https://git.teletypegames.org/engines/rubbs) gem: the clubhouse of the
Teletype Games BBS Network, and it looks like one. The desktop is the
clubhouse from the street with a lit window for everyone inside, and the menus
are its rooms: the cork board, the mailbox, the bell, the games room at the
back, the trophy case, the town map on the wall (see *The clubhouse* below).
It keeps the habits of the old boards: caller numbers, nodes, a wall where
callers pin notes and answer each other, letters and a page bell for the
sysop, a voting booth, numbered bulletins, a hall of fame, and NO CARRIER at
the end. Around them the team's dev log from Gitea, the TTG Master who
answers callers' questions (F1), and the doors that live only here: SERMO, a
Commodore 64, a Plus/4, Chat of Ra and TTG Trivia.

The wall and the letters to the sysop are the network's, not the board's
own: they live on [TTG Gate BBS](https://git.teletypegames.org/bbs/ttg-gate-bbs),
the Central, and ttg-common draws them (`TTG::Wall`, `TTG::Feedback`; see
*Messages* below).

What another board of the network carries is not repeated here: our games and
files are on [WarpEngine BBS](https://git.teletypegames.org/bbs/warp-engine-bbs)
(2329), the wiki on [TTG Wiki BBS](https://git.teletypegames.org/bbs/wiki-bbs)
(2325), the blog on [TTG Blog BBS](https://git.teletypegames.org/bbs/ttg-blog-bbs)
(2328), the art on [Pixelia BBS](https://git.teletypegames.org/bbs/pixelia-bbs)
(2332), the Impostor debrief on [Impostor BBS](https://git.teletypegames.org/bbs/impostor-bbs)
(2324), and [TTG Gate BBS](https://git.teletypegames.org/bbs/ttg-gate-bbs) (2399)
dials them all. The town map, Board > BBS Network (N on the C64), tells a caller where each
thing is, and so does the TTG Master.

The board has two faces on one port: the **modern** one for ANSI terminals
(windows, menus, mouse) and a **Commodore 64** one in PETSCII, 40×25, with
single-key menus. Both work on the same board: a C64 caller and a PC caller
share the nodes and the wall.

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
| `RUBBS_AUTH_SECRET` | empty | The secret every board of the network shares (rubbs `Rubbs::Common::Auth`): the accounts, the wall and the feedback are asked of TTG Gate BBS, the Central, on the `interstack` network, and a caller handed on by the gate comes in signed in. In `.env` on the server, never in the repository |
| `TELETYPE_BBS_DB` | `data/teletype.sqlite3` | The board's SQLite database: the members, calls, profiles, votes and TTG Trivia scores, and the posts, oneliners and mail of before the network's wall and feedback, kept as the archive (see *Data*) |
| `TELETYPE_BBS_FTP_HOST` | `ftp.teletypegames.org` | The FTP server whose `/WARP` sizes give the Commodore doors the blocks of each game (anonymous, passive); the catalog API carries no sizes |
| `SERMO_LLM_URL` | set by compose | SERMO's model, `http://llm:8080`; empty = canned replies only |
| `SERMO_LLM_MODEL` | set by compose | the model's name in infra/llm, `qwen3.5-0.8b` |
| `SERMO_LLM_API_KEY` | empty | SERMO's key to infra/llm, one of its `LLM_API_KEYS`; without it SERMO gets a 401 and answers with canned replies |
| `TELETYPE_BBS_LLM_URL`, `TELETYPE_BBS_LLM_MODEL`, `TELETYPE_BBS_LLM_API_KEY` | SERMO's | The model of the BBS's own characters (Ra, the TTG Master); each one unset or empty falls back to its `SERMO_LLM_*` (read by `TeletypeBBS.llm`, the composition root) |

## Log

Every line on stderr (`docker logs teletype-bbs`) starts with the log tag
`teletype-bbs:` (rubbs' `Rubbs.log`) and what it is about: `export` (the
posts, oneliners and letters to the sysop of before handed over to the
network, a `Rubbs.background` job: what went, or why the Central did not take
it, tried again after a pause doubled up to an hour), `catalog`, `site
events`, `site members`, `dev log`, `ftp` (a remote source failed: the
repository raised, the service logged it and shows nothing), `polls`,
`login`, `dashboard`, `TTG Master`, `trivia`, and rubbs' own lines
(sessions, doors, the Central).

## Interface

A call starts with one question, before the name: which terminal is calling.
The board guesses first: it waits up to 1.5 seconds for the telnet answers, and
a terminal that reports a window wider than 40 columns is a modern one; 40
columns, or no answer at all (a C64 behind a WiFi modem speaks plain TCP), is
taken for a Commodore. The question is rubbs' `Rubbs::Common::Call::Terminal`, plain ASCII in
capitals, readable on both: `1` (or `M`) picks the modern face (ANSI/xterm, 256
colours), `2` (or `C`) the C64 (PETSCII), and RETURN takes the pick, or the
guess when nothing is picked.
Whatever the caller types before the question is dropped (a bot's `root`), and
mouse reporting is switched on only after the choice, so the C64 never gets
its escape sequence.

### The modern face

After the splash (Login, Register or Guest; see *Registered names* below)
the call opens the full-screen Synchronet-style shell on the **dashboard**, the clubhouse from the street (`lib/ui/modern/desktop.rb`):
the hanging sign, the house of the time of day in Budapest (dawn, day, dusk,
night) with a lit window for every node taken (the caller's own brighter), the
door and the lamp lit while anyone is in, smoke from the chimney when a note
was pinned on the wall in the last five minutes, for a sysop the mailbox flag
and the number of new letters to the sysops, and the node and caller number in
the sky; in winter snow on the roof, pumpkins in
the last week of October, fireworks on New Year's Eve, bunting on the days of a
game jam. Under the house two boards: **Inside now** (the nodes, then the
guestbook: the last callers) and **On the notice board** (what is coming up,
with a bar filling as the day nears; for a sysop the new feedback), and the
graffiti wall (the newest notes of the wall) running along the bottom. It
refreshes itself every few seconds; Board > Dashboard closes every window and
brings it back. While a window of a room is open, the card of that room sits
over the top of the house. A terminal smaller than 80×23 keeps the boards and
the wall without the house. Board > Log off (Alt-X) puts the lamps of the
clubhouse out one by one, with the coat ticket (the caller number and the time
on line), a tagline, `+++`, `ATH0`, `NO CARRIER`.

The statusbar shows the node, the clock and the time on line on the right;
while a menu is open it tells what the highlighted item does instead. The
desktop has a **F1 ▸ Lost? Ask the TTG Master** button in its bottom right
corner.

Every window wears the colour of its menu on its frame and its title, and the
icon of its menu in the title: Board pale teal ☼, Messages green ✉, People
pink ☺, Doors salmon ♫, You grey ♥, Help yellow ¿ (`UI::Modern::Accent`,
`UI::Modern::Icon`). The dashboard's boards wear the colour of what they show.

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
| `F2` | The Wall |
| `F7` | Feedback (a letter to the sysop) |
| `Alt-X` | Log off |

#### Menus

The menus go by what a caller wants to do; every item has a hint, shown on the
statusbar while it is highlighted.

| Menu | Items |
|---|---|
| **Board** | Dashboard · Bulletins… · Dev Log · System Info · BBS Network (the town map) · Log off |
| **Messages** | The Wall… · Feedback… · Voting Booth · Page the Sysop… |
| **People** | Who is Online · Last Callers · User Listing · Hall of Fame · Team |
| **Doors** | Games Room… · Door Lobby… · SERMO · Commodore 64 · Commodore Plus/4 · Chat of Ra · TTG Trivia |
| **You** | Your Stats · Profile… · Register… · Sysop Console · Sysop Feedback… (the last two for logged-in sysops only) |
| **Help** | Ask the TTG Master… · What is coming up? · Where do I start? · Where are the games, files, wiki? (the BBS Network) · Which doors are there? · New to BBSes? · Keys · About |

#### Features

- **The Wall** (Messages > The Wall…, F2) — the cork board of the clubhouse, see *Messages* below; the newest notes run along the bottom of the dashboard.
- **Dashboard** — the clubhouse from the street, live (see above), refreshed every five seconds from `SceneService`.
- **Games Room** (Doors) — the five stations at the back of the clubhouse (SERMO's green monitor, the C64 and its TV, the Plus/4, the pyramid of Ra, the quiz table of TTG Trivia), a lamp over each burning while somebody is inside, with the count; the arrows or a click choose a station and switch its screen on, Enter steps in. Under 80 columns it is the Door Lobby.
- **Door Lobby** (Doors) — every door with what it is, the screen it needs (and whether the C64 face has it) and how many callers are inside; Enter or Open steps in.
- **Caller numbers** — every logged call before this one, plus one; the dashboard, You > My Stats and the coat ticket of the logoff show it. The logoff screen picks a tagline (`lib/content/taglines.yml`) or a member's motto.
- **Nodes** — every caller gets the lowest free node number. People > Who is Online lists the nodes with the name, what the caller is doing (the title of the top window, *At the main menu*, or the door) and the time on line.
- **Feedback** (Messages > Feedback…, F7) and **Page the Sysop…** — a letter to the sysops, see *Messages* below.
- **Voting Booth** (Messages) — the polls of `lib/content/polls.yml`; `options: catalog` fills one with the released games, `options: doors` with the doors. Results as bars; a name (not Anonymous) votes and can change its vote.
- **Bulletins** (Board > Bulletins…, Help > New to BBSes?) — numbered: the logon bulletin (the nodes, what is coming up, the last callers, the newest notes of the wall), About Teletype Games, what is coming up, the board rules and New to BBSes? (`lib/content/bulletins/*.md`), and the BBS network.
- **Hall of Fame** (People) — the trophy case: a gold, a silver and a bronze cup for the first three of the top callers, the names most on the wall (the most notes among the newest hundred of the wall, guests left out) and the TTG Trivia high scores, the names on the plates, the places after them under the case with fading bars (the old top lists under 80 columns). **User Listing** has the registered names with their calls, last call and location; **Your Stats** the caller's own numbers.
- **Dev Log** — the public activity of every organisation on git.teletypegames.org (pushes with their commit messages, tags, releases, new repositories), newest first, read anonymously from the Gitea API, so private repositories never show.
- **Team** — the members of teletypegames.org with their mottos.
- **Doors** — full-line programs the BBS hands the telnet line to and takes it back from when they exit (rubbs' `Rubbs::Common::Call::Door`). **SERMO** ([sermo-bbs](https://git.teletypegames.org/bbs/sermo-bbs), pulled in as the `sermo` gem) is a dual machine running SERMO, from the Neumatronic universe: type a command, or just talk to it; `EXIT` returns to the BBS. Natural language goes to its Lapis-ACP, the Qwen3.5 0.8B model in the shared `infra/llm` service. See *Doors* below.
- **BBS Network** (Board > BBS Network, Help > Where are the games, files, wiki?, N on the C64) — the town map on the clubhouse wall: every board of the network a building in its bbsweb colour around the clubhouse (the town gate of TTG Gate BBS, the archive of the wiki, the great library of Alexandria, the news kiosk of Feedia, the printing press of the blog, the warehouse of WarpEngine, the scriptorium, the game shop of Commodex, the gallery of Pixelia, the dark alley of the Impostor, and on the fourth row of the town the starbase of Starbase BBS, the cave of HackerCave BBS and the post office of TTG Mail BBS). The arrows walk from building to building; under the map what the chosen one carries and how to walk over. On a screen shorter than the town the map scrolls to the chosen building (rubbs' `FrameBuffer#clip`). The list of the boards, with bbsweb and archive.teletypegames.org, is a bulletin. This board has no gateway doors: a caller goes to another board by calling it, or through TTG Gate BBS.
- **Registered names** — the accounts are the network's (rubbs `Rubbs::Common::Auth`, kept on TTG Gate BBS, the Central, asked through `central TTG::CENTRAL`): one name and password on every board. The splash (rubbs' `Rubbs::Common::Call::Splash`, from `TTG::PRESET`) asks *Login | Register | Guest* and logs the caller in through rubbs' profile; a guest comes in as Anonymous, and a caller who dialled the board from the gate signed in walks past the question. A guest can also register later (You > Register…, S then R on the C64): the account is made on the gate. The limits on wrong passwords and the look-alike names (a Cyrillic а for an a, an l or a 1 for an i: `Rubbs::Common::Auth::Names.skeleton`) are the gate's. `UI::Login` then puts the call on the board on both faces (a modern terminal that never reported its size is a scanner and is not listed). A caller who came in signed in is a member of the board (the `members` table: User Listing, *member since*). Profiles belong to registered names only. When the gate does not answer, a name comes in as a guest.
- **Sysop console** — the nodes, the last callers and how much new feedback waits on the Central, for an account with the **sysop** role; the feedback itself is read on the console of TTG Gate BBS.
- **Last callers** — a call is logged when it ends, and only if the terminal reported its window size (telnet NAWS) and stayed at least 10 seconds. Telnet password-guessing bots never get listed, and neither do they show up as online.
- **TTG Master** (F1, the desktop button, Help) — the sysop who answers callers' questions about the board; the menu also has ready questions. See *Characters* below.
- **Full screen** — the windows with much to read (Team, User Listing, Bulletins, Dev Log, Hall of Fame, the TTG Master) can fill the screen and go back: `F5`, `Alt-Enter`, the `[↑]` gadget or a double click on the title bar (rubbs' `maximizable`). The small info windows and dialogs cannot.
- **xterm mouse** — click menus, buttons, list items; wheel-scroll lists.
- **Idle disconnect** at 10 minutes.

### The C64 face

The board as the C64 boards had it (`lib/ui/petscii`), on a C64 terminal program
(CCGMS, StrikeTerm, SyncTERM in C64 mode), in two character sets. The
**pictures** are drawn in the uppercase/graphics set on rubbs'
`Rubbs::Petscii::Canvas`, raw PETSCII, the whole screen once and then only what
changes: the main menu, the town map, the games
room, the trophy case, the room cards and leaving. The **reading screens**
(the wall, the letters to the sysop, bulletins, the Master) stay in the lowercase set of
`Rubbs::Petscii::Screen`; the board switches to it (`0x0e`) before each.

The main menu is the clubhouse (`UI::Petscii::Clubhouse::MainMenu`): the house
of the time of day, lit from the same scene as the modern face (a reversed
yellow window for each node, the caller's white, the door, the smoke puffing
after a fresh note on the wall, for a sysop the mailbox flag and the number of
new letters to the sysops), who is
calling and what comes next, and the rooms as a cursor menu on the picture
(`Rubbs::Petscii::CanvasMenu`), each in the colour of its part of the board:

```
 TTG BBS CLUBHOUSE         NODE 2  21:47
 [the sign]     [the house, lit]   [box]
 HI TASI!                     3 INSIDE
 NEXT: TTG GAME JAM IN 3 DAYS
 ╭────────────────────────────────────╮
 │ M CORK BOARD      S YOU            │
 │ E MAILBOX         R GAMES ROOM     │
 │ P RING THE BELL   N TOWN MAP       │
 │ U NOTICE BOARD    T ASK THE BAR    │
 │ D WORKSHOP        Q LEAVE          │
 │ C GUESTBOOK                        │
 │ H TROPHIES                         │
 │ V BALLOT BOX                       │
 │ THE WALL: PIN A NOTE, ANSWER ONE   │
 ╰────────────────────────────────────╯
 CRSR RETURN  ?:HELP  Y:INFO  *:TEXT
```

CRSR moves the bar (left and right to the column beside), RETURN opens the lit
room, the letter in front of it opens it at once; `?` is the help, `Y` the
system info, `Z` the sysop console. A reading room shows its card once a call
(the cork board, the mailbox, the notice board, the workshop, the guestbook),
any key goes in. `M` opens the wall, `E` a letter to the sysop, `P` rings the
bell and opens one of the kind *page* (see *Messages* below). `N` is the town map: the boards of the network as
3×3 buildings, CRSR walks between them, under the map the name, two words and
the port. `R` is the games room: the five stations with their lamps; the C64
and the Plus/4 open, SERMO, Ra and Trivia are on the modern face. `H` is the
trophy case, `Q` puts the four lamps out one by one before `NO CARRIER`.

`*` swaps the pictures for the old menu of plain text in the lowercase set, and
back. A caller whose name comes in capitals gets the text menu at once:
UltimateTerm (the C64 Ultimate's terminal) in its ANSI mode swaps the case of
what is typed and cannot show the graphics (no CLR, swapped letters).

```
 TELETYPE BBS              node 2 13:32
 hi tasi! · 3 on line
 ──────────────────────────────────────
 [messages] ───────  [board] ───────────
 M the wall         U bulletins
 E write the sysop  D dev log
 …
```

Lists are numbered cursor menus: CRSR or the number typed lights one, RETURN
opens it, CRSR left and right turn the pages, `Q` or `←` (RUN/STOP too) goes
back. Long texts stop at every screenful. Every line is typed in a field of
rubbs (`Rubbs::Common::Screens::Field`: the cursor keys move in it, DEL
deletes, RETURN ends it, RUN/STOP or `←` goes back); notes and letters are
written in its full-screen editor (`Rubbs::Common::Screens::Editor`):
RUN/STOP or `←`, then `S` sends them, `Q` drops them. Bulletins are the same
Markdown, rendered 38 columns wide.

The screen is rubbs' PETSCII line (`session.petscii!`, see the rubbs README):
the PETSCII face writes UTF-8 with ANSI colours, and the line makes PETSCII of it,
so the shared parts (Markdown, the doors' FakeOS) work there unchanged.

## Messages

What callers write each other and the sysops is the network's: it lives on
TTG Gate BBS, the Central (ttg-common `TTG::Wall` and `TTG::Feedback`, reached
through `central TTG::CENTRAL`), and the board opens its screens, the same
line-by-line screen on both faces, in its own words: `lib/content/wall.yml`
and `lib/content/feedback.yml` over ttg-common's defaults (shorter C64 texts
under `petscii:`; a key ttg-common does not know stops the board at boot).
On the modern face they take the whole screen and give the desktop back.

- **The Wall** (Messages > The Wall…, F2; `M` on the C64, the cork board) —
  this board's wall: a note of up to 500 characters, or an answer to one (one
  level). An account writes under its name, a guest under a name of their own
  that is no account's, marked *(guest)*; the limits, a note taken off and a
  guest's line barred are the Central's. The newest notes run along the
  bottom of the dashboard, a fresh one makes the chimney smoke, the logon
  bulletin lists five and the trophy case counts them (`WallService`: the
  newest hundred, asked of the Central at most every 30 seconds; an empty wall
  while it does not answer). Every board of the network reads it from the
  gate too.
- **Feedback** (Messages > Feedback…, F7; `E` on the C64, the mailbox) — a
  letter to the sysops of the network, of a kind of `lib/content/feedback.yml`:
  a word, something broken, an idea; a guest may write too, with a name or
  without. The sysops read it here — You › Sysop Feedback… on a modern
  terminal, `F` in the C64's Sysop Console, *Feedback desk* in a sysop's
  profile on any board (ttg-common `TTG::Feedback.desk`: the new ones first,
  read, done, spam, unread again, delete) — or on the console of TTG Gate
  BBS; Discord hears
  only that one came (the board, the kind, the sender), never what it says.
  A sysop sees how many are new on the mailbox flag of the house, on the
  notice board and in the Sysop Console (`FeedbackCounter`, at most every 30
  seconds).
- **Page the Sysop…** (`P` on the C64, the bell) — the bell rings on the
  caller's terminal, then the same screen with the kind *page*: a line on
  what the caller needs, which the sysops find with the rest.

The message boards, the oneliners, the mail between names, the live chat, the
IRC window, the sysop's broadcast and the board's own Discord feed are gone
(2026-11-06). What was written before is handed over once by the background
job `export` (`ExportService`): the posts of the boards and the oneliners go to
this board's wall in the order they were written, a post with its board's
name before it (`[Tech] …`) and at its full length; the letters to `Sysop`
go to the feedback, read already. A post's stamp has no year, so the years
are counted back from the newest. Every row handed over is marked
(`exported_at`, step 3 of the schema), so a restart hands over only what is
left; while the Central does not take them the job tries again, its pause
doubling up to an hour. The letters between names are not handed over: they
stay in the database, as the archive.

## The clubhouse

The look of the board is a clubhouse: not a library and not a store (those
are the other buildings of the town), but the place where a caller sits down,
sees who is in, leaves a note and plays a game at the
back. Every big picture has something drawn from the board's own data, the
same on both faces (`SceneService` → `SceneModel`): nothing is asked of the
outside world but the board's wall and, for a sysop, the count of new
feedback on the Central (each at most every 30 seconds), and the town map is
static.

| Menu (modern) | Room (C64 key) | Live in the picture |
|---|---|---|
| Board > Dashboard | the clubhouse from the street | a lit window a node, the door and lamp, chimney smoke (a note on the wall in the last five minutes), for a sysop the mailbox flag and the count of new feedback, the graffiti wall (the newest notes) running under the house |
| Messages > The Wall… | the cork board (M) | — (the wall on the whole screen) |
| Messages > Feedback… | the mailbox (E) | the flag on the mailbox outside, for a sysop |
| Messages > Page the Sysop… | the bell (P) | — |
| Messages > Voting Booth | the ballot box (V) | — |
| People > Who is Online, Last Callers | the guestbook (C) | — |
| People > Hall of Fame | the trophy case (H) | the names on the cups |
| Board > Bulletins…, Dev Log | the notice board (U), the workshop (D) | — |
| Board > BBS Network | the town map (N) | static |
| Doors > Games Room… | the games room (R) | a lamp over each station in use |
| Help > Ask the TTG Master | the bar (T) | — |
| Log off | leaving (Q) | the lamps go out, the coat ticket with the time on line |

**The pictures** are `Rubbs::Common::Art` YAML (rubbs 0.30): a grid of characters, a
grid of palette letters, optional backgrounds (cp437) or reversed cells
(PETSCII), and hotspots, the cells the board fills from its data. Each is drawn
twice, separately for each machine, under `lib/content/art/`: `modern/` in code
page 437 and 256 colours, 80 columns wide; `c64/` in the C64's
uppercase/graphics set, 40 wide. `UI::Arts` loads and keeps them.

| Art | Modern | C64 |
|---|---|---|
| the sign | `logo.yml` 33×8 | `logo.yml` 40×8 |
| the clubhouse, by time of day | `house_{dawn,day,dusk,night}.yml` 80×12 | `house_*.yml` 40×10 |
| its season layers | `{snow,pumpkin,fireworks,bunting}_<time>.yml` | the same |
| the town and its buildings | `town.yml` 76×23, `building_<id>.yml` 12×4 | `town.yml` 40×21, `building_<id>.yml` 3×3 |
| the games room | `games_room.yml` 76×12 | `games_room.yml` 40×11 |
| the trophy case | `trophies.yml` 76×10 | `trophies.yml` 40×9 |
| the room cards | `card_{cork,mailbox,notice,workshop,guestbook}.yml` 80×5 (the cork board and the mailbox open on the whole screen, so the desktop shows theirs no more) | the same, 40×6 |
| leaving | `leaving.yml` 80×14 + `leaving_out_1..4.yml` | `leaving.yml` 40×13 + `leaving_out_1..4.yml` |

The time of day and the layers come from `Rubbs::Common::Season` (Budapest): snow from
December to February, pumpkins on 24–31 October, fireworks on 31 December and
New Year's night, bunting on the days of a game jam (an event of the site with
*jam* in its name, `SiteService#jam`). A layer is drawn for each time of day,
so it keeps the sky behind it.

To draw or change a picture, check it with rubbs' `art-preview` (ANSI on the
terminal, the PETSCII bytes, a C64 screenshot with VICE's character ROM):

```bash
bundle exec art-preview lib/content/art/c64/house_night.yml -l snow_night -s
bundle exec art-preview lib/content/art/c64/town.yml --png town.png
```

**The town map** reads `lib/content/network.yml`: the clubhouse and every other
board with its id, name, port, building, a line about it, a short name and two
words for the C64, its bbsweb accent colour and C64 colour, and where its
building stands on each map. It is kept in step by hand with TTG Gate BBS's
`config/boards.yml` and the bbsweb cards. A new board: a row there, and its two
buildings, `modern/building_<id>.yml` and `c64/building_<id>.yml`. The town has four
rows of four plots (the clubhouse takes the middle two of the second); the fourth row
has one free plot, `[60, 18]` on the modern map and `[34, 16]` on the C64 one.

**The C64 line is slow**, so the pictures have budgets: the first screen at most
1.2 KB, a step of an animation at most 200 bytes, a room card about 300, a
frame of the lamps going out under 100. `bin/c64-bytes` measures them with a
worst-case scene (`docker exec teletype-bbs bin/c64-bytes`); with a folder it
writes the raw PETSCII of each screen too, to replay through a C64's CHROUT in
VICE. As measured (2026-11-06, thirteen rooms): the main menu 1099–1117 bytes
at every time of day and season, a move of its bar 146–205, a puff of smoke
about 60; the town map 1183 (four rows of the town since 2026-11-03), a step
171–239; the games room 770, a step 230–333 (it rewrites the station's
description); the trophy case 621; a room card 244–275; leaving 584, the lamps
out 29–78 each.

## Project structure

```
bbs.rb                                 entry point: the terminal question, then a face
lib/
  domain.rb                            loads the domain (and the doors and characters)
  domain/teletype_bbs.rb               the board: services wired to their stores, and
                                       what a call does across services (logon, the
                                       bulletin, statistics, the export); the only
                                       reader of the environment
  domain/teletype_doors.rb             the doors (DoorModel), in menu order
  domain/migrations.rb                 the schema of the SQLite file (MIGRATIONS)
  domain/model/                        a Rubbs::Common::Storage::Model (Sequel) for each table, its
                                       queries as class methods:
    member_model.rb                    the members: callers who came in signed in
    account_model.rb                   the board's own accounts of before (read by the gate's import)
    post_model.rb                      the message boards' posts of before (the archive)
    last_read_model.rb                 how far each name had read each board (the archive)
    call_model.rb                      finished calls and their statistics (SQL)
    oneliner_model.rb                  the oneliners of before (the archive)
    profile_model.rb                   per-user persistent profile
    trivia_score_model.rb              TTG Trivia's hall of fame
    vote_model.rb                      the voting booth's ballots
    letter_model.rb                    the mail of before (the archive, the mail table)
                                       and value objects (SceneModel, GameModel, …),
  domain/repository/
    online_users_repository.rb         the nodes: who, since when, doing what
    catalog_repository.rb              games API client (the doors, the Master)
    bulletin_repository.rb             the Markdown bulletins
    site_repository.rb                 teletypegames.org events + members
    ftp_repository.rb                  anonymous FTP: the file sizes of a folder
    gitea_repository.rb                public activity of the Gitea organisations
    network_repository.rb              the town map's boards (content/network.yml)
    http_json.rb                       JSON GET (Rubbs::Common::Web::HTTP) + Rubbs::Common::Storage::Cache
  domain/service/
    online_service.rb, games_service.rb, last_callers_service.rb,
    profile_service.rb, member_service.rb, site_service.rb,
    warp_sizes.rb, dev_log_service.rb, voting_service.rb,
    tagline_service.rb, network_service.rb
    wall_service.rb                    the board's wall on the Central, as the pictures
                                       read it (kept 30 seconds)
    feedback_counter.rb                the new feedback, for a sysop's mailbox flag
    export_service.rb                  the posts, oneliners and letters to the sysop
                                       of before, handed over to the Central once
    remote.rb                          a failed remote source: logged, an empty answer
    scene_service.rb                   what the clubhouse pictures show, for both
                                       faces (SceneModel)
  doors/commodore.rb                   the C64 and Plus/4 doors
  doors/commodore/basic.rb, basic/     their BASIC V2 interpreter (tokenizer,
                                       expressions, statements)
  doors/ra.rb                          Chat of Ra
  doors/trivia.rb                      TTG Trivia
  content/                             polls.yml, trivia.yml, taglines.yml,
                                       bulletins/*.md, network.yml (the town map),
                                       wall.yml and feedback.yml (what the wall and
                                       the letters to the sysop say)
  content/art/modern/, content/art/c64/ the clubhouse pictures (Rubbs::Common::Art YAML)
  characters/                          Ra and the TTG Master: personas, riddles,
                                       the Master's knowledge (modern and C64),
                                       eval questions, the shared model client
  ui/arts.rb                           loads and keeps the pictures (UI::Arts)
  ui/wording.rb                        what both faces say about the domain's answers
  ui/login.rb                          the start of a call on both faces (after the splash)
  ui/modern.rb                         the modern face: the Application (rubbs 2.0 DSL)
  ui/modern/helpers.rb                 the desktop's own methods (menus, buttons, tick)
  ui/modern/section.rb                 a part of the board: its windows' colour and sign
  ui/modern/windows/                   the windows, a Rubbs::Modern::Part per part of the board
  ui/modern/menus.rb                   the commands (F-keys) and the menubar
  ui/logo.rb                           the board's logo (TTG BBS, Rubbs::Common::Text::BlockFont) for both faces
  ui/modern/desktop.rb                 the dashboard (the clubhouse from the street),
                                       the colours and icons of the menus
  ui/modern/rooms.rb                   picture windows: the town map, the games room
  ui/modern/clubhouse.rb               leaving, the room cards,
                                       the trophy case
  ui/modern/formatters.rb              view helpers: bulletin, the wall's notes, events,
                                       doors, team, network, users, sysop,
                                       dev log, the Master's quick questions
  ui/modern/classic_formatters.rb      nodes, voting,
                                       bulletins, hall of fame
  ui/petscii.rb                        the PETSCII face (Rubbs::Petscii::Face): the main menu
  ui/petscii/leaving.rb                its goodbye
  ui/petscii/clubhouse.rb              its pictures: the main menu, the town map,
                                       the games room, trophies, cards, leaving
  ui/petscii/more.rb                   doors, Master, system info, help, sysop
  ui/petscii/messages.rb, content.rb,  its sections (messages.rb: the wall, the letters
                                       to the sysop, the bell; content.rb: bulletins,
                                       the network, dev log)
  ui/petscii/people.rb
bin/persona-eval                       count a character's slips over many runs
test/                                  minitest: the domain, the start of a call, BASIC,
                                       both faces on Rubbs::Test::Session
Rakefile                               bundle exec rake test
bin/c64-bytes                          the bytes of the C64 pictures on the line
data/
  teletype.sqlite3                     the board's database (TELETYPE_BBS_DB)
```

## Doors

A door is one entry of `TeletypeBBS#doors` (`lib/domain/teletype_doors.rb`), a `Rubbs::Common::Call::Door`:
its name, the program, the label with its hotkey, the narrowest screen it
draws for, optionally the same door drawn for 40 columns, and three texts:
`tag` (a few words for the C64's list), `hint` (the statusbar line of its menu
item) and `about` (its paragraph in the Door Lobby). The modern face declares
them all in its Application at boot (`UI::Modern.doors`), and its Doors menu
lists them by itself under the Door Lobby; the PETSCII face offers the ones of
40 columns and the ones with a C64 version (`petscii:`).

Only the programs that live here are doors: SERMO, the Commodore 64 and
Plus/4, Chat of Ra and TTG Trivia. The other boards of the network are no
doors here (no `Rubbs::Common::Line::Gateway`): TTG Gate BBS dials them.

```ruby
DoorModel.new(:c64, Commodore.os(Commodore::C64, games: games, sizes: sizes),
              label: '&Commodore 64', cols: 40, tag: 'c64 + our games',
              hint: 'A Commodore 64 at READY., with our C64 games on its disk: LOAD"$",8 lists them',
              about: 'A Commodore 64 at its READY. prompt, with a small BASIC V2. …'),
```

The program is a `Rubbs::Common::FakeOS` definition, a `Rubbs::Common::Call::Flow` or a callable `(session, context)`.
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
the `trivia_scores` table; the best ten are its hall of fame.

The `sermo` gem, like rubbs, is pinned to a revision in `Gemfile.lock`. After a change in sermo-bbs:

```bash
bundle lock --update sermo
```

then commit and redeploy.

### Sysop accounts

The accounts and their roles are kept on TTG Gate BBS; a sysop is an account
with the **sysop** role, given (or a password reset) on the gate's shell:

```bash
docker exec -it ttg-gate-bbs bin/account grant NAME sysop
docker exec -it ttg-gate-bbs bin/account password NAME
```

The board needs `RUBBS_AUTH_SECRET`, the secret every board shares, in its `.env`.

## Characters

Ra and the TTG Master talk through the shared model service (infra/llm,
Qwen3.5 0.8B), with rubbs' `Rubbs::Common::AI`. A model this small is good at a short
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
games". With the rooms of the clubhouse (2026-11-01: the Games Room, the
town map, the trophy case, and on the C64 a short fact for each room of the
main menu, with questions about them): the modern Master 16 slips in 99
replies (11 misses; 12 in 90 before), the C64 Master 21 in 99 (16 misses; 19
in 87 before); the new questions pass, the misses are the old ones. Woven into
the old facts ("M on the main menu, the Cork board, opens …") the room names
cost the small model its key phrases (33 slips in 99), so a room is a short
fact of its own. Ra, at the last tuning (2026-10-21): 1 slip in 48 replies.
To add a fact, add an entry to `master_knowledge.yml` (and its C64 twin) and
a question to the eval.

## Data

All persisted state lives under `data/` which is mounted as a volume in Docker
so it survives container restarts.

Everything the callers leave here is in one SQLite file, `data/teletype.sqlite3`
(WAL mode); the wall and the letters to the sysop are on the Central (see
*Messages*). Its schema is
`lib/domain/migrations.rb` (the steps are counted in `PRAGMA user_version`, so
a step is never changed, only added), declared in `TeletypeBBS` with rubbs'
`database` and read and written through a `Rubbs::Common::Storage::Model` (Sequel) for each
table in `lib/domain/model`, whose class methods are the queries: the
caller numbers, a name's calls, the top callers and the trivia
hall of fame are aggregates, not loops over the whole history. The server's
nightly backup copies every `data/*.sqlite3`.

The `accounts` table holds the board's own accounts from before the accounts
of the network (salted PBKDF2-SHA256): the board no longer writes it, TTG Gate
BBS imports them. Step 2 of the schema made the `members` table and brought
those names in with their sign-up dates. The `posts`, `last_read`,
`oneliners` and `mail` tables are the message boards, the oneliners and the
mail of before the network's wall and feedback: nothing writes them any more,
step 3 of the schema gave the first, the third and the fourth an
`exported_at` column (when a row was handed over to the Central; the letters
between names never are), and they stay as the archive. Anything else under
`data/` (such as `archive/`) is left alone.

## Tests

```bash
bundle exec rake test
```

Minitest, no network: the start of a call on a throwaway directory of accounts
(`Rubbs::Test.accounts`: a caller signed in at the gate, a guest, a scanner),
stepping through a door, registration, the sysop role, the SQL statistics,
the chimney smoke and the mailbox flag from the wall and the feedback, the
export of before on a Central of the test's own (`Rubbs::Common::Central::Server`
with ttg-common's wall and feedback: once, in order, in requests the Central
takes, nothing marked while it is away), and the BASIC interpreter of the
Commodore doors. CI runs them with RuboCop before a deploy.
