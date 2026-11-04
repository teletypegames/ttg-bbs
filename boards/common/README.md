# ttg-common

The shared parts of the Teletype Games BBS boards, on top of
[rubbs](https://git.teletypegames.org/engines/rubbs) (the `bbs` gem). Something
goes here when more than one TTG board needs it but it is too TTG-specific for
rubbs itself: a logo, a house text, a list of the network's boards.

## Using it

```ruby
# Gemfile
gem 'bbs', git: 'https://git.teletypegames.org/engines/rubbs.git'
gem 'ttg-common', git: 'https://git.teletypegames.org/bbs/common.git'
```

```ruby
require 'ttg/common'
```

The board's `Gemfile.lock` pins a revision; `devarea/scripts/bbs-lock-bump.sh`
moves every board to the latest rubbs and ttg-common together.

## What is in it

| Module | What | Used by |
|--------|------|---------|
| `TTG::PRESET` | The `BBS::Preset` of every board: the logo splash, teletypegames.org and its QR code on the goodbye, the User-Agent | every board (`preset TTG::PRESET`) |
| `ttg/rake` | `rake ttg:sync` (`TTG::Sync`) writes the shared Dockerfile, .dockerignore and .woodpecker.yaml from `lib/ttg/board/`; `rake ttg:format` formats the code by the shared RuboCop rules (`rubocop -a`); the house rules of `rake bbs:check` (`TTG::Check`): `<slug>-bbs`, those files as synced, `.rubocop.yml` inheriting `lib/ttg/board/rubocop.yml`, compose limits, `stop_grace_period` and one 23xx port (another service built from the board's image, like the gate's prober, turns the image's healthcheck and autoheal label off), the preset, every setting in `env-example` | every board's Rakefile |
| `TTG::AUTH`, `TTG::Auth` | The accounts of the network (BBS::Auth): they live on TTG Gate BBS; `TTG::AUTH` is a `BBS::Auth::Remote` on its API (`TTG_AUTH_URL`, default `http://ttg-gate-bbs:8090/auth`), `TTG::Auth::ROLES` the roles (`member`, `sysop`, `blogger`, `wiki-supervisor`); `rake bbs:check` wants `RUBBS_AUTH_SECRET` in the env-example of a board with `auth` | every board with a login |
| `TTG::Logo` | The Teletype Games logo as two `BBS::Art` drawings (modern: 66×23 half blocks, 256 colours; C64: 33×23 quarter blocks) and as a `BBS::Splash` | every board (all twelve) |

### `TTG::Logo`

```ruby
BBS.board('Teletype BBS', TeletypeBBS) { preset TTG::PRESET; … }   # the splash comes with the preset
```

After the terminal question the caller gets the logo, centred, with
PRESS ANY KEY TO CONTINUE under it. `TTG::Logo.art(:modern)` and
`TTG::Logo.art(:petscii)` are the drawings alone, for a board that places the
logo itself. The drawings (`lib/ttg/logo/*.yml`) were made from
`media/LOGOv2/TTG-Logo-Black.png`, the logo halved to 66×46 pixels.

## Adding a part

One module under `TTG` in its own file (`lib/ttg/<part>.rb`, its data beside it
in `lib/ttg/<part>/`), required from `lib/ttg/common.rb`, with a test and a row
in the table above. Everything is RDoc-documented (CI fails below 100%).

## Releasing

Bump `ttg-common.gemspec`, commit, tag `vX.Y.Z` (annotated) and push both; CI
rejects a tag that does not match the gemspec.

### The house rules: `ttg/rake`

```ruby
# Rakefile of every TTG board
require 'bbs/rake'
require 'ttg/rake'
BBS::Rake.board
```

`rake bbs:check` (and `rake`, in CI) then also checks the TTG house rules
(`lib/ttg/check.rb`).

### The shared files: `rake ttg:sync`

What every board has the same lives in `lib/ttg/board/`, and `rake ttg:sync`
writes it into the board:

| Template | In the board | Board's own part |
|---|---|---|
| `Dockerfile` | `Dockerfile` | packages added to the `apk add` line (kept) |
| `dockerignore` | `.dockerignore` | — |
| `woodpecker.yaml.erb` | `.woodpecker.yaml` | the name and the port (from `bbs.rb` and `compose.yaml`) |
| `rubocop.yml` | inherited, not copied | the board's `.rubocop.yml`: `inherit_gem: { ttg-common: lib/ttg/board/rubocop.yml }` and its own exceptions after it |

The shared RuboCop rules are also the formatter: what fits on a line (130) stays on one, a call, definition or hash that
does not gets one argument, parameter or key a line with the closing bracket on its own line, the keys lined up as a
table (the same layout rules as rubbs'). `rake ttg:format` applies them; ruby-lsp in the editor formats on save with
the same rules.

The Dockerfile runs the board with JSON logs (`BBS_LOG_FORMAT=json`), 20
seconds for its callers when it stops (`BBS_SHUTDOWN_SECONDS=20`; the compose
service sets `stop_grace_period: 30s`), a `HEALTHCHECK` on rubbs' health probe
and the `org.teletypegames.autoheal=true` label: the server's `docker-autoheal`
cron restarts a board that stays unhealthy, and `ci-deploy` waits until a new
one is healthy (infra/host-config).

A change for every board: edit the template, release ttg-common, then in each
board bump the lock, `rake ttg:sync`, commit. `rake bbs:check` fails in a board
whose files differ from its ttg-common's.
