# frozen_string_literal: true

module UI
  module Modern
    module Windows
      # Messages > Boards: the boards on the left, the newest posts of the
      # chosen one on the right.
      module Messages
        def self.configure(w)
          w.accent Accent::STYLES[:messages]
          w.maximizable true
          w.title         Icon.title(:messages, 'Message Boards')
          w.list_width    20
          w.empty_message '  (no boards configured)'
          w.items         { |ctx| ctx[:boards].boards }
          w.item_label    { |board, ctx| label(board, ctx) }
          w.render_detail { |board, width, ctx| detail(board, width, ctx) }
          w.action(label: '&New', align: :left) { |window, ctx| compose(window, ctx) }
          w.action label: '&Refresh', align: :left do |window, _ctx|
            window.reload_detail
            :keep
          end
        end

        def self.label(board, ctx)
          unread = ctx[:authenticated] ? ctx[:boards].unread(ctx[:username], board.id) : 0
          unread.positive? ? "#{board.title} (#{unread})" : board.title
        end

        def self.detail(board, width, ctx)
          ctx[:boards].mark_read(ctx[:username], board.id) if ctx[:authenticated]
          Formatters::Board.lines(ctx[:boards].messages(board.id, 100), board.title, width)
        end

        def self.compose(window, ctx)
          ctx[:app].open_window(:compose_message, board: window.list_widget.selected_item,
                                                  on_posted: -> { window.reload_detail })
          :keep
        end
      end

      # A post to a board.
      module ComposeMessage
        ERRORS = {
          empty:    'Message cannot be empty.',
          unknown:  'Select a board first.',
          too_fast: "One post every #{BoardService::COOLDOWN} seconds, please."
        }.freeze

        def self.configure(w)
          w.accent Accent::STYLES[:messages]
          w.maximizable true
          w.title        { |ctx| Icon.title(:messages, ctx[:board] ? "Post to #{ctx[:board].title}" : 'Compose') }
          w.width        { |ctx| [ctx[:app].cols - 8, 70].min }
          w.height       14
          w.hint         { |ctx| "From: #{ctx[:username] || AccountService::ANONYMOUS} — Ctrl-Enter sends" }
          w.submit_label '&Send'
          w.cancel_label '&Cancel'
          w.field :body, type: :textarea, max_length: BoardService::MAX_LENGTH
          w.on_submit { |values, form, ctx| submit(values, form, ctx) }
        end

        def self.submit(values, form, ctx)
          return Windows.refuse(form, ERRORS[:unknown]) if ctx[:board].nil?

          result = ctx[:bbs].post_message(ctx[:board], ctx[:username] || AccountService::ANONYMOUS, values[:body],
                                          caller_key: ctx[:caller_key])
          return Windows.refuse(form, ERRORS[result]) if ERRORS.key?(result)

          ctx[:on_posted]&.call
          :close
        end
      end

      # Messages > Oneliners: the wall.
      module Oneliners
        def self.configure(w)
          w.accent Accent::STYLES[:messages]
          w.maximizable true
          w.title  Icon.title(:messages, 'Oneliners')
          w.width  { |ctx| [ctx[:app].cols - 6, 78].min }
          w.height { |ctx| [ctx[:oneliners].recent(30).size + 6, 10].max }
          w.scroll true
          w.body   { |ctx| Formatters::Oneliners.body(ctx[:oneliners].recent(30)) }
          buttons(w)
        end

        def self.buttons(w)
          w.button label: '&Write', align: :left do |window, ctx|
            ctx[:app].write_oneliner(window)
            :keep
          end
          w.button label: '&Close', cancel: true
        end
      end

      # Messages > Voting Booth.
      module Voting
        def self.configure(w)
          w.accent Accent::STYLES[:messages]
          w.maximizable true
          w.title         Icon.title(:messages, 'Voting Booth')
          w.list_width    26
          w.empty_message '  (no polls)'
          w.items         { |ctx| ctx[:voting].polls }
          w.item_label    { |poll, ctx| Formatters::Voting.label(poll, ctx[:voting].ballot(poll, ctx[:username])) }
          w.render_detail { |poll, width, ctx| detail(poll, width, ctx) }
          actions(w)
        end

        def self.actions(w)
          w.bottom_meta { |_poll, _ctx| '✓ voted   • open   Enter or Vote: cast or change your vote' }
          w.on_activate { |poll, window, ctx| ctx[:app].vote_on(poll, window) }
          w.action label: '&Vote', align: :left do |window, ctx|
            ctx[:app].vote_on(window.list_widget.selected_item, window)
            :keep
          end
        end

        def self.detail(poll, width, ctx)
          voting = ctx[:voting]
          Formatters::Voting.detail(poll, voting.results(poll), voting.total(poll), voting.ballot(poll, ctx[:username]),
                                    width)
        end
      end
    end
  end
end
