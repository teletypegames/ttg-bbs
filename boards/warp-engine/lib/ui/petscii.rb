# frozen_string_literal: true

require_relative 'wording'

module UI
  # The board on a Commodore 64: PETSCII on a 40×25 screen. A cursor menu of
  # the shelves, their titles as numbered lists, a title on a page of its own,
  # and its download by XMODEM-1K or XMODEM, the protocols a C64 terminal
  # knows; the network's wall and feedback (ttg-common).
  class Petscii < Rubbs::Petscii::Face
    LOGO_COLORS   = [LB, LB, CY, CY, WH].freeze
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

    title 'WARPENGINE BBS'

    masthead do
      gap
      rule
      gap
      logo 'WARP', colors: LOGO_COLORS, indent: 10
      gap
      rule
      line 'the file area of teletype games', color: WH, indent: 2
      line 'telnet downloads for your c64', color: GR, indent: 2
      rule
    end

    main_menu do
      each_of(-> { catalog.shelves }) do |shelf, i|
        name = shelf.name.downcase
        item((i + 1).to_s, name, "#{name} titles to download") { open_shelf(shelf) }
      end
      item('h', 'how to download', 'protocols, terminals, file names') { page('HOW TO DOWNLOAD', HELP) }
      item('w', 'the engine room wall', 'tell the others what you loaded') { TTG::Wall.open(@session) }
      item('f', 'write to the sysops', 'a file that will not load, a bug') { TTG::Feedback.open(@session) }
      log_off
    end

    private

    def open_shelf(shelf)
      say('reading the shelf…', color: GR)
      loop do
        titles = catalog.titles(shelf) || fail_with(Wording::NO_ANSWER)
        picked = pick(shelf.name.upcase, titles, empty: 'this shelf is empty right now.', right: "#{titles.size} titles") do |t|
          "#{t.title} #{GR}#{t.version}#{LG}"
        end
        return unless picked

        show_title(shelf, picked)
      end
    end

    def show_title(shelf, title)
      count = catalog.downloads(title)
      lines = [*wrap(title.title).map { |l| " #{WH}#{l}#{LG}" },
               " #{CY}v#{title.version}#{LG}  #{title.size} bytes",
               " #{GR}#{title.author.downcase}  #{count} download#{'s' unless count == 1}#{LG}", '',
               *wrap(title.about).map { |l| " #{l}" }, '',
               " #{GR}load\"#{title.disk_name.downcase}\",8,1 and run#{LG}"]
      page(shelf.name.upcase, lines, wait: false)
      key = actions(%w[1 xmodem-1k], %w[x xmodem], %w[q back])
      download(title, PROTOCOL_KEYS[key]) if PROTOCOL_KEYS.key?(key)
    end

    def download(file, protocol)
      title("DOWNLOAD #{file.disk_name}")
      say("fetching #{file.file.downcase}…", color: GR)
      data = catalog.fetch(file)
      return alert(Wording.refusal(data, file)) if data.is_a?(Symbol)

      result = transfer(file, protocol, data)
      catalog.downloaded(file, protocol) if result == :ok
      title("DOWNLOAD #{file.disk_name}")
      text = Rubbs::Common::Files::Transfer.result(result, protocol, file.file)
      result == :ok ? notice(text) : alert(text)
    end

    def transfer(file, protocol, data)
      puts
      say(Rubbs::Common::Files::Transfer.start(protocol, file.file, file.size, save_as: file.disk_name), color: WH)
      puts
      Rubbs::Common::Files::Transfer.send(session, protocol, file.file, data)
    end
  end
end
