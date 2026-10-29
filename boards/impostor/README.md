# Impostor BBS

A telnet-accessible BBS (Bulletin Board System) server that serves as the post-game debrief terminal for **Definitely not an Impostor** — a puzzle/ARG experience. Players who complete the game receive a personal code; this server validates that code and reveals what comes next.

## How it works

When a player connects, the server asks for their player name and their personal code. The code is decrypted using a salt-based algorithm and checked against the name. A correct code unlocks a short identity confirmation sequence, followed by a congratulations screen and an interactive post-game menu for leaving feedback and signing up for updates.

Every session — successful or not — is recorded in `data/sessions.csv` with a unique session ID, timestamp, player name, and code. Feedback and email are added to the same row as the conversation progresses.

## Two terminals

A call starts with one question: which terminal is calling (rubbs'
`BBS::Terminal`, with a guess from the telnet answers as the default). `1`
picks a modern terminal (ANSI/xterm), `2` a Commodore 64 (PETSCII): the C64
gets the same terminal on 40 columns, with its own screens. The two faces are
two modules, `Impostor::Modern` and `Impostor::C64`, each with its screens in
`screens/modern/` and `screens/c64/`.

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
the port can be changed via the `BBS_PORT` environment variable (see `.env.example`).

## Generating a code

To generate the personal code for a player name, use the CLI tool. It reads the name from the `PLAYER_NAME` environment variable:

```bash
PLAYER_NAME=norman bin/generate_code
# => 2J5GFN
```

The name is trimmed and uppercased (matching how the BBS handles input), and only its first 3 characters are encoded — so `NORMAN` and `NORBERT` produce the same code.

## Project structure

```
bbs.rb                        Entry point — the standalone server: the flow + a sessions store
impostor.gemspec              The gem another rubbs BBS mounts as a door
bin/
  generate_code               CLI tool — generates a player's code from PLAYER_NAME
lib/
  impostor.rb                 Impostor.debrief — the whole terminal as a BBS::Flow, shared by the faces
  impostor/modern.rb          Impostor::Modern.flow(sessions:) — the face for an ANSI terminal
  impostor/c64.rb             Impostor::C64.flow(sessions:) — the face for a C64, in PETSCII
  impostor/code_generator.rb  Decrypt/encrypt logic (Ruby port of the Lua original)
screens/
  modern/welcome.erb          Welcome screen
  modern/congrats.erb         Mission complete screen
  c64/welcome.erb             The same two on 40 columns, for a C64
  c64/congrats.erb
data/
  sessions.csv                Player session records (auto-created)
```

## As a door

The same terminal is a door of the [Teletype BBS](https://git.teletypegames.org/bbs/bbs-server)
(Doors > Impostor). It pulls this repository as the `impostor` gem; the flow
carries its own screens (rubbs 0.7.0's `Flow.define(screens_dir:)`), and the
host BBS gives it a sessions store of its own:

```ruby
gem 'impostor', git: 'https://git.teletypegames.org/bbs/impostor-bbs.git'

require 'impostor'
sessions = Impostor.sessions_store('data/impostor_sessions.csv')
door :impostor, Impostor::Modern.flow(sessions: sessions), label: '&Impostor'
# and for a C64 caller: Impostor::C64.flow(sessions: sessions)
```

When the flow ends, the door asks for ENTER and hands the caller back to the
BBS. The host's `Gemfile.lock` pins the revision, so a change here reaches the
door only with a bump there.

## Data

Sessions are stored in `data/sessions.csv` (created automatically):

```
session_id,timestamp,player_name,code,feedback,email
a3f1b2c4...,2026-04-28T10:00:00Z,NORMAN,2J5GFN,Great puzzle!,norman@example.com
```

Each row is created when the player submits their name and code, then updated in place as feedback and email are collected. Multiple sessions with the same player name are kept separate by their session ID.

When running via Docker Compose the `data/` directory is mounted as a volume so records survive container restarts.

## BBS engine

The server is built on the [rubbs](https://git.teletype.hu/tools/rubbs) gem, which provides the telnet server, conversation flow DSL, screen renderer, and CSV store.
