# TTG Wiki BBS

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
is rubbs' `Rubbs::Common::Call::Terminal`; the faces: `lib/ui/modern.rb`, `lib/ui/petscii*`.

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
| F3 | QR code of the picked page (also **Wiki > Page QR code**) |
| F5 / Alt-Enter | Window / full screen |
| F8 | Refresh the wiki index (clears the page cache) |
| F10 | Menubar |
| Alt-X / Esc | Log off / close window |

Pages marked `*` in the list are private (login-protected on the wiki), for
the supervisors (see [Supervisors](#supervisors)): **Wiki > Profile** (on a
C64: P on the top level) to log in with a Teletype Games account, or out again.

The QR code (rubbs' `Rubbs::Common::Text::QR`, half blocks) is the page's address on the
web, `https://wiki.teletypegames.org<route>`, for a phone to open it with its
pictures and diagrams; a private page asks for the wiki's login there. It
takes the room the screen has: on 80×24 a route of up to 22 characters fits,
on 80×25 up to 47, on a taller screen more; one that does not fit gets a message
instead. The statusbar shows the number of pages indexed and the clock; **Help**
has About and Keys.

Mouse works too (xterm SGR), including wheel scroll in both panes.

## The PETSCII face

PETSCII on a 40×25 screen. The same page tree, one level per screen as a
numbered list, a cursor menu of rubbs (`Rubbs::Common::Screens::Selector`): a page with pages
under it is marked `>`, a private one `*`. CRSR moves the bar (left and right
turn the pages), the number typed lights a page, and RETURN opens it, or goes
down a level, where line 1 is the page itself; `Q` (or ←) goes back up. Pages are shown a screenful at a time
(RETURN: more, `Q`: back), with their public address at the end; under the
last screenful `C` (qr code) shows that address as a QR code (rubbs'
`Rubbs::Common::Text::QR`, quadrant blocks) for a phone to open the page on the web. On the top
level `L` logs in with a Teletype Games account (`O` logs out once in), and `R` re-reads the
index. A call ends with rubbs' goodbye screen: the time on line, the wiki's web address, the
Teletype Games address and its QR code.

## Data source

Two endpoints on the Grav wiki (templates in
`themes/ttgwiki2/templates/*.json.twig`, pages in `pages/custom/`):

- `GET /custom/sitemap.json` — every routable page: `route`, `title`,
  `modified`, `updatedAt`, `tags`, `private` (true when the page or any
  ancestor has `access: site.login` in its frontmatter). Titles/routes only,
  no bodies.
- `GET /custom/page.json?route=/platforms/tic80` (+ header `X-Wiki-Token`, or `&token=`) — one page: the
  above plus `markdown` (raw) and `html` (rendered). Private pages require
  `token` to match the wiki's `SUPERVISOR_PASSWORD`, otherwise
  `{"error": "forbidden"}`. Unknown route → `{"error": "not_found"}`.

The page index (`sitemap.json`) is loaded once at server boot and shared by
every session; **F8 / Wiki > Refresh index** (`R` on the C64) re-reads it for everyone. If the
wiki is down at boot (a stack deploy recreates grav at the same time), the BBS
still starts and retries the index in the background (rubbs' `Rubbs.background`)
until it answers: after 10 seconds, then twice as long each time, at most every
5 minutes. A caller may refresh twice a minute, the whole board ten times a
minute (rubbs' `Rubbs::Common::Line::RateLimit.allow_all?`, counted by the caller's address; a
refresh one limit refuses counts in neither), so nobody can hammer Grav with it.
The repository raises `WikiRepository::Error` (a network or HTTP error, an
answer that is no JSON); the wiki service logs it and words it for the caller. Page bodies are rendered with `Rubbs::Common::Text::Markdown` and cached for 5 minutes
(`WikiRepository::PAGE_TTL`) in a `Rubbs::Common::Storage::Cache` of at most 200 pages and 8 MiB.

Requests go through rubbs' `Rubbs::Common::Web::HTTP` (timeouts, a deadline, a body cap; the wiki is
on the Docker network, so `public_only: false`) with the board's User-Agent, and every
text from the wiki (titles, routes, tags, markdown) is cleaned of control characters
(`Rubbs::Common::Text.clean`) before it reaches a screen.

Resizing the terminal mid-session re-lays-out the whole UI (rubbs re-runs
each open window's `relayout` on NAWS updates — rubbs rev `db8a97b`+).

### Supervisors

Pages flagged `private` (or sitting under a private ancestor) are for the
supervisors: the accounts of the network (rubbs' `Rubbs::Common::Auth`, kept on TTG Gate
BBS, `auth TTG::AUTH, login: :menu`) with the `wiki-supervisor` role. A
supervisor logs in from the menu, or comes in logged in when dialled from TTG
Gate BBS; an account without the role is told it is not a supervisor, and the
private pages stay locked. The gate counts the wrong passwords. A sysop gives
the role on the gate:

```bash
docker exec -it ttg-gate-bbs bin/account grant NAME wiki-supervisor
```

The board asks the gate on the `interstack` network, signed with
`RUBBS_AUTH_SECRET`, the secret every board shares.

The lock is also enforced server-side: the Grav entrypoint injects
`SUPERVISOR_PASSWORD` into `config.site.supervisor_password`, and the JSON
API refuses private page bodies without a matching token (the `X-Wiki-Token`
header, or `?token=`). The BBS sends its own `WIKI_BBS_SUPERVISOR_PASSWORD` as
that token, for a supervisor's private pages only, in the header, so it stays
out of the wiki's access log. No caller types it: it is the board's API
credential, and **the two services must share the same value** (the compose
file wires both from one variable). The older
`updates.json` / `pages.json` endpoints hide private bodies the same way
(`body=1` only includes them with a valid token).

## Running

### On the server

Its own stack, `/srv/stacks/wiki-bbs` (`ci-deploy wiki-bbs`, a push to master deploys it). It
reaches the wiki's Grav as `http://wiki-grav` on the `interstack` network, an alias the
`services/wiki-pages` compose gives Grav. Until 2026-11-01 it lived in that repo as `bbs/`; this
repository keeps that folder's history.

```bash
docker compose up --build    # needs the interstack network and the wiki-pages stack
telnet localhost 2325
```

### Standalone, local dev

```bash
cd bbs
WIKI_BBS_URL=http://localhost:9120 bundle exec ruby bbs.rb
telnet localhost 2323
```

### Environment

| Var | Default | Purpose |
|---|---|---|
| `BBS_PORT` | `2323` | Telnet listen port |
| `BBS_MAX_SESSIONS` | `100` | Callers at once (the compose file sets 50) |
| `WIKI_BBS_IDLE` | `900` | Idle disconnect (seconds; the compose file sets 600) |
| `WIKI_BBS_URL` | `http://localhost:9120` | Grav wiki base URL |
| `WIKI_BBS_SUPERVISOR_PASSWORD` | — | The board's API token for the private pages (the `X-Wiki-Token` header), not a caller password — must match the grav service's `SUPERVISOR_PASSWORD`; empty = private pages stay locked |
| `RUBBS_AUTH_SECRET` | — | The secret every board of the network shares, for the accounts on TTG Gate BBS (in `.env` on the server) |

`env-example` lists them all with their defaults. `WikiBBS`
(`lib/domain/wiki_bbs.rb`) declares the `WIKI_BBS_` ones as `Rubbs::Common::Board::Domain`
settings; rubbs reads `BBS_PORT`, `BBS_MAX_SESSIONS` and `RUBBS_AUTH_SECRET` itself.

Every log line (the board's and rubbs') starts with `wiki-bbs:` (rubbs'
`Rubbs.log`, `log_tag`).

The image runs the rubbs revision of `Gemfile.lock`, as uid 1000; a new rubbs
reaches the board with a lock bump (devarea `scripts/bbs-lock-bump.sh`).

## Project structure

```
bbs.rb                        Entry point: Rubbs.board with WikiBBS and the two faces
Gemfile, Gemfile.lock         rubbs from git; rubocop, minitest and rake in :development
Rakefile                      rake test
Dockerfile, .dockerignore     The image
compose.yaml                  The wiki-bbs service on 2325, on the interstack network
.rubocop.yml                  The house RuboCop rules
.woodpecker.yaml              RuboCop, tests, compose check, ci-deploy wiki-bbs
env-example                   Every environment variable, with its default
lib/
  domain.rb                   Requires the domain in dependency order
  domain/
    model/page_model.rb       PageModel: one entry of the page index
    repository/wiki_repository.rb   WikiRepository: the JSON API over Rubbs::Common::Web::HTTP, the page cache
    service/wiki_service.rb   WikiService: the shared index, private flags, pages as markdown, refreshes
    wiki_bbs.rb               WikiBBS (Rubbs::Common::Board::Domain): settings, services, the index loaded in the background
  ui/
    wording.rb                UI::Wording: what both faces tell the caller, who is a supervisor
    modern.rb                 UI::Modern::APP: the commands, menus and help of the ANSI face
    modern/helpers.rb         UI::Modern::Helpers: the browser, refresh, the QR code, logging in and out
    modern/browser_window.rb  UI::Modern::BrowserWindow: the page tree and the reader
    petscii.rb                UI::Petscii (Rubbs::Petscii::Face): the masthead, the page tree as cursor lists
test/                         Minitest tests of the domain (no network: Rubbs::Common::Web::HTTP is stubbed)
```

## Tests

```bash
bundle exec rake test
```

The repository (cleaning, the cache, the token only on private pages and never in an error),
the index and its refresh limits, and the C64 face: the private pages for the
`wiki-supervisor` role (`Rubbs::Test.accounts`), logging in with and without it. CI runs them before a deploy.

## Licence

MIT, see `LICENSE`.
