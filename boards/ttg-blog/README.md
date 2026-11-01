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
docker exec -it ttg-blog-bbs bin/user add NAME    # the first editor
```

**Directly (Ruby 3.x):**

```bash
bundle install
bin/user add NAME
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
| `TTG_BLOG_BBS_DISCORD_WEBHOOK` | — | A post rings this Discord webhook when first published, with its link on the web (`.env` on the server) |
| `TTG_BLOG_BBS_SITE_URL` | `https://teletypegames.org` | The site the Discord message links to |

## Data

One SQLite file, two tables:

- `users` — the editors: `name` (unique, case does not matter) and a
  PBKDF2-SHA256 password digest.
- `posts` — `slug`, `title`, `summary`, `body` (Markdown), `category` (an id
  from the config), `face` (`modern` or `petscii`: the terminal it was written
  on), `published` (0 or 1), `published_at` (the first time it was
  published), `author_id`, `created_at`, `updated_at` (UTC, ISO 8601).

A new post is saved **unpublished**: only the editors see it, on the board,
and the web does not. Publishing is a step of its own: `P` under a post
publishes it or takes it back. Taking a post back keeps its
`published_at`, and only the first publishing rings Discord. The posts from
before the flag stay published.

The slug is the post's address on the web: its date and its title in plain
ASCII (`2026-10-28-hello-world`, `-2` when taken). It is made once, when the
post is saved, and stays when the title changes, so links keep working. A
database from before the slug and the face gets both columns on start, and
its posts get slugs.

Readers need no account. The editors are managed from the server's shell:

```bash
docker exec -it ttg-blog-bbs bin/user list
docker exec -it ttg-blog-bbs bin/user add NAME       # asks the password twice
docker exec -it ttg-blog-bbs bin/user passwd NAME
docker exec -it ttg-blog-bbs bin/user remove NAME    # their posts stay, without an author
```

A logged-in editor can change their own password from the menu too. Three
wrong logins end the tries of a call; each costs a second.

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
| `E` | Editor login |
| `W` | Write a post (logged in) |
| `P` | Change your password (logged in) |
| `O` | Log out (logged in) |
| `Q` | Log off |

Lists are numbered: the number and RETURN opens a post, RETURN alone turns the
page, `Q` or `←` (Esc, RUN/STOP) goes back. On a C64 the number lights the
post, CRSR moves the bar, RETURN opens the lit one, and the pages turn with
CRSR left and right (or as the bar runs past the end). A post shows its title, category,
date, author, the date of its last change, the summary, then the body,
paged a screenful at a time. An editor gets `E` edit, `P` publish or
unpublish and `D` delete under it. On a C64 the post keeps its footer on
every page: RETURN, `+` or CRSR down turns to the next page, `-` or CRSR up
back, `Q` or `←` leaves; an editor's `E`/`P`/`D` stand on the row over it on
every page, the questions (publish? delete?) and their answers come in the
footer over the post, and after an edit or a publish the post is shown again.
A reader sees the published posts only; an
editor sees all of them, the unpublished ones marked so.

### Writing

A new post asks for its title, category, summary and body in turn, then shows
the draft: `T` title, `C` category, `S` summary, `B` body, `V` view (as a
reader will see it), `W` save, `Q` quit (asks before dropping changes). Editing
a post opens the same draft screen.

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
| `GET /posts[?limit=N]` | the posts newest first, without their bodies |
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
bbs.rb                         entry point: the terminal question, then a face
bin/user                       the editors, from the server's shell
config/categories.yml          the categories
env-example                    every environment variable, with its default
lib/
  domain.rb                    requires the domain in dependency order
  domain/
    model/                     CategoryModel, UserModel, PostModel (and its slug)
    repository/                SqliteDatabase (the one connection), PostRepository,
                               UserRepository, CategoryRepository (the YAML file)
    service/                   PostService (limits, publishing), EditorService
                               (names, passwords, login), CategoryService,
                               DiscordNotifier (a new post on Discord)
    ttg_blog_bbs.rb            TTGBlogBBS, the composition root: reads ENV, wires it all
  web/api.rb                   the read API for teletypegames.org
  ui/
    screen.rb                  the colours and the screen (BBS::Petscii::Screen of
                               rubbs), with a number typed up to RETURN
    board.rb                   one call, shared by the faces: menu, lists, a post,
                               login, the editor, goodbye
    modern.rb, modern/board.rb    UI::Modern: the caller's window, half-block masthead
    modern/screen.rb              its lists, numbered, picked by typing the number
    petscii.rb, petscii/board.rb  UI::Petscii: 40×25 PETSCII, the front page of cursor
                                  menus, a post's C64 screen for the web
    petscii/screen.rb             full-screen menus and lists, the footer bar, a post
                                  read under its footer, questions in the footer
```

## Deploy

A push to master deploys from Woodpecker: RuboCop, a compose check, then
`ci-deploy ttg-blog-bbs` on the server (infra/host-config), which runs the stack in
`/srv/stacks/ttg-blog-bbs`; `data/` and `.env` stay. The image runs the rubbs revision of
`Gemfile.lock`, as uid 1000.
