# frozen_string_literal: true

require_relative 'wall/store'
require_relative 'wall/screen'

module TTG
  # The wall of a board: callers write on it and answer each other, one wall
  # a board and, on the gate, all of them together. It lives on the Central
  # (TTG Gate BBS) as a Rubbs::Common::Central::Service, Service; an account
  # writes under its name, a guest under a name of their own that is no
  # account's, marked as a guest's.
  #
  #   TTG::Wall.open(session)                         # this board's wall, on either face
  #   TTG::Wall.open(session, board: nil)             # every board's (the gate)
  #   TTG::Wall.lines(3)                              # the newest three, for a board's own screen
  #
  # What the screen says comes from DEFAULTS and the board's own
  # (TTG::Narrative): a Hash, or <tt>lib/content/wall.yml</tt>.
  module Wall
    # The wall's tables on the Central.
    MIGRATIONS = [
      <<~SQL
        CREATE TABLE wall (
          id         INTEGER PRIMARY KEY,
          created_at TEXT NOT NULL,
          board      TEXT NOT NULL,
          account_id INTEGER,
          name       TEXT NOT NULL,
          guest      INTEGER NOT NULL DEFAULT 0,
          sysop      INTEGER NOT NULL DEFAULT 0,
          text       TEXT NOT NULL,
          reply_to   INTEGER,
          face       TEXT,
          caller_key TEXT,
          hidden_at  TEXT,
          hidden_by  TEXT,
          reason     TEXT
        );
        CREATE INDEX wall_board ON wall (board, id);
        CREATE INDEX wall_caller ON wall (caller_key, created_at);
        CREATE INDEX wall_account ON wall (account_id, created_at);
        CREATE TABLE wall_bars (
          caller_key TEXT PRIMARY KEY,
          until_at   TEXT NOT NULL,
          by         TEXT
        );
      SQL
    ].freeze

    # What the screen says when the board says nothing (TTG::Narrative).
    DEFAULTS = {
      title:        'The Wall',
      intro:        'Write on the wall of this board, and answer what others wrote.',
      empty:        'Nothing on the wall yet. Be the first!',
      write:        'Write',
      reply:        'Reply',
      older:        'Older',
      newer:        'Newest',
      back:         'Back',
      text:         { label: 'Your note', max: 500 },
      reply_to:     { label: 'Answer note #' },
      guest_name:   { label: 'Your name' },
      guest:        'guest',
      answer:       'to %<name>s',
      thanks:       'On the wall.',
      empty_note:   'Nothing to write.',
      name_needed:  'A guest writes with a name.',
      name_taken:   'That name is an account\'s. Log in, or use another name.',
      too_soon:     'Not so fast: wait a little before the next note.',
      limited:      'That is all for now. Please come back later.',
      barred:       'You cannot write on the walls for now.',
      unknown_note: 'There is no such note on this wall.',
      unavailable:  'The wall cannot be reached now. Please try again later.',
      petscii:      { intro: 'WRITE ON THE WALL, ANSWER THE OTHERS.' }
    }.freeze

    # The wall as a service of the Central, on <tt>/wall</tt>. Ops (the board
    # is the asker unless +board+ says otherwise):
    #
    # [post]       +text+, +reply_to+
    # [recent]     +board+, +before+, +limit+ (who asks is not checked)
    # [since]      +board+, +after+
    # [withdraw]   +id+ (the writer's own)
    # [moderation] (sysop) +before+, +limit+: every note, hidden ones too
    # [hide]       (sysop) +id+, +reason+
    # [unhide]     (sysop) +id+
    # [bar]        (sysop) +id+, +hours+: the guest's line off the walls
    # [import]     +rows+ from before the wall, from the board itself
    class Service < Rubbs::Common::Central::Service
      path     '/wall'
      database :wall, MIGRATIONS

      op(:post) { |actor, text: '', reply_to: nil, **| store.post(actor, board: asker, text: text, reply_to: reply_to) }
      op(:recent, actor: false) do |_, board: :asker, before: nil, limit: 20, **|
        store.recent(board: board == :asker ? asker : board, before: before, limit: limit)
      end
      op(:since, actor: false) { |_, board: :asker, after: 0, **|
        store.since(board: board == :asker ? asker : board, after: after)
      }
      op(:withdraw) { |actor, id:, **| store.withdraw(actor, id) }
      op(:moderation, role: :sysop) { |_, before: nil, limit: 30, **| store.moderation(before: before, limit: limit) }
      op(:hide, role: :sysop) { |actor, id:, reason: nil, **| store.hide(id, by: actor.name, reason: reason) }
      op(:unhide, role: :sysop) { |_, id:, **| store.unhide(id) }
      op(:bar, role: :sysop) { |actor, id:, hours: 24, **| store.bar(id, hours: hours, by: actor.name) }
      op(:import, actor: false) { |_, rows: [], **|
        { count: store.import(Array(rows).map { |r|
          { board: asker }.merge(r.transform_keys(&:to_sym))
        }) }
      }

      # A service on the Central's +context+.
      def initialize(context)
        super
        @store = Store.new(database, context.accounts)
      end

      # The Store.
      attr_reader :store
    end

    # The walls of the network on this board (a
    # Rubbs::Common::Central::Proxy of Service).
    def self.walls = Rubbs.central(Service)

    # Shows the wall to the caller on +session+ (Screen): this board's, or
    # +board+'s (+nil+: every board's, newest first from all of them);
    # +narrative+ a TTG::Narrative, a Hash or a path (default: the board's
    # <tt>lib/content/wall.yml</tt>). Returns +nil+.
    def self.open(session, board: :here, narrative: nil)
      Screen.new(session, narrative_of(narrative), board: board).run
    end

    # The newest +count+ notes of this board's wall, oldest first, for a
    # board's own screen: Hashes with +name+, +text+, +guest+ (empty when
    # the Central does not answer).
    def self.lines(count = 3, board: :here)
      answer = walls.call(:recent, nil, **board_field(board), limit: count)
      answer['notes'] || []
    end

    # The +board+ field of a request: none for :here (the asker's own wall).
    def self.board_field(board) = board == :here ? {} : { board: board.to_s }

    # +given+ as a TTG::Narrative on DEFAULTS.
    def self.narrative_of(given)
      return given if given.is_a?(Narrative)

      Narrative.new(DEFAULTS, given || File.expand_path('lib/content/wall.yml', Dir.pwd))
    end
  end
end
