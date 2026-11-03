# frozen_string_literal: true

module UI
  module Modern
    module Windows
      # Messages > Boards, the post to one, Oneliners and the Voting Booth.
      module Messages
        POST_ERRORS = {
          empty:    'Message cannot be empty.',
          unknown:  'Select a board first.',
          too_fast: "One post every #{BoardService::COOLDOWN} seconds, please."
        }.freeze

        extend Section

        section :messages do
          # The boards on the left, the newest posts of the chosen one on the right.
          window :messages, :master_detail do
            title 'Message Boards'
            list_width 20
            empty '  (no boards configured)'
            items { boards.boards }
            label { |board| board_label(board) }
            detail { |board, width| board_lines(board, width) }
            action('New', align: :left) do |board|
              show(:compose_message, board: board, on_posted: -> { window.reload_detail })
            end
            action('Refresh', align: :left) { window.reload_detail }
          end

          # A post to a board.
          window :compose_message, :form do
            maximizable true
            title { board ? "Post to #{board.title}" : 'Compose' }
            width { [cols - 8, 70].min }
            height 14
            hint { "From: #{caller_name} — Ctrl-Enter sends" }
            submit_label '&Send'
            cancel_label '&Cancel'
            field :body, type: :textarea, max_length: BoardService::MAX_LENGTH
            errors POST_ERRORS
            on_submit do |values|
              next :unknown unless board

              result = bbs.post_message(board, caller_name, values[:body], caller_key: caller_key)
              extras[:on_posted]&.call if result == :ok
              result
            end
          end

          # The wall.
          window :oneliners, :info do
            maximizable true
            title 'Oneliners'
            width { [cols - 6, 78].min }
            height { [oneliners.recent(30).size + 6, 10].max }
            scroll true
            body { Formatters::Oneliners.body(oneliners.recent(30)) }
            button('Write', align: :left) do
              write_oneliner(window)
              keep
            end
            button 'Close', cancel: true
          end

          window :voting, :master_detail do
            title 'Voting Booth'
            list_width 26
            empty '  (no polls)'
            items { voting.polls }
            label { |poll| Formatters::Voting.label(poll, voting.ballot(poll, context[:username])) }
            detail { |poll, width| poll_detail(poll, width) }
            meta { '✓ voted   • open   Enter or Vote: cast or change your vote' }
            on_pick { |poll| vote_on(poll, window) }
            action('Vote', align: :left) { |poll| vote_on(poll, window) }
          end
        end

        helpers do
          def board_label(board)
            unread = registered? ? boards.unread(context[:username], board.id) : 0
            unread.positive? ? "#{board.title} (#{unread})" : board.title
          end

          def board_lines(board, width)
            boards.mark_read(context[:username], board.id) if registered?
            Formatters::Board.lines(boards.messages(board.id, 100), board.title, width)
          end

          def poll_detail(poll, width)
            Formatters::Voting.detail(poll, voting.results(poll), voting.total(poll),
                                      voting.ballot(poll, context[:username]), width)
          end
        end
      end
    end
  end
end
