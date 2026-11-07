# The Hunt

One YAML file a hunt: `<year>/w<ISO week>-<name>.yml`. It is open from the Monday 00:00 of that
week to the next Monday (Europe/Budapest); `opens:` and `closes:` say otherwise. A push deploys it,
the gate reads it within a minute, nobody is restarted.

```yaml
title: The Avian Route
intro: Follow a message across the network.
authors: [Zed]                 # they play, but are not on the list
steps:
  - clue: Find the April document that flies datagrams on wings.
    find: { board: hackercave, event: read, kind: rfc, ref: '1149' }
    fragment: PIGEON           # told when the step is solved
    hints: [It is an April RFC., Number 1149.]   # at most two: after 12 and 36 hours
  - clue: How heavy is a typical MTU, by that standard?
    answer: ['256 mg', '256 milligrams']          # case, accents, spaces and signs do not count
```

- **`find`** is a place: any event a board declares in its `badges.rb`, its fields as the filter
  (a value or a list). A board's own `ref` is its key: an RFC number, a Gutenberg id, a Wikipedia or
  Memory Alpha title. Give the spellings the board may use as a list.
- **`answer`** is typed on the Hunt page; a step with both wants the place first.
- The parts count only after the step opened, so the steps keep their order.
- A clue fits a C64: at most 8 lines of 38 columns.

Before a push: `bin/hunt check` (the gate's tests run the same); `bin/hunt show <file>` prints the
hunt as a player meets it; `bin/hunt new <name>` starts the file of the next free week.
