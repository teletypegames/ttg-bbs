# frozen_string_literal: true

module UI
  module Modern
    module Windows
      # People: the team, who is online, the last callers, the user listing
      # and the Hall of Fame as lists (the trophy case under 80 columns).
      module People
        extend Section

        section :people do
          window :team, :info do
            maximizable true
            title  'The Team'
            width  64
            height { [rows - 4, 22].min }
            scroll true
            body   { Formatters::Team.body(site.members) }
          end

          window :online_users, :info do
            title  'Who is Online'
            width  74
            scroll true
            height { [online.count + 8, 10].max }
            body   { Formatters::Nodes.body(online.nodes, session_id) }
          end

          window :last_callers, :info do
            title  'Last Callers'
            width  64
            scroll true
            height { [last_callers.recent(15).size + 6, 10].max }
            body   { Formatters::Users.last_callers_list(last_callers.recent(15)) }
          end

          window :user_list, :info do
            maximizable true
            title  'User Listing'
            width  74
            scroll true
            height { (accounts.names.size + 9).clamp(10, [rows - 4, 10].max) }
            body   { Formatters::UserList.body(bbs.user_rows) }
          end

          window :hall_of_fame, :info do
            maximizable true
            title  'Hall of Fame'
            width  { fame_width }
            height { [rows - 4, 24].min }
            scroll true
            body   { Formatters::HallOfFame.body(**bbs.hall_of_fame, width: fame_width - 8) }
          end
        end

        helpers do
          def fame_width = [cols - 6, 76].min
        end
      end
    end
  end
end
