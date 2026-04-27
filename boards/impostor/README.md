# Impostor BBS

A telnet-accessible BBS (Bulletin Board System) server that serves as the post-game debrief terminal for **Definitely not an Impostor** — a puzzle/ARG experience. Players who complete the game receive a personal code; this server validates that code and reveals what comes next.

## How it works

When a player connects, the server asks for their player name and their personal code. The code is decrypted using a salt-based algorithm (ported from `logic.codegenerator.lua`) and checked against the name. A correct code unlocks a short identity confirmation sequence, followed by a congratulations screen, a feedback prompt, and an optional newsletter sign-up.

Every session — successful or not — is recorded in `data/sessions.csv` with a unique session ID, timestamp, player name, and code. Feedback and email are added to the same row as the conversation progresses.

## Running

**With Docker Compose (recommended):**

```bash
docker compose up --build
```

**Directly (requires Ruby 3.x):**

```bash
ruby bbs.rb
```

Connect with:

```bash
telnet localhost 2323
```

The port can be changed via the `BBS_PORT` environment variable.

## Project structure

```
bbs.rb                        Entry point — requires and starts the server
bbs/
  server.rb                   TCP accept loop, spawns one thread per client
  session.rb                  Negotiates telnet options, runs the flow
  telnet.rb                   Telnet protocol module (IAC handling, echo, readline)
  flow.rb                     Conversation DSL — Flow.define { ... }
  flow_runner.rb              Executes a Flow step by step
  flows/
    debrief.rb                The full debrief conversation, defined with the DSL
  store.rb                    Thread-safe CSV persistence (upsert by session ID)
  renderer.rb                 ERB template loader with ANSI colour helpers
  code_generator.rb           Decrypt/encrypt logic (Ruby port of the Lua original)
  templates/
    welcome.erb               Welcome screen
    congrats.erb              Mission complete screen
```

## Extending the conversation

The entire dialogue lives in `bbs/flows/debrief.rb` as a declarative DSL. Adding a new question is one line:

```ruby
ask :favourite_character, prompt: "Who was your favourite character?"
persist :favourite_character
```

Available DSL primitives:

| Primitive | Description |
|---|---|
| `screen :name` | Render an ERB template from `bbs/templates/` |
| `ask :field, prompt:, transform:, validate:` | Read a line of input and store it in the context |
| `persist :field, ...` | Write the named context fields to the CSV row |
| `pause "message", seconds:` | Display a status message and sleep |
| `gate denied: "..."  { \|ctx\| bool }` | Halt the flow unless the block returns true |
| `confirm "message", denied: "..."` | Yes/no gate — halts on no |
| `confirm "message", denied: "..." { }` | Yes/no branch — runs the block on yes, skips on no |
| `say "text", style:` | Print a styled message (`:success`, `:muted`, `:error`, `:info`) |

New templates go in `bbs/templates/`; they have access to ANSI colour helpers (`<%= green %>`, `<%= yellow %>`, `<%= reset %>`, etc.) and any context variable set by a preceding `ask` step.

## Data

Sessions are stored in `data/sessions.csv` (created automatically):

```
session_id,timestamp,player_name,code,feedback,email
a3f1b2c4...,2026-04-28T10:00:00Z,NORMAN,2J5GFN,Great puzzle!,norman@example.com
```

Each row is created when the player submits their name and code, then updated in place as feedback and email are collected. Multiple sessions with the same player name are kept separate by their session ID.

When running via Docker Compose the `data/` directory is mounted as a volume so records survive container restarts.
