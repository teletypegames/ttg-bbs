# WIKI-BBS

The Teletype Games wiki over telnet — a [rubbs](https://git.teletype.hu/tools/rubbs.git)-based
BBS that browses the Grav wiki live through its JSON API.

```
telnet localhost 2325
```

A Norton Commander-style two-pane browser: page tree on the left (indented by
route depth), the selected page rendered as ANSI markdown on the right.

## Keys

| Key | Action |
|---|---|
| Up/Down | Pick a page (detail reloads) |
| Tab | Move focus to the reader pane |
| PgUp/PgDn/Home/End | Scroll the reader |
| F2 | Reopen the browser |
| F5 | Refresh the wiki index (clears the page cache) |
| F10 | Menubar |
| Alt-X / Esc | Quit / close window |

Pages marked `*` in the list are private (login-protected on the wiki).
Unlock them with **Wiki > Supervisor login** — the password comes from the
`SUPERVISOR_PASSWORD` env var. Locking back: same menu item, confirm.

Mouse works too (xterm SGR), including wheel scroll in both panes.

## Data source

Two endpoints on the Grav wiki (templates in
`themes/ttgwiki/templates/*.json.twig`, pages in `pages/api/`):

- `GET /api/sitemap.json` — every routable page: `route`, `title`,
  `modified`, `updatedAt`, `tags`, `private` (true when the page or any
  ancestor has `access: site.login` in its frontmatter). Titles/routes only,
  no bodies.
- `GET /api/page.json?route=/development/tic80[&token=...]` — one page: the
  above plus `markdown` (raw) and `html` (rendered). Private pages require
  `token` to match the wiki's `SUPERVISOR_PASSWORD`, otherwise
  `{"error": "forbidden"}`. Unknown route → `{"error": "not_found"}`.

The page index (`sitemap.json`) is loaded once at server boot and shared by
every session; **F5 / Wiki > Refresh index** re-reads it for everyone. If the
wiki is down at boot, the BBS still starts with an empty index. Page bodies
are rendered with `BBS::Markdown` and cached for 5 minutes
(`Wiki::Client::PAGE_TTL`).

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
| `BBS_IDLE` | `900` | Idle disconnect (seconds) |
| `WIKI_URL` | `http://localhost:9120` | Grav wiki base URL |
| `SUPERVISOR_PASSWORD` | — | Unlocks private pages (Wiki > Supervisor login) and is sent to the wiki as the API token — must match the grav service's value; empty = private pages stay locked |

`entrypoint.sh` runs `bundle update bbs` on container start, so the BBS
always boots with the latest rubbs revision.
