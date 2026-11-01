# Impostor BBS

A telnet-accessible BBS (Bulletin Board System) server that serves as the post-game debrief terminal for **Definitely not an Impostor** — a puzzle/ARG experience. Players who complete the game receive a personal code; this server validates that code and reveals what comes next.

## How it works

When a player connects, the server asks for their player name and their personal code. The code is decrypted using a salt-based algorithm and checked against the name. A correct code unlocks a short identity confirmation sequence, followed by a congratulations screen and an interactive post-game menu for leaving feedback and signing up for updates.

Every session — successful or not — is recorded in `data/sessions.sqlite3` with a unique session ID, timestamp, player name, and code. Feedback and email are added to the same row as the conversation progresses.

## Two terminals

A call starts with one question: which terminal is calling (rubbs'
`BBS::Terminal`, with a guess from the telnet answers as the default). `1`
picks a modern terminal (ANSI/xterm), `2` a Commodore 64 (PETSCII): the C64
gets the same terminal on 40 columns, with its own screens. The two faces are
two modules, `Impostor::Modern` and `Impostor::Petscii`, each with its screens in
`screens/modern/` and `screens/petscii/`. The board wraps them in `UI::Modern` and
`UI::Petscii`: when the debrief ends (or the code is refused), it thanks the caller
(rubbs' `BBS::Goodbye`, on a C64 with the IMPOSTOR logo in block letters) and hangs up
with NO CARRIER. A door gets only the gem's flows, so the host BBS keeps
the caller.

## Running

**With Docker Compose (recommended):**

```bash
docker compose up --build
```

**Directly (requires Ruby 3.x):**

```bash
bundle install
ruby bbs.rb
```

Connect with:

```bash
telnet localhost 2323
```

Docker Compose publishes it on port 2324 (`telnet localhost 2324`), the public port on the server. Run directly,
the port can be changed via the `BBS_PORT` environment variable. `env-example` lists every
variable with its default: `BBS_PORT`, `BBS_MAX_SESSIONS` and `IMPOSTOR_BBS_SESSIONS`, the sessions database.

## Tests

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

The repository is two things: the `impostor` gem (`lib/impostor*`, `screens/`), the debrief
terminal with its code check, and the standalone board around it. The board's own domain is
what a call leaves behind: `SessionModel` holds the rules of each field (no control characters,
length limits, an email only when it is a valid address), `SessionRepository` keeps the rows,
and `SessionService` is the store the gem's flow persists into, so every field passes the
rules before it is written.

```
bbs.rb                        Entry point: one ImpostorBBS, BBS::Terminal with the two faces
impostor.gemspec              The gem another rubbs BBS mounts as a door (lib/impostor*, screens/)
Gemfile, Gemfile.lock         rubbs from git; rubocop, minitest and rake in :development
Rakefile                      rake test
Dockerfile, .dockerignore, compose.yaml
.woodpecker.yaml, .rubocop.yml
env-example                   Every environment variable, with its default
bin/
  generate_code               CLI tool: generates a player's code from IMPOSTOR_BBS_PLAYER_NAME
lib/
  domain.rb                   Requires the gem, then the domain
  domain/impostor_bbs.rb      ImpostorBBS: the composition root, the only place that reads ENV
  domain/model/session_model.rb            SessionModel: one call, and the rules of its fields
  domain/repository/session_repository.rb  SessionRepository: the calls in SQLite (BBS::Store)
  domain/service/session_service.rb        SessionService: the store the gem's flow persists into
  ui/modern.rb                UI::Modern: the gem's modern face, then goodbye and NO CARRIER
  ui/petscii.rb               UI::Petscii: the gem's PETSCII face, then logo, goodbye and NO CARRIER
  ui/petscii/screen.rb        UI::Petscii::Screen: rubbs' C64 screen
  impostor.rb                 The gem: Impostor.debrief, the whole terminal as a BBS::Flow
  impostor/modern.rb          Impostor::Modern.flow(sessions:): the face for an ANSI terminal
  impostor/petscii.rb         Impostor::Petscii.flow(sessions:): the face for a C64, in PETSCII
  impostor/code_generator.rb  Decrypt/encrypt logic (Ruby port of the Lua original)
screens/
  modern/welcome.erb          Welcome screen
  modern/congrats.erb         Mission complete screen
  petscii/welcome.erb         The same two on 40 columns, for a C64
  petscii/congrats.erb
test/                         Minitest tests of the domain and the code generator
data/
  sessions.sqlite3            Player session records (auto-created, git-ignored)
```

## As a door

The same terminal is a door of the [Teletype BBS](https://git.teletypegames.org/bbs/teletype-bbs)
(Doors > Impostor). It pulls this repository as the `impostor` gem; the flow
carries its own screens (rubbs 0.7.0's `Flow.define(screens_dir:)`), and the
host BBS gives it a sessions store of its own:

```ruby
gem 'impostor', git: 'https://git.teletypegames.org/bbs/impostor-bbs.git'

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
rubbs' `BBS::Store`, one row a call:

```
session_id        timestamp             player_name  code    feedback       email
a3f1b2c4...       2026-04-28T10:00:00Z  NORMAN       2J5GFN  Great puzzle!  norman@example.com
```

Each row is created when the player submits their name and code, then updated in place as feedback and email are collected. Multiple sessions with the same player name are kept separate by their session ID. The email is the game's contact list and is kept as typed, but only when it is a valid address (printable, one `@`, a dotted domain, at most 254 characters); the other fields are cleaned of control characters and cut to a limit.

Earlier versions kept the sessions in `data/sessions.csv`. On the first start that file is imported into the database in one transaction and renamed to `data/sessions.csv.imported`.

`IMPOSTOR_BBS_SESSIONS` moves the database. When running via Docker Compose the `data/` directory is mounted as a volume so records survive container restarts.

## BBS engine

The server is built on the [rubbs](https://git.teletypegames.org/engines/rubbs) gem, which provides the telnet server, conversation flow DSL, screen renderer, and SQLite-backed store.
