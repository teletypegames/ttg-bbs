# frozen_string_literal: true

module UI
  module Modern
    # The years, the genres or the companies of one letter, each with its
    # count; the right pane lists the first games of the one picked.
    module GroupsWindow
      extend Rubbs::Modern::Part

      window :groups, :master_detail do
        empty 'Nothing here.'
        height(-6)
        title      { caption }
        list_width { [32, cols / 3].max }
        items      { groups }
        label      { |(name, count)| "#{name} (#{count})" }
        detail     { |(name, count), width| group_card(kind, name, count, width) }
        meta       { 'Enter lists the games' }
        on_pick    { |(name, _count)| open_group(kind, name) }
      end
    end
  end
end
