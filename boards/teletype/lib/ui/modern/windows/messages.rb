# frozen_string_literal: true

module UI
  module Modern
    module Windows
      # Messages > Voting Booth. The wall and the letters to the sysop open
      # on the whole screen (Helpers#open_wall, Helpers#write_feedback).
      module Messages
        extend Section

        section :messages do
          window :voting, :master_detail do
            title 'Voting Booth'
            list_width 26
            empty '  (no polls)'
            items { voting.polls }
            label { |poll| Formatters::Voting.label(poll, voting.ballot(poll, caller_name)) }
            detail { |poll, width| poll_detail(poll, width) }
            meta { '✓ voted   • open   Enter or Vote: cast or change your vote' }
            on_pick { |poll| vote_on(poll, window) }
            action('Vote', align: :left) { |poll| vote_on(poll, window) }
          end
        end

        helpers do
          def poll_detail(poll, width)
            Formatters::Voting.detail(poll, voting.results(poll), voting.total(poll), voting.ballot(poll, caller_name), width)
          end
        end
      end
    end
  end
end
