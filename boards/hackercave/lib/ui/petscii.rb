# frozen_string_literal: true

require_relative 'petscii/screen'
require_relative 'petscii/reader'
require_relative 'logo'

module UI
  # The board on a Commodore 64: PETSCII on a 40×25 screen. A cursor menu,
  # the shelves and their RFCs as numbered lists, an RFC's record on a page
  # with its links, and the reader: the RFC reflowed to 38 columns, in pages
  # that wait for RETURN.
  module Petscii
    LOGO_COLORS = [GN, GN, GN, GN, GN].freeze

    # HACKERCAVE in reversed blocks, five rows.
    def self.logo = BBS::BlockFont.petscii(Logo::WORD, colors: LOGO_COLORS)

    def self.masthead
      rule = " #{DG}#{'─' * (COLS - 2)}#{LG}"
      [rule, *logo, rule, "  #{WH}the hacker's reading room#{LG}",
       "  #{GR}every rfc, from 1969 to today#{LG}", rule]
    end

    def self.flow(bbs)
      BBS::Flow.define do
        call do |_ctx, runner|
          Board.new(bbs.library, bbs.reading, Screen.new(runner.session)).run
          nil
        end
        call do |_ctx, runner|
          BBS::Goodbye.petscii(Screen.new(runner.session), title: 'hackercave bbs', color: GN, width: 38,
                                                            note: 'The RFCs are the work of the IETF.')
          nil
        rescue IOError, Errno::EPIPE, Errno::ECONNRESET
          nil
        end
      end
    end

    # One call: the menu, the shelves, the lists, the record, the reader.
    class Board
      ABOUT = [
        " #{WH}hackercave bbs#{LG}", '',
        ' The hacker\'s reading room of Teletype Games: every RFC, the documents the Internet is made of, ' \
        'from RFC 1 of 1969 to the newest.', '',
        ' The index comes from the RFC Editor (rfc-editor.org) every day. An RFC is fetched the first time ' \
        'someone reads it, and kept for the next reader.', '',
        ' Here the RFCs are reflowed to 38 columns: a figure too wide comes in panels, its columns said ' \
        'above. The RFCs are the work of the IETF and their authors.', '',
        " #{GR}search: 854, std 7, or words; status:standard and year:1983 narrow it.#{LG}"
      ].freeze

      # The most of an abstract a record shows, in characters.
      ABSTRACT = 300

      def initialize(library, reading, screen)
        @library = library
        @reading = reading
        @screen  = screen
        @seen    = Set.new
      end

      def run
        @screen.cls
        Petscii.masthead.each { |l| @screen.puts l }
        loop do
          @screen.puts
          @screen.puts " #{GR}#{index_line}#{LG}"
          @choice = @screen.menu(menu_items, index: menu_items.index { |i| i.value == @choice }, back: 'q',
                                             hint: 'crsr: choose  return: take')
          return if @choice == 'q'

          take(@choice)
          @screen.title('HACKERCAVE BBS', index_note)
        end
      end

      private

      def menu_items
        @menu_items ||= [
          BBS::Selector.item('classics', key: '1', value: '1', about: 'the rfcs the internet is built on'),
          BBS::Selector.item('telnet', key: '2', value: '2', about: 'the protocol of this board'),
          BBS::Selector.item('april 1st', key: '3', value: '3', about: 'the rfcs of april fools\' day'),
          BBS::Selector.item('all shelves', key: '4', value: '4', about: 'series, status, decades, newest'),
          BBS::Selector.item('search', key: '5', value: '5', about: 'a number, std 7, or words'),
          BBS::Selector.item('most read on this board', key: '6', value: '6', about: 'what the callers here read'),
          BBS::Selector.item('about', key: 'a', value: 'a', about: 'the board, the rfcs, the keys'),
          BBS::Selector.item('log off', key: 'q', value: 'q', about: 'hang up. see you!')
        ]
      end

      def take(choice)
        case choice
        when '1', '2', '3' then shelf(@library.own_shelves[choice.to_i - 1])
        when '4' then shelves
        when '5' then search
        when '6' then most_read
        when 'a' then @screen.page('ABOUT', ABOUT)
        end
      end

      def index_line = @library.ready? ? "#{@library.count} rfcs in the index" : 'the index is being prepared'

      def index_note = @library.ready? ? "#{@library.count} rfcs" : ''

      def not_ready
        message('The index is being prepared: it is downloaded from the RFC Editor and indexed. Try again in a ' \
                'minute. The classics, telnet and april 1st shelves are open meanwhile.')
      end

      def shelves
        return not_ready unless @library.ready?

        list = @library.shelves
        loop do
          picked = @screen.pick('SHELVES', list, right: "#{list.size} shelves") do |s|
            "#{s.name.downcase} #{GR}#{s.count}#{LG}"
          end
          return unless picked

          shelf(picked)
        end
      end

      def shelf(shelf)
        return not_ready unless shelf

        entries(shelf.name.upcase[0, 26], @library.entries_on(shelf))
      end

      def search
        return not_ready unless @library.ready?

        @screen.title('SEARCH')
        @screen.say('An rfc number (854), a series (std 7), or words. status:standard and year:1983 narrow it.',
                    color: GR)
        @screen.puts
        query = BBS::Field.ask(@screen.session, ' search> ', max: 60)
        return if query.nil? || query.strip.empty?

        found(query, @library.search(query))
      end

      def found(query, result)
        case result
        when :too_short then message('A word of two letters or more, please.')
        when [] then message('Nothing found. Fewer or other words?')
        when Array
          return message(refused(*result)) if result.first.is_a?(Symbol)

          entries("SEARCH: #{query.strip.upcase}"[0, 26], result)
        end
      end

      def refused(why, number)
        why == :not_issued ? "RFC #{number} was never issued." : "There is no RFC #{number} yet."
      end

      def most_read
        list = @library.most_read
        return message('Nothing has been read here yet. Be the first!') if list.empty?

        entries('MOST READ HERE', list)
      end

      def message(text)
        @screen.puts
        @screen.say(text, color: YE)
        @screen.pause
      end

      def entries(heading, list)
        loop do
          entry = @screen.pick(heading, list, empty: 'no rfcs here.', right: "#{list.size} rfcs") { |e| label(e) }
          return unless entry

          record(entry)
        end
      end

      # The number and the title; the number of reads before them in the
      # Most read list, the relation in a list of links.
      def label(entry)
        prefix = case entry.kind
                 when :reads then "#{GR}#{entry.note}#{LG} "
                 when :series then "#{GR}#{entry.note.downcase}#{LG} "
                 when :relation then "#{GR}#{entry.note.split.first}#{LG} "
                 end
        "#{prefix}#{entry.number} #{entry.rfc.title.downcase}"
      end

      # An RFC's record, and what to do with it: read, links, QR code.
      def record(entry)
        rfc = entry.rfc
        loop do
          @screen.page(rfc.name, card(entry), wait: false)
          case @screen.actions(%w[r read], %w[l links], ['c', 'qr code'], %w[q back])
          when 'r' then open_rfc(rfc)
          when 'l' then links(rfc)
          when 'c' then qr(rfc)
          else return
          end
        end
      end

      def card(entry)
        rfc = entry.rfc
        [*lines(@screen.plain(rfc.title), WH), *(lines(@screen.plain(entry.note), CY) if entry.kind == :remark),
         *lines(@screen.plain(rfc.author_list.first(3).join(', ')), LB), " #{GR}#{facts(rfc)}#{LG}",
         *relation_lines(rfc), '', *lines(@screen.plain(short(rfc.abstract.split("\n\n").first.to_s)))]
      end

      # +text+ cut at a word to fit about ABSTRACT characters.
      def short(text) = text.length <= ABSTRACT ? text : "#{text[0, ABSTRACT].sub(/\s+\S*\z/, '')}..."

      def facts(rfc)
        reads = @library.reads(rfc)
        status = @library.series_of(rfc).first || rfc.status_label
        [rfc.date_label, status, "#{reads} read#{'s' unless reads == 1}"].reject(&:empty?).join(' . ').downcase
      end

      def relation_lines(rfc)
        @library.relations(rfc).flat_map do |kind, numbers|
          lines("#{kind}: #{numbers.first(6).join(', ')}#{' ...' if numbers.size > 6}",
                kind == 'obsoleted by' ? RD : GR)
        end
      end

      # +text+ wrapped, each line indented and in +color+.
      def lines(text, color = nil)
        @screen.wrap(text).map { |l| color ? " #{color}#{l}#{LG}" : " #{l}" }
      end

      def links(rfc)
        list = @library.links(rfc)
        return message("#{rfc.name} does not obsolete or update any other.") if list.empty?

        entries("LINKS OF #{rfc.name}", list)
      end

      def open_rfc(rfc)
        @screen.puts " #{GR}opening #{rfc.name.downcase}...#{LG}"
        doc = @reading.open(rfc, seen: @seen)
        return Reader.new(@screen, @reading, rfc, doc).read unless doc.is_a?(Symbol)

        message(doc == :no_text ? "The RFC Editor has no plain text of #{rfc.name}." : 'The RFC Editor did not answer. ' \
          'Try again in a minute.')
      end

      # The RFC's page at the RFC Editor as a QR code, in the middle of the
      # screen.
      def qr(rfc)
        @screen.title(rfc.name, 'scan me ')
        code   = qr_code(rfc.link)
        indent = ' ' * ((COLS - 1 - BBS::FrameBuffer.plain(code.first).size) / 2)
        code.each { |line| @screen.puts("#{indent}#{line}") }
        @screen.pause
      rescue BBS::QR::TooLong
        message("The address is too long for a QR code: #{rfc.url}")
      end

      def qr_code(link)
        BBS::QR.petscii(link)
      rescue BBS::QR::TooLong
        BBS::QR.petscii(link, quiet: 1)
      end
    end
  end
end
