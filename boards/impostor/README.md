# Impostor BBS

A telnet-accessible BBS (Bulletin Board System) server that serves as the post-game debrief terminal for **Definitely not an Impostor** — a puzzle/ARG experience. Players who complete the game receive a personal code; this server validates that code and reveals what comes next.

## How it works

When a player connects, the server asks for their player name and their personal code. The code is decrypted using a salt-based algorithm and checked against the name. A correct code unlocks a short identity confirmation sequence, followed by a congratulations screen and an interactive post-game menu: feedback on the game (the network's feedback box, ttg-common `TTG::Feedback`, kept on TTG Gate BBS and read on its sysop console), the survivors' wall (ttg-common `TTG::Wall`, a word for the next player) and signing up for updates. What the two screens say is in `lib/content/feedback.yml` and `lib/content/wall.yml`.

Every session — successful or not — is recorded in `data/sessions.sqlite3` with a unique session ID, timestamp, player name, and code. The email is added to the same row as the conversation goes on. The `feedback` column holds what players wrote before the network's feedback box; it is handed over to it once at boot (`feedback export`, then a `sessions.sqlite3.feedback-exported` marker beside the database).

## Two terminals

A call starts with one question: which terminal is calling (rubbs'
`Rubbs::Common::Call::Terminal`, with a guess from the telnet answers as the default). `1`
picks a modern terminal (ANSI/xterm), `2` a Commodore 64 (PETSCII): the C64
gets the same terminal on 40 columns, with its own screens. The two faces are
two modules, `Impostor::Modern` and `Impostor::Petscii`, each with its screens in
`screens/modern/` and `screens/petscii/`. The board runs each in a runner of its own (`UI.debrief`)
and, when the debrief ends (or the code is refused), thanks the caller
(rubbs' `Rubbs::Common::Call::Goodbye`, on a C64 with the IMPOSTOR logo in block letters) and hangs up
with NO CARRIER. A door gets only the gem's flows, so the host BBS keeps
the caller.

## Running

The board is `boards/impostor` of [TTG BBS](https://git.teletypegames.org/bbs/ttg-bbs) and runs
with the other boards in one container. From the repository root:

**With Docker Compose (recommended):**

```bash
docker compose up --build       # every board, this one on 2324
```

**Directly (requires Ruby 3.x):**

```bash
bundle install
bin/board impostor              # this board alone, on 2324 (boards.yml)
```

Connect with:

```bash
telnet localhost 2324
```

2324 is also the public port on the server. Run on its own (`cd boards/impostor && bundle exec
ruby bbs.rb`), it listens on `BBS_PORT`, 2323 by default. `env-example` lists every
variable with its default: `BBS_PORT`, `BBS_MAX_SESSIONS` and `IMPOSTOR_BBS_SESSIONS`, the sessions database.
Every log line (the board's and rubbs') starts with `impostor-bbs:` (rubbs' `Rubbs.log`, `log_tag`);
in the container they are in `docker logs ttg-bbs`, with `"board":"impostor-bbs"`. A push to master
of bbs/ttg-bbs deploys it (`ci-deploy ttg-bbs`, stack `/srv/stacks/ttg-bbs`); a change only in
`boards/impostor` restarts only this board.

## Tests

In `boards/impostor`:

```bash
bundle exec rake test
```

Minitest, no network: the session rules (cleaning, limits, email validation), the sessions
database with the import of a legacy CSV file, and the code generator. CI runs them before a deploy.

## Generating a code

To generate the personal code for a player name, use the CLI tool. It reads the name from the `IMPOSTOR_BBS_PLAYER_NAME` environment variable:

```bash
IMPOSTOR_BBS_PLAYER_NAME=norman bin/generate_code
# => 2J5GFN
```

The name is trimmed and uppercased (matching how the BBS handles input), and only its first 3 characters are encoded — so `NORMAN` and `NORBERT` produce the same code.

## Project structure

The folder is two things: the `impostor` gem (`lib/impostor*`, `screens/`), the debrief
terminal with its code check, and the standalone board around it. The board's own domain is
what a call leaves behind: `SessionModel` holds the rules of each field (no control characters,
length limits, an email only when it is a valid address), `SessionRepository` keeps the rows,
and `SessionService` is the store the gem's flow persists into, so every field passes the
rules before it is written.

```
bbs.rb                        Entry point: Rubbs.board with the two faces
impostor.gemspec              The gem another rubbs BBS mounts as a door (lib/impostor*, screens/)
Rakefile                      rake test
.rubocop.yml
env-example                   Every environment variable, with its default
bin/
  generate_code               CLI tool: generates a player's code from IMPOSTOR_BBS_PLAYER_NAME
lib/
  domain.rb                   Requires the gem, then the domain
  domain/impostor_bbs.rb      ImpostorBBS: the board's domain (Rubbs::Common::Board::Domain), its one setting and service
  domain/model/session_model.rb            SessionModel: one call, and the rules of its fields
  domain/repository/session_repository.rb  SessionRepository: the calls in SQLite (Rubbs::Common::Storage::Store)
  domain/service/session_service.rb        SessionService: the store the gem's flow persists into
  ui.rb                       UI: the debrief in a runner of its own, the goodbyes (on a C64 with the logo)
  impostor.rb                 The gem: Impostor.debrief, the whole terminal as a Rubbs::Common::Call::Flow
  impostor/modern.rb          Impostor::Modern.flow(sessions:): the face for an ANSI terminal
  impostor/petscii.rb         Impostor::Petscii.flow(sessions:): the face for a C64, in PETSCII
  impostor/code_generator.rb  Decrypt/encrypt logic (Ruby port of the Lua original)
screens/
  modern/welcome.erb          Welcome screen
  modern/congrats.erb         Mission complete screen
  petscii/welcome.erb         The same two on 40 columns, for a C64
  petscii/congrats.erb
test/                         Minitest tests of the domain, the code generator and the faces
data/
  sessions.sqlite3            Player session records (auto-created, git-ignored)
```

## As a door

The same terminal is a door of the [Teletype BBS](https://git.teletypegames.org/bbs/ttg-bbs/src/branch/master/boards/teletype)
(Doors > Impostor). It pulls this folder as the `impostor` gem; the flow
carries its own screens (rubbs 0.7.0's `Flow.define(screens_dir:)`), and the
host BBS gives it a sessions store of its own:

```ruby
gem 'impostor', git: 'https://git.teletypegames.org/bbs/ttg-bbs.git', glob: 'boards/impostor/impostor.gemspec'

require 'impostor'
sessions = Impostor.sessions_store('data/impostor_sessions.sqlite3')
door :impostor, Impostor::Modern.flow(sessions: sessions), label: '&Impostor'
# and for a C64 caller: Impostor::Petscii.flow(sessions: sessions)
```

When the flow ends, the door asks for ENTER and hands the caller back to the
BBS. The host's `Gemfile.lock` pins the revision, so a change here reaches the
door only with a bump there.

## Data

Sessions are stored in `data/sessions.sqlite3` (created automatically), in the table of
rubbs' `Rubbs::Common::Storage::Store`, one row a call:

```
session_id        timestamp             player_name  code    feedback       email
a3f1b2c4...       2026-04-28T10:00:00Z  NORMAN       2J5GFN  Great puzzle!  norman@example.com
```

Each row is created when the player submits their name and code, then updated in place as feedback and email are collected. Multiple sessions with the same player name are kept separate by their session ID. The email is the game's contact list and is kept as typed, but only when it is a valid address (printable, one `@`, a dotted domain, at most 254 characters); the other fields are cleaned of control characters and cut to a limit.

Earlier versions kept the sessions in `data/sessions.csv`. On the first start (the board opens the database at boot) that file is imported into the database in one transaction and renamed to `data/sessions.csv.imported`; lines that are no CSV row are set aside in `data/sessions.csv.rejected` and the good ones kept (rubbs' `Rubbs::Common::Storage::Store`).

`IMPOSTOR_BBS_SESSIONS` moves the database. When running via Docker Compose the `data/` directory is mounted as a volume (`/srv/stacks/ttg-bbs/boards/impostor/data` on the server) so records survive container restarts.

## BBS engine

The server is built on the [rubbs](https://git.teletypegames.org/engines/rubbs) gem, which provides the telnet server, conversation flow DSL, screen renderer, and SQLite-backed store.
