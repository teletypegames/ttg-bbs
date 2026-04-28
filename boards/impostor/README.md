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
bbs.rb                        Entry point — server definition and start
lib/
  code_generator.rb           Decrypt/encrypt logic (Ruby port of the Lua original)
  bbs.rb                      (internal) library loader
screens/
  welcome.erb                 Welcome screen
  congrats.erb                Mission complete screen
data/
  sessions.csv                Player session records (auto-created)
gems/
  bbs/
    bbs.gemspec
    lib/
      bbs/
        config.rb             Configuration object (screens_dir, flow, stores)
        server.rb             TCP accept loop, spawns one thread per client
        session.rb            Negotiates telnet options, runs the flow
        telnet.rb             Telnet protocol module (IAC handling, echo, readline)
        flow.rb               Conversation DSL — Flow.define { ... }
        flow_runner.rb        Executes a Flow step by step
        banner.rb             ASCII box-drawing banner renderer
        renderer.rb           ERB screen loader with ANSI colour helpers
        store.rb              Thread-safe CSV persistence (upsert by session ID)
```

## Flow DSL

The entire dialogue is defined in `bbs.rb` as a declarative `BBS::Flow.define` block. The server configuration (screens directory, stores, flow) lives in a `BBS.configure` block above it.

### Primitives

| Primitive | Description |
|---|---|
| `screen :name, **vars` | Render an ERB screen from `screens/`; vars override/extend the context |
| `banner "text", style:` | Print a box-drawing ASCII banner (styles: `:success`, `:info`, `:error`, …) |
| `big_banner "text", style:, font:` | Print a large FIGlet ASCII-art banner (default font: `slant`) |
| `say "text", style:` | Print a single styled line |
| `ask :field, prompt:, transform:, validate:` | Read input and store it in the context |
| `set :field, value` | Set a context variable directly from code |
| `persist :field, …, store:` | Write the named context fields to a `BBS::Store` |
| `pause "message", seconds:` | Display a status message and sleep |
| `gate denied: "…" { \|ctx\| bool }` | Halt the flow unless the block returns true |
| `confirm "message", denied: "…"` | Yes/no gate — halts on no |
| `confirm "message", denied: "…" { }` | Yes/no branch — runs the block on yes, skips on no |
| `menu "prompt", loop: bool { }` | Numbered option menu; loops back after each selection when `loop: true` |
| `exit_menu` | Break out of the enclosing `menu` loop and continue the parent flow |

### Menu example

```ruby
menu ">", loop: true do
  option "Leave feedback" do
    ask :feedback, prompt: "Feedback"
    persist :feedback, store: sessions
    say "Recorded. Thank you.", style: :success
    # completes normally → menu is shown again
  end

  option "Exit" do
    exit_menu   # breaks the loop, flow continues after menu
  end
end

say "Goodbye!", style: :muted   # reached after exit_menu
```

### Screens

ERB files in `screens/` have access to ANSI colour helpers and a `banner` helper:

```erb
<%= banner("MISSION COMPLETE") %>

  <%= white %>Congratulations!<%= reset %> You defeated <%= yellow %>"<%= @game_name %>"<%= reset %>.
```

Variables set by `ask`, `set`, or passed explicitly to `screen` are available as `@field` in the template.

### Stores

Each `persist` step writes to a `BBS::Store` instance. Multiple stores can coexist — one per CSV file:

```ruby
identities = BBS::Store.new(path: 'data/identities.csv', headers: %w[session_id timestamp name code])
signups    = BBS::Store.new(path: 'data/signups.csv',    headers: %w[session_id timestamp email])

persist :name, :code, store: identities
persist :email,       store: signups
```

`session_id` and `timestamp` are always written automatically.

## Data

Sessions are stored in `data/sessions.csv` (created automatically):

```
session_id,timestamp,player_name,code,feedback,email
a3f1b2c4...,2026-04-28T10:00:00Z,NORMAN,2J5GFN,Great puzzle!,norman@example.com
```

Each row is created when the player submits their name and code, then updated in place as feedback and email are collected. Multiple sessions with the same player name are kept separate by their session ID.

When running via Docker Compose the `data/` directory is mounted as a volume so records survive container restarts.
