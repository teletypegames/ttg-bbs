# Kinema BBS

The film catalog on a telnet line: search any film or anyone who made one,
read their pages and the Wikipedia articles in English or Hungarian, the film
of the day and the films first released on this day, the best known films by
decade and genre; with an account, rate films, write short reviews, keep a
watchlist and a list of the films you have seen. A board of the Teletype
Games BBS network, powered by [rubbs](https://git.teletypegames.org/engines/rubbs).

It has two faces on one port, like every board of the network:

- a **modern** one for ANSI terminals: a desktop under a menubar, the searches
  in dialogs, lists of films and people with the picked one on the right, a
  film's page in a reader with its buttons (Wiki, People, Rate…, Lists…,
  Reviews), a person's films, and an article with its sections on the left;
- a **Commodore 64** one in PETSCII, 40×25: cursor menus of rubbs, the lists
  as cursor lists, a film a page with its actions on one row, a person's
  facts and films, an article as its contents and each section paged.

## Where the data comes from

No IMDb data is used: IMDb's datasets are for personal, non-commercial use
only. Everything comes from open sources.

- **The films and people** are [Wikidata](https://www.wikidata.org)'s, under
  CC0, asked live:
  - the search is the Action API's full-text search (`generator=search`),
    narrowed to films (`haswbstatement:P31=Q11424|…`: a film, a feature, an
    animated, a television or a documentary film) or to the people of the
    films (humans whose occupation is actor, director, screenwriter, producer,
    composer or cinematographer); a hit's name is its English label, else its
    `mul` label (some items keep their name only there), else the Hungarian;
  - a film's page is `wbgetentities` of the film and one more of the names of
    what it points to: directors (P57), writers (P58), cast (P161, the first
    40), music (P86), camera (P344), producers (P162), genres (P136),
    countries (P495), language (P364), based on (P144), follows and followed
    by (P155, P156), company (P272), the length (P2047), the first release
    (P577), the IMDb id (P345, only as Wikidata states it) and the English and
    Hungarian Wikipedia articles;
  - a person's films are one SPARQL query (rubbs' `Rubbs::Common::Web::Wikidata`): every
    film (or subclass of film) that names them in one of those parts, with
    their parts in it, the newest first.

  The answers are kept for six hours in a `Rubbs::Common::Storage::Cache`; the
  Action API is asked at most five times a second, all callers together.
- **The shelf** is a catalog of the best known films, kept on the board:
  every film with an article on at least 30 wikis (about 4,100), with its
  English and Hungarian title, the year and day it first came out, its
  directors and genres. It gives the film of the day (one of the 600 best
  known, the same all day), the films first released on this day, the decades
  and the genres, a random film, and a title search when Wikidata's search
  does not answer. One query finds the films, the rest come 400 films a query
  so no query runs long. The seed ships with the board
  (`config/catalog.json.gz`); the board reads Wikidata again in the background
  when its copy is a week old and keeps the new one in `data/`.
- **The articles** are [Wikipedia](https://www.wikipedia.org)'s, English or
  Hungarian, under CC BY-SA 4.0, read on demand (rubbs'
  `Rubbs::Common::Web::Wikipedia`) and cut into their sections, without the
  lists of sources. Every article ends with its address and licence; its
  address can be shown as a QR code.
- **The ratings and lists** are the callers', in `data/ratings.sqlite3`: an
  account rates a film 1 to 10 stars (the stars count at once) and may add a
  review of up to 400 characters, which waits for an admin (`bin/reviews`).
  A caller may rate 30 times an hour, the whole board takes 300 an hour.
  Marking a film seen takes it off the watchlist.

## Using it

**Modern:** the film of the day opens on the desktop.

| Key | Action |
|---|---|
| `F2` | Search films (English or Hungarian title) |
| `F3` | Search people |
| `F4` | Film of the day |
| `F5` | On this day: the films of the shelf first released on today's date |
| `F7` | A random film of the shelf |
| `F10` | Menu: Films (decades, genres, top rated, recent reviews) and Mine (watchlist, seen, my ratings, the wall, feedback) |
| `Alt-W`, `Alt-P`, `Alt-T`, `Alt-L`, `Alt-V` | On a film: Wiki, People, Rate…, Lists…, Reviews |
| `Alt-M` | In an article: the other language (Magyar/English) |
| `Alt-X` | Log off |

**C64:** the menu: `F` search films, `P` search people, `D` film of the day,
`T` on this day, `E` by decade, `G` by genre, `R` random film, `B` top
rated, `V` recent reviews, `M` my lists, `W` the lobby wall, `H` write to the
sysops, `I` about, `Q` log off. Under a film `A` reads its article (`H` there
switches to the Hungarian one, `C` shows the QR code), `C` lists its people,
`R` rates it, shows the reviews or puts it on a list.

The lobby wall and the feedback are ttg-common's (`TTG::Wall`,
`TTG::Feedback`) and live on TTG Gate BBS, the network's Central;
`lib/content/wall.yml` and `lib/content/feedback.yml` say them the board's
way. The accounts are the network's: a guest can browse everything; rating
and the lists need an account (`auth login: :menu`).

