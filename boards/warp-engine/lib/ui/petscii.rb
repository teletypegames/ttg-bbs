# frozen_string_literal: true

require_relative 'petscii/screen'
require_relative 'transfer'
require_relative 'logo'

module UI
  # The board on a Commodore 64: PETSCII on a 40×25 screen. A one-key menu
  # of the shelves, their titles as numbered lists, a title on a page of its
  # own, and its download by XMODEM-1K or XMODEM, the protocols a C64
  # terminal knows.
  module Petscii
    LOGO_COLORS = [LB, LB, CY, CY, WH].freeze

    # WARP in reversed blocks, five rows.
    def self.logo
      Logo.rows.each_with_index.map do |line, row|
        blocks = line.gsub(/#+/) { |run| "#{RV}#{' ' * run.size}#{RO}" }.tr('.', ' ')
        "          #{LOGO_COLORS[row]}#{blocks}#{LG}"
      end
    end

    def self.masthead
      rule = " #{DG}#{'─' * (COLS - 2)}#{LG}"
      [rule, '', *logo, '', rule,
       "  #{WH}the file area of teletype games#{LG}", "  #{GR}telnet downloads for your c64#{LG}", rule]
    end

    def self.flow(bbs)
      BBS::Flow.define do
        call do |ctx, runner|
          Board.new(bbs.catalog, Screen.new(runner.session), ctx).run
          nil
        end
        call do |_ctx, runner|
          Petscii.goodbye(Screen.new(runner.session))
          nil
        rescue IOError, Errno::EPIPE, Errno::ECONNRESET
          nil
        end
      end
    end

    def self.goodbye(screen)
      screen.cls
      screen.puts
      screen.puts " #{LB}#{RV}#{' thanks for calling warpengine bbs'.ljust(39)}#{RO}#{LG}"
      screen.puts
      screen.say('More of us: teletypegames.org', GR)
      screen.puts
      sleep 1.2
      screen.puts " #{LG}+++"
      sleep 0.6
      screen.puts ' ATH0'
      sleep 0.4
      screen.puts " #{RD}NO CARRIER#{LG}"
      screen.puts
    end

    # One call: the shelves, their titles, the downloads.
    class Board
      PROTOCOL_KEYS = { '1' => :xmodem_1k, 'x' => :xmodem }.freeze

      HELP = [
        " #{WH}1#{LG} xmodem-1k is the faster one; #{WH}x#{LG} plain xmodem is for a terminal that has no 1k.", '',
        ' Pick a title and a protocol, then start the download in your terminal: in ccgms, ' \
        'novaterm or ultimateterm it is the download or receive menu. It asks for a file name, ' \
        'and saves the file as a program on your disk.', '',
        ' The board waits a minute for your terminal. run/stop gives up.', '',
        ' Every file is checked against its shelf before it goes. Xmodem fills its last block up, ' \
        'so the file on your disk may be a little longer: it loads all the same.'
      ].freeze

      def initialize(catalog, screen, ctx)
        @catalog = catalog
        @screen  = screen
        @ctx     = ctx
      end

      def run
        @screen.cls
        @screen.puts
        Petscii.masthead.each { |l| @screen.puts l }
        loop do
          shelves = @catalog.shelves
          @screen.puts
          shelves.each_with_index { |s, i| @screen.puts " #{YE}#{i + 1}#{LG} #{s.name.downcase}" }
          @screen.puts " #{YE}H#{LG} how to download"
          @screen.puts " #{YE}Q#{LG} log off"
          keys = [*shelves.each_index.map { |i| (i + 1).to_s }, 'h', 'q']
          case (k = @screen.choose("\r\n #{WH}warp#{LG}> ", keys, back: 'q'))
          when 'h' then help
          when 'q' then return
          else shelf(shelves[k.to_i - 1])
          end
          @screen.title('WARPENGINE BBS')
        end
      end

      private

      def shelf(shelf)
        @screen.puts " #{GR}reading the shelf…#{LG}"
        loop do
          titles = @catalog.titles(shelf)
          unless titles
            @screen.puts
            @screen.say('The archive did not answer. Try again later.', RD)
            @screen.pause
            return
          end

          title = @screen.pick(shelf.name.upcase, titles, empty: 'this shelf is empty right now.',
                                                          right: "#{titles.size} titles") do |t|
            "#{t.title} #{GR}#{t.version}#{LG}"
          end
          return unless title

          show(shelf, title)
        end
      end

      def show(shelf, title)
        count = @catalog.downloads(title)
        lines = [*@screen.wrap(title.title).map { |l| " #{WH}#{l}#{LG}" },
                 " #{CY}v#{title.version}#{LG}  #{title.size} bytes",
                 " #{GR}#{title.author.downcase}  #{count} download#{'s' unless count == 1}#{LG}", '',
                 *@screen.wrap(title.about).map { |l| " #{l}" }, '',
                 " #{GR}load\"#{title.disk_name.downcase}\",8,1 and run#{LG}"]
        @screen.page(shelf.name.upcase, lines, wait: false)
        @screen.puts " #{YE}1#{LG} xmodem-1k  #{YE}X#{LG} xmodem  #{YE}Q#{LG} back"
        k = @screen.choose(" #{WH}download#{LG}> ", [*PROTOCOL_KEYS.keys, 'q'], back: 'q')
        download(title, PROTOCOL_KEYS[k]) if PROTOCOL_KEYS.key?(k)
      end

      def download(title, protocol)
        @screen.title("DOWNLOAD #{title.disk_name}")
        @screen.puts " #{GR}fetching #{title.file.downcase}…#{LG}"
        data = @catalog.fetch(title)
        if data.is_a?(Symbol)
          @screen.puts
          @screen.say(Transfer.refusal(data, title), RD)
          @screen.pause
          return
        end

        @screen.puts
        @screen.say(Transfer.start(protocol, title), WH)
        @screen.puts
        result = Transfer.send_file(@screen.session, protocol, title, data)
        raise IOError, 'the caller hung up' if result == :hangup

        @catalog.downloaded(title, protocol) if result == :ok
        @screen.title("DOWNLOAD #{title.disk_name}")
        @screen.puts
        @screen.say(Transfer.result(result, protocol, title), result == :ok ? GN : RD)
        @screen.pause
      end

      def help = @screen.page('HOW TO DOWNLOAD', HELP)
    end
  end
end
