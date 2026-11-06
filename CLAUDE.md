# CLAUDE.md

TTG BBS: every board of the network in one repository, `boards/<name>` each, run by
rubbs' `Rubbs::MultiRunner` (`bbs.rb`) in one container. README.md has the whole picture.

- A board stays self-contained in its folder: `bbs.rb` (`board = Rubbs.board …` and
  `board.run! if Rubbs.main?(__FILE__)`), `lib/`, `test/`, `env-example`, `.rubocop.yml`,
  `README.md`. Boards may name their classes alike: each runs (and is tested) in its own process.
- A new board: its folder, an entry in `boards.yml` (port, max_sessions, memory), its port in
  `compose.yaml` (port and data mount), and on the server: `ALLOW_PORTS` of
  `/etc/ci-deploy/ttg-bbs.conf`, ufw, Kuma, the bbs-web and gate lists.
- `boards/common` is ttg-common (a gem by path): shared TTG parts only; general BBS machinery goes
  to rubbs (engines/rubbs). Its RDoc is 100% (CI).
- Before a push: `bundle exec rake` and `bundle exec rake rubocop` (CI runs both).
- A change in `boards/<name>` restarts only that board on deploy; a change of the core
  (Gemfile.lock, boards/common, bbs.rb, boards.yml, compose.yaml, Dockerfile, bin/) restarts all.
