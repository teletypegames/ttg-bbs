# WIKI-BBS

The Teletype Games wiki over telnet — a [rubbs](https://git.teletypegames.org/engines/rubbs.git)-based
BBS that browses the Grav wiki live through its JSON API.

```
telnet localhost 2325
```

The wiki has two faces on one port. A call starts with one question: which
terminal is calling. The BBS guesses first — it waits up to 1.5 seconds for the
telnet answers, and a terminal reporting a window wider than 40 columns is a
modern one; 40 columns, or no answer at all (a C64 behind a WiFi modem speaks
plain TCP), is taken for a Commodore. `1` picks the modern terminal
(ANSI/xterm, 256 colours), `2` the C64 (PETSCII), and RETURN takes the pick or
the guess. Mouse reporting is switched on only after the choice. The question
is rubbs' `BBS::Terminal`; the faces: `lib/ui/modern.rb`, `lib/ui/petscii*`.

## The modern face

A full-screen Norton Commander-style two-pane browser: page tree on the left
(indented by route depth), the selected page rendered as ANSI markdown on the
right. The browser opens maximized — it fills the screen between the menubar
and the statusbar; F5 / Alt-Enter (or the `[↕]` gadget) turns it into a
window and back.

| Key | Action |
|---|---|
| Up/Down | Pick a page (detail reloads) |
| Tab | Move focus to the reader pane |
| PgUp/PgDn/Home/End | Scroll the reader |
| F2 | Reopen the browser |
| F5 / Alt-Enter | Window / full screen |
| F8 | Refresh the wiki index (clears the page cache) |
| F10 | Menubar |
| Alt-X / Esc | Quit / close window |

Pages marked `*` in the list are private (login-protected on the wiki).
Unlock them with **Wiki > Supervisor login** — the password comes from the
`SUPERVISOR_PASSWORD` env var. Locking back: same menu item, confirm.

Mouse works too (xterm SGR), including wheel scroll in both panes.

## The PETSCII face

PETSCII on a 40×25 screen. The same page tree, one level per screen as a
numbered list, a cursor menu of rubbs (`BBS::Selector`): a page with pages
under it is marked `>`, a private one `*`. CRSR moves the bar (left and right
turn the pages), the number typed lights a page, and RETURN opens it, or goes
down a level, where line 1 is the page itself; `Q` (or ←) goes back up. Pages are shown a screenful at a time
(RETURN: more, `Q`: back), with their public address at the end. On the top
level `S` is the supervisor login (again: lock back) and `R` re-reads the
index.

## Data source

Two endpoints on the Grav wiki (templates in
`themes/ttgwiki2/templates/*.json.twig`, pages in `pages/custom/`):

- `GET /custom/sitemap.json` — every routable page: `route`, `title`,
  `modified`, `updatedAt`, `tags`, `private` (true when the page or any
  ancestor has `access: site.login` in its frontmatter). Titles/routes only,
  no bodies.
- `GET /custom/page.json?route=/platforms/tic80[&token=...]` — one page: the
  above plus `markdown` (raw) and `html` (rendered). Private pages require
  `token` to match the wiki's `SUPERVISOR_PASSWORD`, otherwise
  `{"error": "forbidden"}`. Unknown route → `{"error": "not_found"}`.

The page index (`sitemap.json`) is loaded once at server boot and shared by
every session; **F8 / Wiki > Refresh index** (`R` on the C64) re-reads it for everyone. If the
wiki is down at boot (a stack deploy recreates grav at the same time), the BBS
still starts and retries the index every 10 seconds until it answers. Page bodies
are rendered with `BBS::Markdown` and cached for 5 minutes
(`WikiRepository::PAGE_TTL`).

Resizing the terminal mid-session re-lays-out the whole UI (rubbs re-runs
each open window's `relayout` on NAWS updates — rubbs rev `db8a97b`+). Pages flagged `private` (or
sitting under a private ancestor) are locked in the BBS until the caller
enters the supervisor password.

The lock is enforced server-side: the Grav entrypoint injects
`SUPERVISOR_PASSWORD` into `config.site.supervisor_password`, and the JSON
API refuses private page bodies without a matching `?token=`. The BBS sends
its own `SUPERVISOR_PASSWORD` as that token, so **the two services must share
the same value** (the compose file wires both from one variable). The older
`updates.json` / `pages.json` endpoints hide private bodies the same way
(`body=1` only includes them with a valid token).

## Running

### With the wiki's compose (recommended)

The service is part of the repo root `docker-compose.yml`:

```bash
docker compose up --build    # from the wiki-pages root
telnet localhost 2325
```

It reaches Grav as `http://grav` on the compose network.

### Standalone, local dev

```bash
cd bbs
WIKI_URL=http://localhost:9120 bundle exec ruby wiki.rb
telnet localhost 2323
```

### Environment

| Var | Default | Purpose |
|---|---|---|
| `BBS_PORT` | `2323` | Telnet listen port |
| `BBS_MAX_SESSIONS` | `100` | Callers at once (the compose file sets 50) |
| `BBS_IDLE` | `900` | Idle disconnect (seconds) |
| `WIKI_URL` | `http://localhost:9120` | Grav wiki base URL |
| `SUPERVISOR_PASSWORD` | — | Unlocks private pages (Wiki > Supervisor login) and is sent to the wiki as the API token — must match the grav service's value; empty = private pages stay locked |

`env-example` lists them all with their defaults. `WikiBBS`
(`lib/domain/wiki_bbs.rb`) is the one place that reads them, apart from
`BBS_PORT` and `BBS_MAX_SESSIONS`, which rubbs reads itself.

`entrypoint.sh` runs `bundle update bbs` on container start, so the BBS
always boots with the latest rubbs revision.

## Project structure

```
wiki.rb                       Entry point: one WikiBBS, its index loading, BBS::Terminal with the two faces
Gemfile, Gemfile.lock         rubbs from git, rubocop in :development
entrypoint.sh                 Updates rubbs, then starts wiki.rb
Dockerfile, .dockerignore     The image; the root docker-compose.yml builds it as wiki-bbs
.rubocop.yml                  The house RuboCop rules; CI lints bbs/ (root .woodpecker.yaml)
env-example                   Every environment variable, with its default
lib/
  domain.rb                   Requires the domain in dependency order
  domain/
    model/page_model.rb       PageModel: one entry of the page index
    repository/wiki_repository.rb   WikiRepository: the JSON API, the page cache
    service/wiki_service.rb   WikiService: the shared index, private flags, pages as markdown
    service/supervisor_service.rb   SupervisorService: the supervisor password
    wiki_bbs.rb               WikiBBS: the composition root, reads ENV
  ui/
    modern.rb                 UI::Modern: the two-pane browser on an ANSI terminal
    petscii.rb                UI::Petscii: the C64 face, its masthead and goodbye
    petscii/screen.rb         UI::Petscii::Screen: rubbs' BBS::Petscii::Screen, back key n
    petscii/browser.rb        UI::Petscii::Browser: the page tree as cursor menus
```

## Licence

MIT, see `LICENSE`. It covers this folder only: the rest of the wiki-pages
repository has no licence of its own (Grav's in `core/` is Grav's).
