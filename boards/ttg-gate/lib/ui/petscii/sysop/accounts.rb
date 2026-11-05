# frozen_string_literal: true

module UI
  module Petscii
    module Sysop
      # The accounts of the network by name, a row each (a red * for a
      # banned one, the name, the roles in short). / searches names and
      # roles, RETURN opens the account.
      class Accounts < Views::Picker
        include Shared

        PER_PAGE = 18
        # The roles in a row, short.
        SHORT = { 'member' => 'M', 'sysop' => 'S', 'blogger' => 'B', 'wiki-supervisor' => 'W' }.freeze
        HINT = [['RETURN', true], [' Open  ', false], ['/', true], [' Find  ', false], ['+/-', true], [' Page  ', false],
                ['←', true], [' Back', false]].freeze

        key('/') { guarded { search } }

        def initialize(accounts)
          @accounts = accounts
          @query    = nil
          super(accounts.accounts, per_page: PER_PAGE)
        end

        # Back from an account: its roles or ban may have changed.
        def resume = reload_items(@accounts.accounts(@query))

        def hint = HINT

        def take(entry) = guarded { push(Account.new(@accounts, entry.name)) }

        def draw(canvas)
          right = [@query, page_mark].compact.reject(&:empty?).join(' ')
          Layout.band(canvas, 'ACCOUNTS', right, Canvas::YELLOW)
          return canvas.text(Layout.row(2), 1, 'No account here.', Canvas::GREY) if items.empty?

          on_page.each_with_index { |entry, slot| row(canvas, Layout.row(1 + slot), entry, slot) }
          canvas.text(Layout.row(Layout::ROWS - 1), 1, 'M member S sysop B blogger W wiki', Canvas::DARK_GREY)
        end

        private

        def roles(entry) = entry.roles.map { |r| SHORT.fetch(r, r[0].upcase) }.join

        def row(canvas, row, entry, slot)
          name = Layout.plain(entry.name)[0, 28].ljust(29)
          mark = entry.banned? ? '*' : ' '
          if slot == @index
            canvas.text(row, 0, "#{mark}#{name} #{roles(entry)}".ljust(Layout::WIDTH), Canvas::CYAN, rvs: true)
          else
            Layout.runs(canvas, row, 0, [[mark, Canvas::LIGHT_RED], [name, entry.banned? ? Canvas::GREY : Canvas::WHITE],
                                         [" #{roles(entry)}", Canvas::YELLOW]])
          end
        end

        def search
          text = read_line('Find:', text: @query.to_s, max: 20)&.strip
          return if text.nil?

          @query = text.empty? ? nil : text
          @items = []
          reload_items(@accounts.accounts(@query))
          @page = 0
          @index = 0
        end
      end
    end
  end
end
