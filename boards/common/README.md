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

ttg-common lives in the TTG BBS repository (`bbs/ttg-bbs`, `boards/common`), beside the boards that
use it: they take it by path from the repository's `Gemfile`, so a change here reaches every board in
the same commit. The repository's `Gemfile.lock` pins the rubbs revision of all of them.

## What is in it

| Module | What | Used by |
|--------|------|---------|
| `TTG::PRESET` | The `Rubbs::Common::Board::Preset` of every board: the logo splash, teletypegames.org and its QR code on the goodbye, the User-Agent, the small TTG mark over the profile (`Rubbs::Common::Auth::Profile`) | every board (`preset TTG::PRESET`) |
| `ttg/rake` | `rake ttg:format` formats the code by the shared RuboCop rules (`rubocop -a`); the house rules of `rake bbs:check` (`TTG::Check`): `<slug>-bbs` in the folder `boards/<slug without -bbs>`, the board's entry in the repository's `boards.yml` (a 23xx `port`, `max_sessions`, `memory`), `.rubocop.yml` inheriting `lib/ttg/board/rubocop.yml` and an `env-example`, the preset, every setting in `env-example` | every board's Rakefile |
| `TTG::CENTRAL`, `TTG::Central` | The Central of the network (Rubbs::Common::Central): TTG Gate BBS keeps the accounts and the network's services; `TTG::CENTRAL` is a `Rubbs::Common::Central::Client` on it (`TTG_CENTRAL_URL`, default `http://ttg-gate-bbs:8090`; the older `TTG_AUTH_URL` still read); `rake bbs:check` wants `RUBBS_AUTH_SECRET` in the env-example of a board with `central` or `auth` | every board that asks the gate (`central TTG::CENTRAL`) |
| `TTG::AUTH`, `TTG::Auth` | The accounts of the network (Rubbs::Common::Auth): they live on TTG Gate BBS; `TTG::AUTH` is a `Rubbs::Common::Auth::Remote` on the Central (`TTG::CENTRAL`, path `/auth`), `TTG::Auth::ROLES` the roles (`member`, `sysop`, `blogger`, `wiki-supervisor`); `rake bbs:check` wants `RUBBS_AUTH_SECRET` in the env-example of a board with `auth` | every board with a login |
| `TTG::Feedback` | What callers send the sysops from any board (feedback, a bug, an idea, a page, a board's own kind: a feed to add, a game's debrief), a `Rubbs::Common::Central::Service` on the gate (`/feedback`, `data/feedback.sqlite3`): limits for accounts and guests, the sysops' ops (`list`, `read`, `mark`, `delete`, `counts`), `import` of a board's old box. The **only** Discord line of the network: that something came (board, kind, sender), never what it says (`TTG_GATE_BBS_FEEDBACK_WEBHOOK` on the gate). `TTG::Feedback.open(session, narrative:, context:, kind:)` is the screen on either face; `TTG::Feedback.desk(session)` the sysops' desk on either face (every board's feedback, the new ones first: read, done, spam, unread again, delete), in a sysop's profile on every board | every board |
| `TTG::Wall` | The wall of a board, where callers write and answer each other (`/wall`, `data/wall.sqlite3` on the gate): 500 characters a note, an answer names the note it answers (one level), an account under its name, a guest under a name that is no account's and looks like none, marked *(guest)*; limits for both; the sysop hides a note or bars a guest's line for a while. `TTG::Wall.open(session, board:)` (`board: nil`: every board's, the gate), `TTG::Wall.lines(n)` for a board's own screen, `import` of older notes | every board |
| `TTG::PrivateMessage` | Letters from account to account on the gate (`/messages`, `data/messages.sqlite3`): write, inbox, outbox, read, delete, unread, block; accounts only. `TTG::PrivateMessage.open(session)` is the mailbox on either face (the letters, new ones marked; read, reply, delete, block the writer; write in the full-screen editor; the sent letters), in the words of `lib/content/mail.yml`; `TTG::PrivateMessage.unread(session)` counts the letters not read yet. A letter is read on its sheet (`Stationery`: a frame with the network's red stamp, the writer, the reader, the day, the postmark of TTG MAIL) and a sent one goes into the pillar box in a little film | TTG Mail BBS |
| `TTG::Badges` | The network's badges on rubbs' `Rubbs::Common::Badges` (`docs/bbs/BADGES.md`): the network's own in `lib/ttg/badges/network.rb` (First Light, Tourist, Globetrotter, Regular, Night Owl, Commodore, Marathon, Graffiti, Pen Pal, the secret seasonal ones, Pioneer, Completionist …), each board's in its `badges.rb`. A board says `badges TTG::Badges.load(__dir__)` (its own and the network's; its folder is its name), the gate `badges TTG::Badges.load_all(__dir__)` and serves `TTG::Badges::Service` (`/badges`, `data/badges.sqlite3`), which at its start gives Pioneer to the accounts made before 8 November 2026 and turns the old notes, feedback and letters into events. *Badges* in every signed-in caller's profile (`TTG::Badges::Screen`: earned, on the way with how far, secret ones as ???, the Hall of Badges); the Wall, Feedback and the mailbox report `wall_note`, `feedback`, `letter` | every board |
| `TTG::Narrative` | What the screens of Feedback and the Wall say: their defaults, and the board's own over them (a Hash, or `lib/content/feedback.yml` / `wall.yml`), with shorter C64 texts under `petscii:` and the kinds of feedback, each with its own intro and fields. A key the defaults do not know is an error at boot | the boards that say it their own way |
| `TTG::Screen`, `TTG::Places` | The line-by-line screen the two draw on, the same on either face; `Places` puts *Feedback* and *The Wall* in every board's profile (`Rubbs::Common::Auth::Profile.extra`) when the board has `central` | every board |
| `TTG::Logo` | The Teletype Games logo as two `Rubbs::Common::Art` drawings (modern: 66×23 half blocks, 256 colours; C64: 33×23 quarter blocks) and as a `Rubbs::Common::Call::Splash` | every board (all twelve) |

### `TTG::Logo`

```ruby
Rubbs.board('Teletype BBS', TeletypeBBS) { preset TTG::PRESET; … }   # the splash comes with the preset
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
require 'rubbs/rake'
require 'ttg/rake'
Rubbs::Rake.board
```

`rake bbs:check` (and `rake`, in CI) then also checks the TTG house rules
(`lib/ttg/check.rb`).

### The shared RuboCop rules

Every board's `.rubocop.yml` inherits `lib/ttg/board/rubocop.yml`
(`inherit_gem: { ttg-common: lib/ttg/board/rubocop.yml }`) and adds its own exceptions after it.

The shared RuboCop rules are also the formatter: what fits on a line (130) stays on one, a call, definition or hash that
does not gets one argument, parameter or key a line with the closing bracket on its own line, the keys lined up as a
table (the same layout rules as rubbs'). `rake ttg:format` applies them; ruby-lsp in the editor formats on save with
the same rules.

How the boards run (one image, `Rubbs::MultiRunner`, JSON logs, the health probe, the deploy that restarts only the
boards that changed) is the repository's README.
