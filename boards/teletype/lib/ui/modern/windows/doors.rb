# frozen_string_literal: true

module UI
  module Modern
    module Windows
      # Doors > Door Lobby: every door with what it is, the way the old
      # boards had a door menu.
      module Doors
        def self.configure(w)
          w.accent Accent::STYLES[:doors]
          w.maximizable true
          w.title         Icon.title(:doors, 'Door Lobby')
          w.list_width    22
          w.items         { |ctx| ctx[:bbs].doors }
          w.item_label    { |door, _ctx| door.title }
          w.render_detail { |door, width, ctx| detail(door, width, ctx) }
          w.bottom_meta   { |_door, _ctx| 'Enter or Open: step in · leaving the door brings you back' }
          w.on_activate   { |door, _window, ctx| ctx[:app].open_door(door.name) }
          w.action(label: '&Open', align: :left) { |window, ctx| step_in(window.list_widget.selected_item, ctx) }
        end

        def self.step_in(door, ctx) = door ? ctx[:app].open_door(door.name) : :keep

        def self.detail(door, width, ctx)
          inside = ctx[:online].nodes.count { |n| n.activity.to_s == "Door: #{door.title}" }
          Formatters::Doors.detail(door, width, inside: inside)
        end
      end
    end
  end
end
