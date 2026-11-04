# TTG Blog BBS

The Teletype Games blog on a telnet line. Readers browse the latest posts or
the posts of a category and read them paged; the editors log in from the same
menu and write, edit and delete posts. Built on the
[rubbs](https://git.teletypegames.org/engines/rubbs) gem, like the
[Teletype BBS](https://git.teletypegames.org/bbs/teletype-bbs),
[Alexandria BBS](https://git.teletypegames.org/bbs/alexandria-bbs) and
[Feedia BBS](https://git.teletypegames.org/bbs/feedia-bbs).

It has two faces on one port, and both are line by line, with no windows: a
**modern** one for ANSI terminals (up to 80 columns, the caller's window
height) and a **Commodore 64** one in PETSCII, 40×25. The lists and the
full-screen editor are the same on both; on the C64 the menus and the lists
are cursor menus of rubbs (`BBS::Selector`), and the front page is its own.

## Running

**Docker Compose:**

```bash
docker compose up --build
```

**Directly (Ruby 3.x):**

```bash
bundle install
ruby bbs.rb
```

Connect:

```bash
telnet localhost 2328      # compose
telnet localhost 2323      # directly (BBS_PORT)
```

## Configuration

The categories are listed in [`config/categories.yml`](config/categories.yml),
in the order a caller sees them; a post names its category by `id`:

```yaml
- id: devlog                                 # required, stored with the post
  name: Devlog                               # required, shown
  about: How the games and the tools are made
```

A change is a commit to that file: a push to master deploys it. A new post
can only pick a listed category; a post whose category left the list keeps it
and shows its bare id.

| Variable | Default | Description |
|---|---|---|
| `BBS_PORT` | `2323` | TCP port to listen on (in the container; compose publishes it on 2328) |
| `TTG_BLOG_BBS_DB` | `data/ttgblog.sqlite3` | The SQLite database (compose mounts `./data`) |
| `TTG_BLOG_BBS_CATEGORIES` | `config/categories.yml` | The category list |
| `TTG_BLOG_BBS_HTTP_PORT` | `8080` | Port of the read API (`0` turns it off); compose does not publish it |
| `TTG_BLOG_BBS_AUTOSAVE_SECONDS` | `15` | Seconds between the autosaves of a draft while an editor writes |
| `TTG_BLOG_BBS_DISCORD_WEBHOOK` | — | A post rings this Discord webhook when first published, with its link on the web (`.env` on the server) |
| `TTG_BLOG_BBS_SITE_URL` | `https://teletypegames.org` | The site a published post is on, `/blog/SLUG`: the Discord message links to it, the QR code of a post shows it |

## Log

Every line on stderr (`docker logs ttg-blog-bbs`) starts with the log tag
`ttg-blog-bbs:` (rubbs' `BBS.log`) and what it is about: `login` (a failed
login, with the name and the caller), `saving a post`, `on_publish`, `categories`
(the list could not be read: no post can be written then), `web` (an error of
the read API, whose server runs as the `BBS.background` thread `web`).

## Data

One SQLite file (`data/ttgblog.sqlite3`, the board's database: `database :db,
MIGRATIONS`, rubbs' `BBS::Model` on Sequel), two tables, each a model, its schema
in `lib/domain/migrations.rb` (`BlogSchema`) as `migrate` steps (`PRAGMA user_version`):

- `users` — the authors of the posts: the id and name of their account of the
  network, remembered when they first write (the password digests are of the
  blog's own logins before the accounts of the network, empty since).
- `posts` — `slug`, `title`, `summary`, `body` (Markdown), `category` (an id
  from the config), `face` (`modern` or `petscii`: the terminal it was written
  on), `status` (`draft`, `unpublished` or `published`), `published_at`
  (the first time it was published), `author_id`, `created_at`,
  `updated_at` (UTC, ISO 8601), and for a draft `original_id` and
  `base_updated_at`.

A new post is saved **unpublished**: only the editors see it, on the board,
and the web does not. Publishing is a step of its own: `P` under a post
publishes it or takes it back. Taking a post back keeps its
`published_at`, and only the first publishing rings Discord. The posts from
before the flag stay published.

What an editor writes is a **draft** until it is saved: a row of its own with
the status `draft`, which nothing but the composer sees (not the lists, the
counts, `G` or the web). A draft with an `original_id` is an edit of that
post; one without is a new post. It is kept unchecked, after every field,
every `TTG_BLOG_BBS_AUTOSAVE_SECONDS` in the editor while the text changes,
and when the caller hangs up; it is made at the first change, so opening a
post and leaving makes none. Saving a draft writes its fields into its post
and deletes it; a new post's draft becomes the post itself (unpublished, with
a slug, dated then, keeping its id). Deleting a post deletes its drafts.

`base_updated_at` is the original's `updated_at` when the edit began: when
the original was saved since (by another editor), saving asks before it
overwrites.

The slug is the post's address on the web: its date and its title in plain
ASCII (`2026-10-28-hello-world`, `-2` when taken). It is made once, when the
post is saved, and stays when the title changes, so links keep working.

Step 1 of the schema is the board before versions: on a database the board
wrote before (version 0) it adds only what that file lacks (the slug, face
and publishing columns, the slugs, the indexes) and keeps every row, so the
production file comes out at version 1 as it was. Step 2 turns the
`published` flag into the `status` and adds the draft columns. What an editor types is
cleaned of control characters (`BBS::Text.clean`) before it is kept.

Readers need no account. The editors are the accounts of the network
(rubbs `BBS::Auth`, kept on TTG Gate BBS) with the **blogger** role: they log
in from the menu (`E`), or come in logged in when they dialled the blog from the
gate. The accounts and their roles are managed on the gate's shell:

```bash
docker exec -it ttg-gate-bbs bin/account grant NAME blogger
docker exec -it ttg-gate-bbs bin/account password NAME
```

A logged-in editor can change their own password from the menu too (`P`, through
the gate). The limits on wrong passwords are the gate's (by name and by line).
The board needs `RUBBS_AUTH_SECRET`, the secret every board shares, in its `.env`.

## Interface

A call starts with rubbs' `BBS::Terminal` question: which terminal is calling.
Then the masthead and the menu. On a C64 every screen is the whole 40×25,
with a reversed footer bar on its last but one row that tells its keys. The
front page is the logo over one cursor menu: the newest posts, as many as the
screen holds (`1`… open them), then the items below, the lit one's line about
it over the footer. CRSR moves the bar and RETURN takes it; the keys of the
table work as well. The lists and the draft screen (with the first lines of the
body under it) are full-screen cursor menus too, numbered or lettered as on
the modern face.

| Key | Action |
|---|---|
| `L` | Latest posts, newest first |
| `C` | Categories, with their post counts, then that category's posts |
| `G` | Go to a post by its number (the web shows it beside the post) |
| `U` | Unpublished posts (logged in) |
| `E` | Log in (an account with the blogger role is an editor) |
| `W` | Write a post (logged in) |
| `P` | Change your password (logged in) |
| `O` | Log out (logged in) |
| `Q` | Log off |

Lists are numbered cursor lists on both faces: the number lights the post,
CRSR moves the bar, RETURN opens the lit one, the pages turn with CRSR left
and right (or as the bar runs past the end), `Q` or `←` (Esc, RUN/STOP) goes
back. A post shows its title, category,
date, author, the date of its last change, the summary, then the body,
paged a screenful at a time. An editor gets `E` edit, `P` publish or
unpublish and `D` delete under it. On a C64 the post keeps its footer on
every page: RETURN, `+` or CRSR down turns to the next page, `-` or CRSR up
back, `Q` or `←` leaves; an editor's `E`/`P`/`D` stand on the row over it on
every page, the questions (publish? delete?) and their answers come in the
footer over the post, and after an edit or a publish the post is shown again.
A reader sees the published posts only; an
editor sees all of them, the unpublished ones marked so.

Under a published post `C` shows the QR code of its page on the web
(`TTG_BLOG_BBS_SITE_URL/blog/SLUG`), for a phone to open it with its pictures
and links: rubbs' `BBS::QR`, half blocks on a modern terminal, quadrant
blocks on a C64, in the middle of the screen until a key (a quiet zone of
one module when two leave no room). A reader gets it after the last page
(on a C64 on the row over the footer), an editor beside `E`/`P`/`D`; an
unpublished post has no page on the web and no `C`.

### Writing

A new post asks for its title, category, summary and body in turn, then shows
the draft: `T` title, `C` category, `S` summary, `B` body, `V` view (as a
reader will see it), `W` save, `Q` quit. Editing a post opens the same draft
screen. Every change is autosaved into a draft (see Data), so a dropped line
loses nothing.

`Q` after a change asks: `K` keeps the draft for later, `D` discards it,
RETURN (on a C64 `back`) goes back to the draft. `E` on a post with drafts,
and `W` while there are drafts of new posts, start from a list: the post as it
is now (or a new post), then the drafts with their time and editor, the last
first; `D` discards one (on a modern terminal `D` then its number). Every
editor sees every draft. The menu tells the drafts of new posts beside `W`.

The name, the passwords and the title are typed in a field of rubbs
(`BBS::Field`), the summary and the body in its full-screen editor
(`BBS::Editor`); both start from the current text: the cursor keys move
anywhere in it, typing inserts at the cursor, DEL deletes before it, and the
lines wrap as they are typed. A field and the summary end with RETURN, RUN/STOP
or `←` leaves a field; the body is Markdown, RETURN starts a new line and an
empty line a new paragraph.

In the editor:

| Key | Action |
|---|---|
| cursor keys | Move; up and down keep the column |
| HOME / END | Start / end of the screen row |
| PgUp / PgDn | A screenful up / down (modern terminal) |
| RUN/STOP or `←` (Esc), then `S` | Save |
| RUN/STOP or `←` (Esc), then `Q` | Quit, keep the text as it was |
| F1 (Ctrl-S) | Save at once (the Ultimate Term keeps F1 for its help) |

## On the web

The posts are the blog of [teletypegames.org](https://teletypegames.org/blog).
The board serves them read-only over HTTP, beside the telnet line, in the same
process (`Web::Api`); the container joins the `interstack` network and the
site's API reads it there as `http://ttg-blog-bbs:8080`. The port is never
published.

| Request | Answer |
|---|---|
| `GET /health` | `{"ok":true}` |
| `GET /categories` | the categories in order, with `count` |
| `GET /posts[?limit=N]` | the posts newest first, without their bodies: 100 by default, at most 200 |
| `GET /posts/SLUG` | one post: `body` (Markdown), `html` (kramdown, GFM), `screen` |

Only the published posts: an unpublished one is 404, and the category counts
leave it out.

A post carries `id`, `slug`, `title`, `summary`, `category` (`id`, `name`),
`author`, `face`, `published_at`, `created_at`, `updated_at` and `updated`. Its `screen` is the
post as a Commodore 64 caller sees it: `cols` (40), `page` (lines a
screenful) and `lines`, the title bar and the paged lines in the board's ANSI
colours; the site draws them in the C64 palette. The HTML is not sanitised
here: the site does that.

## Project structure

```
bbs.rb                         entry point: BBS.board, the two faces and the read API
bin/user                       the editors, from the server's shell
config/categories.yml          the categories
env-example                    every environment variable, with its default
lib/
  domain.rb                    requires the domain in dependency order
  domain/
    migrations.rb              MIGRATIONS: the schema, one step per version (BlogSchema)
    model/                     UserModel and PostModel (the tables, BBS::Model: their
                               queries, the drafts, the slugs), CategoryModel
    repository/                CategoryRepository (the YAML file)
    service/                   PostService (limits, cleaning, publishing), EditorService
                               (names, passwords, login), LoginGuard (failed tries
                               by name and caller, two derivations at a time),
                               CategoryService, DiscordNotifier (a new post on Discord)
    ttg_blog_bbs.rb            TTGBlogBBS (BBS::Domain): its settings and services
  web/api.rb                   the read API for teletypegames.org
  ui/
    board.rb                   UI::Board (BBS::Petscii::Face), one call shared by the
                               faces: the menu's items, lists, a post
    board/account.rb           logging in and changing the password
    board/composer.rb          writing and editing a post
    post_page.rb               a post as lines, for both faces and the web's C64 screen
    modern.rb                     UI::Modern: the caller's window, half-block masthead,
                                  the menu typed at a prompt
    petscii.rb                    UI::Petscii: 40×25 PETSCII, the front page of cursor
                                  menus, a post's C64 screen for the web
    petscii/screen.rb             full-screen menus and lists, the footer bar, a post
                                  read under its footer, questions in the footer
test/                          minitest: the schema and the legacy shapes, the services,
                               the login limits, the read API (rake test)
```

## Tests

```bash
bundle exec rake test               # all of them
bundle exec rake test schema        # the files whose name has one of the words
```

They need no network: each test works on a database in a temporary folder.

## Deploy

A push to master deploys from Woodpecker: RuboCop and the tests, a compose check, then
`ci-deploy ttg-blog-bbs` on the server (infra/host-config), which runs the stack in
`/srv/stacks/ttg-blog-bbs`; `data/` and `.env` stay. The image runs the rubbs revision of
`Gemfile.lock`, as uid 1000.
