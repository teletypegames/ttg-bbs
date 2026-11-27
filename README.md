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
| `boards/kinema` | Kinema BBS | 2337 |
| `boards/monitor` | Monitor BBS: Grafana's dashboards, for the `grafana` role only (`private`, not published: on the gate's list for that role only) | (2336) |
| `boards/siliconia` | Siliconia BBS | 2338 |
| `boards/ttg-gate` | TTG Gate BBS (the gate, the Central) | 2399 |
| `boards/common` | ttg-common: the TTG parts every board shares (a gem, by path) | — |

Each board's README says what it is; its history came with it (`git log -- boards/<name>`).

## Running

```bash
bundle install
bundle exec ruby bbs.rb        # every board, on its port of boards.yml
bin/board feedia               # one board (BBS_BOARDS=feedia)
cd boards/feedia && bundle exec ruby bbs.rb   # one board on its own (in its folder: data/), BBS_PORT or 2323
```

In Docker: `docker compose up --build`. The boards' code is not in the image: compose mounts
`./boards` read-only and each `boards/<name>/data` writable, so create the data folders first
(`mkdir -p boards/{teletype,impostor,…}/data`). The `interstack` network must exist.

## Settings

- `boards.yml`: per board its `port`, `max_sessions` and `memory` (the supervisor restarts a board
  that stays over it), `enabled: false` to keep it stopped, `private: true` for a board only a
  role may call (no list shows it, no badge counts it, its port is not in `compose.yaml`),
  `drain: false` for a board that must never run twice at once (Pixelia's canvas in memory: a
  deploy stops it and starts it again).
- Every board's variables keep their prefix (`FEEDIA_BBS_…`, listed in `boards/<name>/env-example`);
  on the server they are in the stack's `.env` (`env-example` here lists what compose passes on).

## The supervisor

`bbs.rb` runs `Rubbs::MultiRunner` (rubbs README, *Many boards in one container*):

- a board that ends is started again (1, 2, 4 … 60 s); one that fails its health probe three times
  or stays over its memory is restarted in order (its callers are told);
- every board's log line goes out with its name (`"board":"feedia-bbs"`), so Loki and Grafana see
  each board as before;
- `state/<colour>/multi_runner.json`: every board's pid, health, callers, memory, restarts,
  revision and the old processes draining, read by the server's metrics (`ttgvps metrics
  textfile`); the container's health check is its age.

## Deploy

A push to master deploys (`.woodpecker.yaml`, `ci-deploy ttg-bbs` in infra/host-config) to
`/srv/stacks/ttg-bbs`:

- the core (`Gemfile*`, `bbs.rb`, `boards.yml`, `compose.yaml`, `Dockerfile`, `bin/`) is copied and
  the image rebuilt; `boards/` is copied **in place** (each `data/` stays), between
  `boards/.deploying` and a new `boards/.revision`;
- no call drops. When only boards changed, the image and the container stay: the supervisor sees
  the new revision and hands over **only the boards whose code changed**, one at a time: the new
  process listens beside the old one (`SO_REUSEPORT`), then the old one drains (SIGUSR2): it takes
  no new call, and its callers go on until they leave (at most `BBS_DRAIN_SECONDS`, 30 minutes);
- when the core changed (`Gemfile.lock` — a rubbs bump —, `boards/common`, `bbs.rb`, `boards.yml`,
  `compose.yaml`, `Dockerfile`, the `.env`), the other colour starts: `ttg-bbs-blue` and
  `ttg-bbs-green` share the network namespace of `ttg-bbs-net` (the public ports and the interstack
  names, never rebuilt), so the new colour listens beside the old one; once every board of it runs,
  the old colour drains and its container exits when its last caller has left. The running colour
  is `/var/lib/ttgvps/slots/ttg-bbs` (`ttgvps stack ps ttg-bbs` shows it). A change of
  `ttg-bbs-net` itself (a new public port) recreates it, and then every board restarts.

## Checks

```bash
bundle exec rake               # every folder's tests and every board's rake bbs:check
bundle exec rake rubocop       # each folder by its own .rubocop.yml
BOARDS=feedia,common bundle exec rake test
```

CI also checks the Director's scenarios (below) with bbs-web's `bin/scenario-check`, from a tagged
bbs-web release.

## Scenarios (bbs-web's Director)

`boards/<board>/scenarios/*.yaml` are scripted calls for screen recordings: the local-only Director of
bbs-web (`services/bbs-web`, README: *Director*) types them into its terminal and records them as mp4.
They live here so a board and its demo change in the same commit. `boards/common/scenarios` holds the
shared parts (`face-ansi`, `face-c64`, `splash`), `ttg-gate/scenarios/login-demo` logs in as the Demo
account. A board's `scenarios/` is not its code (rubbs 4.6.2: `Fingerprint::IGNORED`), so a changed
scenario restarts no board; nothing on the server reads them.

```bash
cd ../../services/bbs-web
docker compose -f compose.yaml -f compose.director.yaml up -d --build   # http://localhost:9140
node tools/director-record/record.mjs siliconia/tour                    # → out/siliconia-tour.mp4
```
