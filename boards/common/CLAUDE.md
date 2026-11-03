# CLAUDE.md

ttg-common: the shared, TTG-specific parts of the Teletype Games BBS boards,
on rubbs (`engines/rubbs`, the `bbs` gem). General BBS machinery goes to rubbs;
what only the TTG boards need (logo, house texts, the board list) goes here.

- One part = one module under `TTG` in `lib/ttg/<part>.rb`, its data in
  `lib/ttg/<part>/`, required from `lib/ttg/common.rb`, a test in `test/`, a
  row in the README table.
- RDoc on every public module, class, constant and method, as in rubbs:
  `rdoc -C lib` must print 100.00% documented (CI checks it).
- `bundle exec rake test` and `bundle exec rubocop` must be clean.
- Release: version in `ttg-common.gemspec`, annotated tag `vX.Y.Z`.
