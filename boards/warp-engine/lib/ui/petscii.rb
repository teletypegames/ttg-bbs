# frozen_string_literal: true

require_relative 'wording'

module UI
  # The board on a Commodore 64: PETSCII on a 40×25 screen. A cursor menu of
  # the directories, their titles as numbered lists, a title on a page of its own,
  # and its download by XMODEM-1K or XMODEM, the protocols a C64 terminal
  # knows; the network's wall and feedback (ttg-common).
  class Petscii < Rubbs::Petscii::Face
    include TTG::Network::Petscii

    LOGO_COLORS   = [LB, LB, CY, CY, WH].freeze
    PROTOCOL_KEYS = { '1' => :xmodem_1k, 'x' => :xmodem }.freeze

    HELP = [
      " #{WH}1#{LG} xmodem-1k is the faster one; #{WH}x#{LG} plain xmodem is for a terminal that has no 1k.", '',
      ' Pick a title and a protocol, then start the download in your terminal: in ccgms, ' \
      'novaterm or ultimateterm it is the download or receive menu. It asks for a file name, ' \
      'and saves the file as a program on your disk.', '',
      ' The board waits a minute for your terminal. run/stop gives up.', '',
      ' Every file is checked against its directory before it goes. Xmodem fills its last block up, ' \
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
      each_of(-> { catalog.directories }) do |directory, i|
        name = directory.name.downcase
        item((i + 1).to_s, name, "#{name} titles to download") { open_directory(directory) }
      end
      item('h', 'how to download', 'protocols, terminals, file names') { page('HOW TO DOWNLOAD', HELP) }
      item('w', 'the engine room wall', 'tell the others what you loaded') { TTG::Wall.open(@session) }
      item('f', 'write to the sysops', 'a file that will not load, a bug') { TTG::Feedback.open(@session) }
      log_off
    end

    # The Directory another board asked for (TTG::Network: <tt>directory:ID</tt>) first, then the
    # masthead and the main menu.
    def run
      id = TTG::Network.place_of(@session.take_goto, 'directory')
      directory = id && catalog.directories.find { |d| d.id == id }
      open_directory(directory) if directory
      super
    end

    private

    def open_directory(directory)
      say('reading the directory…', color: GR)
      loop do
        titles = catalog.titles(directory) || fail_with(Wording::NO_ANSWER)
        picked = pick(
          directory.name.upcase,
          titles,
          empty: 'this directory is empty right now.',
          right: "#{titles.size} titles"
        ) do |t|
          "#{t.title} #{GR}#{t.version}#{LG}"
        end
        return unless picked

        show_title(directory, picked)
      end
    end

    def show_title(directory, title)
      page(directory.name.upcase, title_lines(title), wait: false)
      key = actions(%w[1 xmodem-1k], %w[x xmodem], *machine_key(directory), %w[q back])
      return network(TTG::Network.directory_links(directory.id)) if key == 'm'

      download(title, PROTOCOL_KEYS[key]) if PROTOCOL_KEYS.key?(key)
    end

    # The page of +title+: its name, version, size, author, downloads, about and how to load it.
    def title_lines(title)
      count = catalog.downloads(title)
      [*wrap(title.title).map { |l| " #{WH}#{l}#{LG}" },
       " #{CY}v#{title.version}#{LG}  #{title.size} bytes",
       " #{GR}#{title.author.downcase}  #{count} download#{'s' unless count == 1}#{LG}", '',
       *wrap(title.about).map { |l| " #{l}" }, '',
       " #{GR}load\"#{title.disk_name.downcase}\",8,1 and run#{LG}"]
    end

    # The M key of a title's page when its Directory's machine is on Siliconia BBS.
    def machine_key(directory) = TTG::Network.reachable(TTG::Network.directory_links(directory.id)).any? ? [%w[m machine]] : []

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
