# frozen_string_literal: true

module UI
  module Modern
    module Windows
      # Doors > Door Lobby: every door with what it is, the way the old
      # boards had a door menu.
      module Doors
        extend Section

        section :doors do
          window :doors, :master_detail do
            title      'Door Lobby'
            list_width 22
            items      { board.doors }
            label      :title
            detail     { |door, width| Formatters::Doors.detail(door, width, inside: inside(door)) }
            meta       { 'Enter or Open: step in · leaving the door brings you back' }
            on_pick    { |door| open_door(door.name) }
            action('Open', align: :left) { |door| open_door(door.name) }
          end
        end

        helpers do
          def inside(door) = online.nodes.count { |n| n.activity.to_s == "Door: #{door.title}" }
        end
      end
    end
  end
end
