# frozen_string_literal: true

module UI
  module Modern
    module Windows
      # People > Team.
      module Team
        def self.configure(w)
          w.accent Accent::STYLES[:people]
          w.maximizable true
          w.title  Icon.title(:people, 'The Team')
          w.width  64
          w.height { |ctx| [ctx[:app].rows - 4, 22].min }
          w.scroll true
          w.body   { |ctx| Formatters::Team.body(ctx[:site].members) }
        end
      end

      # People > Who is Online: the nodes.
      module OnlineUsers
        def self.configure(w)
          w.accent Accent::STYLES[:people]
          w.title  Icon.title(:people, 'Who is Online')
          w.width  74
          w.scroll true
          w.height { |ctx| [ctx[:online].count + 8, 10].max }
          w.body   { |ctx| Formatters::Nodes.body(ctx[:online].nodes, ctx[:app].session_id) }
        end
      end

      # People > Last Callers.
      module LastCallers
        def self.configure(w)
          w.accent Accent::STYLES[:people]
          w.title  Icon.title(:people, 'Last Callers')
          w.width  64
          w.scroll true
          w.height { |ctx| [ctx[:last_callers].recent(15).size + 6, 10].max }
          w.body   { |ctx| Formatters::Users.last_callers_list(ctx[:last_callers].recent(15)) }
        end
      end

      # People > User Listing: the registered names.
      module UserList
        def self.configure(w)
          w.accent Accent::STYLES[:people]
          w.maximizable true
          w.title  Icon.title(:people, 'User Listing')
          w.width  74
          w.scroll true
          w.height { |ctx| (ctx[:accounts].names.size + 9).clamp(10, [ctx[:app].rows - 4, 10].max) }
          w.body   { |ctx| Formatters::UserList.body(ctx[:bbs].user_rows) }
        end
      end

      # People > Hall of Fame, as lists (the trophy case under 80 columns).
      module HallOfFame
        def self.configure(w)
          w.accent Accent::STYLES[:people]
          w.maximizable true
          w.title  Icon.title(:people, 'Hall of Fame')
          w.width  { |ctx| width(ctx) }
          w.height { |ctx| [ctx[:app].rows - 4, 24].min }
          w.scroll true
          w.body   { |ctx| Formatters::HallOfFame.body(**ctx[:bbs].hall_of_fame, width: width(ctx) - 8) }
        end

        def self.width(ctx) = [ctx[:app].cols - 6, 76].min
      end
    end
  end
end
