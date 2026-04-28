# Impostor BBS

A telnet-accessible BBS (Bulletin Board System) server that serves as the post-game debrief terminal for **Definitely not an Impostor** — a puzzle/ARG experience. Players who complete the game receive a personal code; this server validates that code and reveals what comes next.

## How it works

When a player connects, the server asks for their player name and their personal code. The code is decrypted using a salt-based algorithm and checked against the name. A correct code unlocks a short identity confirmation sequence, followed by a congratulations screen and an interactive post-game menu for leaving feedback and signing up for updates.

Every session — successful or not — is recorded in `data/sessions.csv` with a unique session ID, timestamp, player name, and code. Feedback and email are added to the same row as the conversation progresses.

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

The port can be changed via the `BBS_PORT` environment variable (see `.env.example`).

## Project structure

```
bbs.rb                        Entry point — BBS config, flow definition, server start
lib/
  code_generator.rb           Decrypt/encrypt logic (Ruby port of the Lua original)
  bbs.rb                      (internal) library loader
screens/
  welcome.erb                 Welcome screen
  congrats.erb                Mission complete screen
data/
  sessions.csv                Player session records (auto-created)
```

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
