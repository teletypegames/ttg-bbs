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
| `TTG::Logo` | The Teletype Games logo as two `BBS::Art` drawings (modern: 66×23 half blocks, 256 colours; C64: 33×23 quarter blocks) and as a `BBS::Splash` | every board (all twelve) |

### `TTG::Logo`

```ruby
config.flow = BBS::Terminal.flow(title: 'Teletype BBS', modern: m, petscii: p,
                                 splash: TTG::Logo.splash)
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
