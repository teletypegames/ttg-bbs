# frozen_string_literal: true

require_relative 'switchboard'

module UI
  module Petscii
    # A switchboard of Global Discovery on the C64: the same frame, rain and
    # pages, eight nodes a page, but each node a board of the catalog (its
    # state mark instead of the colour block, its country at the edge, its
    # address, software and state under the frame) or an entry of a menu.
    class DiscoveryBoard < Switchboard
      # The state marks in the C64's graphics set.
      MARKS = {
        'online' => ['●', Canvas::LIGHT_GREEN], 'flaky' => ['●', Canvas::YELLOW], 'down' => ['╳', Canvas::RED],
        'dead' => ['┼', Canvas::GREY], 'unknown' => ['?', Canvas::LIGHT_GREY]
      }.freeze

      # An entry of a menu: its +name+, the +right+ text (a count), and what
      # the info lines say of it.
      Entry = Data.define(:name, :right, :about, :action)

      HELP_LIST = [['RETURN', true], [' OPEN  ', false], ['/', true], [' FIND  ', false],
                   ['+/-', true], [' PAGE  ', false], ['Q', true], [' BACK', false]].freeze
      HELP_HOME = [['RETURN', true], [' OPEN  ', false], ['/', true], [' FIND  ', false],
                   ['G', true], [' OWN  ', false], ['Q', true], [' EXIT', false]].freeze
      HELP_MENU = [['CRSR', true], ['  ', false], ['RETURN', true], [' OPEN   ', false], ['Q', true], [' BACK', false]].freeze

      # [items]  ListingModels or Entries
      # [title]  the frame's label
      # [help]   :list, :home or :menu
      def initialize(items, title:, help: :list, tagline: "THE WORLD'S TELNET BBSES", now: -> { Time.now.to_i }, **)
        @title   = " #{title.upcase[0, 18]} "
        @help    = help
        @tagline = tagline
        @now     = now
        @twins   = items.grep_v(Entry).group_by(&:title).select { |_, l| l.size > 1 }.keys
        super(items, **)
      end

      # The mark and its colour of a state.
      def self.mark(state) = MARKS.fetch(state, MARKS['unknown'])

      private

      attr_reader :title, :tagline

      def name_width = 21

      def info_labels = @help == :list ? %w[ADDR INFO STATE] : ['', '', '']

      def help_parts
        case @help
        when :home then HELP_HOME
        when :menu then HELP_MENU
        else HELP_LIST
        end
      end

      def node_view(item)
        return entry_view(item) if item.is_a?(Entry)

        mark, color = DiscoveryBoard.mark(item.state)
        status = item.status(@now.call)
        name = item.title
        name = "#{name[0, name_width - item.port.to_s.length - 2].rstrip} :#{item.port}" if @twins.include?(name)
        Node.new(name: name, right: item.country.to_s, mark: mark, mark_color: color, lit_mark: mark,
                 addr: item.address, tags: [item.software, item.country&.upcase].compact.join(' / '),
                 link: status.empty? ? item.state : status)
      end

      def entry_view(entry)
        lines = Array(entry.about)
        Node.new(name: entry.name, right: entry.right.to_s, mark: '>', mark_color: Canvas::GREEN, lit_mark: '>',
                 addr: lines[0], tags: lines[1], link: lines[2])
      end
    end
  end
end
