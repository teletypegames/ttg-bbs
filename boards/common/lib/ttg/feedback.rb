# frozen_string_literal: true

require 'rubbs/common/web/discord_webhook'
require_relative 'feedback/store'
require_relative 'feedback/screen'

module TTG
  # What callers send the sysops, from any board: feedback, a bug, a
  # suggestion, a page, or a board's own kind (a feed to add, a game's
  # debrief). It lives on the Central (TTG Gate BBS, TTG::CENTRAL) as a
  # Rubbs::Common::Central::Service, Service, and is the only thing of the
  # network that goes to Discord: that something came, not what it says.
  #
  #   TTG::Feedback.open(session)                                  # the screen, on either face
  #   TTG::Feedback.open(session, narrative: NARRATIVE, context: 'Book: Emma')
  #
  # What the screen says comes from DEFAULTS and the board's own
  # (TTG::Narrative): a Hash, or <tt>lib/content/feedback.yml</tt>.
  module Feedback
    # The feedback table on the Central.
    MIGRATIONS = [
      <<~SQL
        CREATE TABLE feedback (
          id         INTEGER PRIMARY KEY,
          created_at TEXT NOT NULL,
          board      TEXT NOT NULL,
          kind       TEXT NOT NULL,
          subject    TEXT NOT NULL DEFAULT '',
          body       TEXT NOT NULL,
          link       TEXT,
          context    TEXT,
          account_id INTEGER,
          name       TEXT,
          caller_key TEXT,
          face       TEXT,
          state      TEXT NOT NULL DEFAULT 'new',
          handled_by TEXT,
          handled_at TEXT,
          note       TEXT
        );
        CREATE INDEX feedback_state ON feedback (state, id);
        CREATE INDEX feedback_caller ON feedback (caller_key, created_at);
      SQL
    ].freeze

    # What the screen says when the board says nothing (TTG::Narrative).
    DEFAULTS = {
      title:       'Feedback',
      intro:       'A word for the sysops: an idea, a bug, a question or a thank you. They read every one.',
      kinds:       { feedback: { label: 'Feedback' }, bug: { label: 'A bug' }, suggestion: { label: 'An idea' } },
      name:        { label: 'Your name (or nothing)', max: 20 },
      subject:     { label: 'Subject', max: 60 },
      body:        { label: 'Your message', max: 2000 },
      link:        { label: 'Address (http…)', off: true },
      context:     'About: %<context>s',
      thanks:      'Thank you. The sysops will read it.',
      empty:       'Nothing to send.',
      bad_link:    'That is not an http or https address.',
      limited:     'That is all for now. Please try again later.',
      name_taken:  'That name is an account\'s. Log in, or use another name.',
      unavailable: 'The feedback box cannot be reached now. Please try again later.',
      petscii:     { intro: 'A WORD FOR THE SYSOPS. THEY READ EVERY ONE.' }
    }.freeze

    # The Discord line of new feedback: on which board, what kind, from whom
    # — never what it says (the console has that). Set on the Central by
    # +TTG_GATE_BBS_FEEDBACK_WEBHOOK+; off without it.
    class Notifier
      # A notifier posting to +url+ (+nil+: off).
      def initialize(url)
        @hook = Rubbs::Common::Web::DiscordWebhook.new(url, relay_max: 20, relay_window: 600, embeds: false, label: 'feedback')
      end

      # Posts the line of +row+ (a new feedback). Returns the post's Thread or +nil+.
      def call(row)
        who = row[:name].to_s.empty? ? 'a guest' : row[:name].to_s
        who = "#{who} (guest)" if row[:account_id].nil? && !row[:name].to_s.empty?
        board, kind, who = [row[:board], row[:kind], who].map { |text| Rubbs::Common::Web::DiscordWebhook.escape(text) }
        @hook.post("📨 New feedback on **#{board}**: #{kind}, from #{who} (##{row[:id]})")
      end
    end

    # The feedback as a service of the Central, on <tt>/feedback</tt>. Ops:
    #
    # [submit] +subject+, +body+, +kind+, +link+, +context+; the board is the asker
    # [list]   (sysop) +state+, +before+, +limit+
    # [read]   (sysop) +id+
    # [mark]   (sysop) +id+, +state+, +note+
    # [delete] (sysop) +id+
    # [counts] (sysop)
    # [import] the rows of a board's old box (+rows+), from the board itself
    class Service < Rubbs::Common::Central::Service
      path     '/feedback'
      database :feedback, MIGRATIONS

      op(:submit) do |actor, subject: '', body: '', kind: 'feedback', link: nil, context: nil, **|
        store.add(actor, board: asker, subject: subject, body: body, kind: kind, link: link, context: context)
      end
      op(:list, role: :sysop) { |_, state: nil, before: nil, limit: 30, **|
        store.list(state: state, before: before, limit: limit)
      }
      op(:read, role: :sysop) { |actor, id:, **| store.read(id, by: actor.name) }
      op(:mark, role: :sysop) { |actor, id:, state:, note: nil, **| store.mark(id, state, by: actor.name, note: note) }
      op(:delete, role: :sysop) { |_, id:, **| store.delete(id) }
      op(:counts, role: :sysop) { |_, **| { counts: store.counts } }
      op(:import, actor: false) { |_, rows: [], **|
        { count: store.import(Array(rows).map { |row|
          { board: asker }.merge(row.transform_keys(&:to_sym))
        }) }
      }

      # A service on the Central's +context+, its notifier on
      # +TTG_GATE_BBS_FEEDBACK_WEBHOOK+.
      def initialize(context)
        super
        @store = Store.new(database, notify: Notifier.new(ENV.fetch('TTG_GATE_BBS_FEEDBACK_WEBHOOK', nil)))
      end

      # The Store.
      attr_reader :store
    end

    # The feedback box of the network on this board (a
    # Rubbs::Common::Central::Proxy of Service).
    def self.box = Rubbs.central(Service)

    # Shows the feedback screen to the caller on +session+ (Screen):
    # +narrative+ a TTG::Narrative, a Hash or a path (default: the board's
    # <tt>lib/content/feedback.yml</tt>), +context+ what the caller was
    # looking at, +kind+ to skip the choice of kinds. Returns +nil+.
    def self.open(session, narrative: nil, context: nil, kind: nil)
      Screen.new(session, narrative_of(narrative), context: context).run(kind: kind)
    end

    # +given+ as a TTG::Narrative on DEFAULTS.
    def self.narrative_of(given)
      return given if given.is_a?(Narrative)

      Narrative.new(DEFAULTS, given || File.expand_path('lib/content/feedback.yml', Dir.pwd))
    end
  end
end
