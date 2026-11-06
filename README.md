# TTG BBS

Every board of the Teletype Games BBS network in one repository and one container. Each board
keeps its own folder, domain, faces, database, port and tests (`boards/<name>`); one supervisor,
[rubbs](https://git.teletypegames.org/engines/rubbs)' `Rubbs::MultiRunner`, starts each in a
process of its own and watches them.

| Folder | Board | Port |
|---|---|---|
| `boards/teletype` | Teletype BBS | 2323 |
| `boards/impostor` | Impostor BBS | 2324 |
| `boards/wiki` | Wiki BBS | 2325 |
| `boards/alexandria` | Alexandria BBS | 2326 |
| `boards/feedia` | Feedia BBS | 2327 |
| `boards/ttg-blog` | TTG Blog BBS | 2328 |
| `boards/warp-engine` | WarpEngine BBS | 2329 |
| `boards/scriptorium` | Scriptorium BBS | 2330 |
| `boards/commodex` | Commodex BBS | 2331 |
| `boards/pixelia` | Pixelia BBS | 2332 |
| `boards/starbase` | Starbase BBS | 2333 |
| `boards/hackercave` | HackerCave BBS | 2334 |
| `boards/ttg-mail` | TTG Mail BBS | 2335 |
| `boards/ttg-gate` | TTG Gate BBS (the gate, the Central) | 2399 |
| `boards/common` | ttg-common: the TTG parts every board shares (a gem, by path) | — |

Each board's README says what it is; its history came with it (`git log -- boards/<name>`).

## Running

```bash
bundle install
bundle exec ruby bbs.rb        # every board, on its port of boards.yml
bin/board feedia               # one board (BBS_BOARDS=feedia)
ruby boards/feedia/bbs.rb      # one board on its own, BBS_PORT or 2323
```

In Docker: `docker compose up --build`. The boards' code is not in the image: compose mounts
`./boards` read-only and each `boards/<name>/data` writable, so create the data folders first
(`mkdir -p boards/{teletype,impostor,…}/data`). The `interstack` network must exist.

## Settings

- `boards.yml`: per board its `port`, `max_sessions` and `memory` (the supervisor restarts a board
  that stays over it), `enabled: false` to keep it stopped.
- Every board's variables keep their prefix (`FEEDIA_BBS_…`, listed in `boards/<name>/env-example`);
  on the server they are in the stack's `.env` (`env-example` here lists what compose passes on).

## The supervisor

`bbs.rb` runs `Rubbs::MultiRunner` (rubbs README, *Many boards in one container*):

- a board that ends is started again (1, 2, 4 … 60 s); one that fails its health probe three times
  or stays over its memory is restarted in order (its callers are told);
- every board's log line goes out with its name (`"board":"feedia-bbs"`), so Loki and Grafana see
  each board as before;
- `state/multi_runner.json`: every board's pid, health, callers, memory, restarts and revision,
  read by the server's metrics (`vps-textfile-metrics`); the container's health check is its age.

## Deploy

A push to master deploys (`.woodpecker.yaml`, `ci-deploy ttg-bbs` in infra/host-config) to
`/srv/stacks/ttg-bbs`:

- the core (`Gemfile*`, `bbs.rb`, `boards.yml`, `compose.yaml`, `Dockerfile`, `bin/`) is copied and
  the image rebuilt; `boards/` is copied **in place** (each `data/` stays), between
  `boards/.deploying` and a new `boards/.revision`;
- when only boards changed, the image and the container stay: the supervisor sees the new
  revision and restarts **only the boards whose code changed**, one at a time;
- when the core changed (`Gemfile.lock` — a rubbs bump —, `boards/common`, `bbs.rb`, `boards.yml`,
  `compose.yaml`, `Dockerfile`), the container is recreated and every board restarts in order.

## Checks

```bash
bundle exec rake               # every folder's tests and every board's rake bbs:check
bundle exec rake rubocop       # each folder by its own .rubocop.yml
BOARDS=feedia,common bundle exec rake test
```
