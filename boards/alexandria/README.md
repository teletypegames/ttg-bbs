# Alexandria BBS

Wikipedia on a telnet line. Type the title of an article, and Alexandria looks
it up on wikipedia.org and shows it in a form a terminal can read: the article
as plain text, cut into its sections, wrapped to the screen. Built on the
[rubbs](https://git.teletypegames.org/engines/rubbs) gem, like the
[Teletype BBS](https://git.teletypegames.org/bbs/teletype-bbs).

It has two faces on one port: the **modern** one for ANSI terminals (windows,
menus, mouse) and a **Commodore 64** one in PETSCII, 40×25, with single-key
menus.

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
telnet localhost 2326      # compose
telnet localhost 2323      # directly (BBS_PORT)
```

## Configuration

Copy `env-example` to `.env`:

| Variable | Default | Description |
|---|---|---|
| `BBS_PORT` | `2323` | TCP port to listen on (in the container; compose publishes it on 2326) |
| `BBS_MAX_SESSIONS` | `100` | Callers at once (compose sets 50) |
| `ALEXANDRIA_BBS_LANGUAGES` | `en,hu` | The Wikipedias a caller can switch between, by their language code; the first one is the default |

## Interface

A call starts with one question: which terminal is calling. The proxy guesses
first: it waits up to 1.5 seconds for the telnet answers, and a terminal that
reports a window wider than 40 columns is a modern one; 40 columns, or no
answer at all (a C64 behind a WiFi modem speaks plain TCP), is taken for a
Commodore. The question is rubbs' `BBS::Terminal`, plain ASCII in capitals,
readable on both: `1` (or `M`) picks the modern face (ANSI/xterm, 256 colours),
`2` (or `C`) the C64 (PETSCII), and RETURN takes the pick, or the guess when
nothing is picked.

What is typed is first looked up as a title: when Wikipedia has an article of
that title, or one it redirects to (`c64` → *Commodore 64*), it opens at once.
Otherwise the search results come, best first, up to 30. An article opens with
its sections: the lead under the article's title, then the `==` sections, the
deeper headings inside them. The sections nobody reads on a terminal (See also,
References, External links, and their Hungarian and German names) are left
out. A formula is shown as its TeX made readable (`e^(iπ)+1=0`). Search
results and articles are cached for 10 minutes, at most 200 answers and 16 MiB
(rubbs' `BBS::Cache`).

### The modern face

A desktop under a menubar, the search dialog open on it. Above it the Pharos of
Alexandria stands by the sea, its light turning while the caller types.

| Key | Action |
|---|---|
| `F2` | Search… |
| `F3` | Random article |
| `F4` | The next language |
| `Enter` | Open the search result |
| `F5` / `Alt-Enter` | Full screen and back |
| `F6` / `Shift-F6` | Next / previous window |
| `Esc` | Close the window |
| `F10` | Menu |
| `Alt-X` | Log off |

The results window lists the titles with the matching snippet and the word
count; the article window has its sections on the left and the text on the
right, the article's address under it.

### The C64 face

The Pharos, the ALEXANDRIA logo and a prompt: type a title and RETURN. RETURN alone opens
the menu: `S` back to the search, `R` random article, `L` the next language,
`Q` log off. Results and sections are numbered lists. The menu and the lists
are cursor menus of rubbs (`BBS::Selector`): CRSR moves the bar, RETURN takes
the lit item, and the letters (or the number typed, in a list) work as well;
CRSR left and right turn the pages of a list, `Q` or `←` (RUN/STOP too) goes
back. A section stops at every
screenful. Accented letters come as their nearest ASCII (the PETSCII line of
rubbs).

## Project structure

```
bbs.rb                        entry point: the board, the terminal question, then a face
lib/
  domain.rb                   requires the domain in dependency order
  domain/
    alexandria_bbs.rb         AlexandriaBBS, the composition root: reads ENV, wires the rest
    model/article_model.rb    an article: title, address, language, sections
    model/section_model.rb    one section: heading and Markdown
    model/search_result_model.rb  one search hit: title, snippet, word count
    model/extract_text.rb     the plain extract → sections in Markdown, TeX made readable
    repository/wikipedia_repository.rb  search, article, random over BBS::Wikipedia; the cache
    service/article_service.rb  look up, search, read, random, the languages
  ui/modern.rb                the modern face: the Application and its parts
  ui/modern/helpers.rb        search, look up, read, random, language, the desktop
  ui/modern/menu.rb           the menubar, the status bar's hints, the desktop on start
  ui/modern/results_window.rb the search results
  ui/modern/article_window.rb an article: sections and text
  ui/modern/pharos.rb         the desktop's title: the lighthouse and the name
  ui/petscii.rb               the PETSCII face: logo, prompt, menu, lists, pages
  ui/petscii/screen.rb        the 40×25 screen: rubbs' BBS::Petscii::Screen
test/                         minitest: the repository, the service, the extract
Rakefile                      rake test
```

## Tests

```bash
bundle exec rake test
```

No network: `BBS::HTTP` is stubbed. CI runs them before a deploy.

## Wikipedia

The proxy reads the [MediaWiki Action API](https://www.mediawiki.org/wiki/API:Main_page)
of `en.wikipedia.org` / `hu.wikipedia.org` anonymously: `list=search` for the results,
`prop=extracts` (TextExtracts, `explaintext`) for the article,
`list=random` for a random one. Every request goes through rubbs'
`BBS::Wikipedia` (over `BBS::HTTP`: timeouts, a deadline, a body cap) and names
the proxy in its User-Agent, as Wikipedia asks. All callers share one pace: at
most 5 requests a second, and a request that would wait more than 3 seconds for
its turn is not sent, so a crowd on the board cannot get our address throttled.
The repository lets a failure go up; the service logs it once and the caller
sees "did not answer".
Titles, snippets and article text are cleaned of control characters
(`BBS::Text.clean`) before they reach a screen. The text is Wikipedia's, under
[CC BY-SA](https://creativecommons.org/licenses/by-sa/4.0/); every article
shows its address.

## Logs

Every line on stderr starts with the log tag `alexandria-bbs:` (rubbs'
`BBS.log`), e.g. `alexandria-bbs: wikipedia: search: BBS::HTTP::Error: …`.

## Deploy

A push to master deploys from Woodpecker: RuboCop, the tests, a compose check, then
`ci-deploy alexandria-bbs` on the server (infra/host-config), which runs the stack in
`/srv/stacks/alexandria-bbs`. The image runs the rubbs revision of `Gemfile.lock`, as uid 1000.