## Badges

`badges.rb`: **Cinephile** (open the pages of 10, 50, 200 films), **Critic**
(rate 1, 10, 50 films), **Film buff** (mark 10, 100, 500 films seen).

## Running

The board is `boards/kinema` of [TTG BBS](https://git.teletypegames.org/bbs/ttg-bbs) and runs
with the other boards in one container. From the repository root:

```bash
docker compose up --build                                    # every board, this one on 2337
bin/board kinema                                             # on 2337 (boards.yml)
cd boards/kinema && BBS_PORT=2337 bundle exec ruby bbs.rb    # or on its own
```

Then `telnet localhost 2337`. Every environment variable is in `env-example`
with its default.

| Variable | Default | |
|---|---|---|
| `KINEMA_BBS_CATALOG_SEED` | `config/catalog.json.gz` | the shelf shipped with the board |
| `KINEMA_BBS_CATALOG` | `data/catalog.json.gz` | the shelf a refresh writes |
| `KINEMA_BBS_CATALOG_TTL` | `604800` | seconds before Wikidata is read again (0: never) |
| `KINEMA_BBS_RATINGS_DB` | `data/ratings.sqlite3` | the callers' ratings and lists |
| `TTG_CENTRAL_URL` | `http://ttg-gate-bbs:8090` | the network's Central (TTG Gate BBS) |
| `RUBBS_AUTH_SECRET` | — | the secret every board shares (in `.env` on the server) |

## Tests

In `boards/kinema`: `bundle exec rake test`. Minitest, no network: the shelf
(film of the day, release days, decades, genres, the accent-blind title
search), the Wikidata import (the batches, the earliest release to the day,
the bare Hungarian titles), a film's page from a recorded `wbgetentities`
answer (`test/fixtures/stalker.json`), the ratings and lists, and both faces
on a fake line.

## Logs

Every line starts with `kinema-bbs:` (`Rubbs.log`): `wikidata: …`,
`wikipedia: …`, `ratings: …`, the refresh of the shelf. In the container they
are in `docker logs ttg-bbs`, with `"board":"kinema-bbs"`.

## Admin

```bash
docker exec -w /app/boards/kinema ttg-bbs bin/reviews list        # the pending reviews
docker exec -w /app/boards/kinema ttg-bbs bin/reviews approve ID  # show it
docker exec -w /app/boards/kinema ttg-bbs bin/reviews reject ID   # never show it (the stars count)
bin/refresh-catalog [path]                                        # a new seed shelf (in a dev checkout)
```

## Project structure

```
bbs.rb                         entry point: Rubbs.board
badges.rb                      Cinephile, Critic, Film buff
bin/refresh-catalog            writes the seed shelf from Wikidata
bin/reviews                    the admins' look at the reviews
config/catalog.json.gz         the seed shelf (Wikidata, CC0)
lib/domain/
  migrations.rb                the ratings and the lists (SQLite)
  model/catalog_film_model.rb  a film of the shelf
  model/catalog_model.rb       the films of a shelf file
  model/hit_model.rb           a search hit, film or person
  model/film_model.rb          a film's page (and PersonRef)
  model/person_model.rb        a person's page (and CreditModel)
  model/article_model.rb       a Wikipedia article in sections (and SectionModel)
  model/rating_model.rb        an account's rating and review
  model/mark_model.rb          a film on an account's watchlist or seen list
  repository/catalog_repository.rb    the shelf's SPARQL queries
  repository/wikidata_repository.rb   the live search, film and person pages
  repository/wikipedia_repository.rb  the articles
  service/catalog_service.rb   the shelf: day, release days, decades, genres, refresh
  service/film_service.rb      search, pages and articles, "did not answer" as nil
  service/rating_service.rb    ratings, reviews, lists, the limits
  kinema_bbs.rb                the composition root (a Rubbs::Common::Board::Domain)
lib/ui/
  wording.rb                   the facts and the words of both faces
  rows.rb                      the lists of films and people, both faces
  modern.rb, modern/           UI::Modern::APP, its helpers and windows
  petscii.rb                   UI::Petscii, the C64 face
test/                          minitest
```

## Licence

MIT, see the repository's `LICENSE`. The film data is Wikidata's (CC0); the
Wikipedia text shown on the board is under CC BY-SA 4.0.
