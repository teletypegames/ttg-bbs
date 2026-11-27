# frozen_string_literal: true

require 'yaml'

module TTG
  # Our boards, one dialling another with a place to open (Rubbs::Common::Line::Gateway#to):
  # the links between Siliconia BBS (the machines), Commodex BBS (the C64 games) and WarpEngine
  # BBS (our titles in a Directory of each machine). The boards run in one network namespace, so
  # a board dials another on HOST, on its port of the root boards.yml; the call is forwarded (the
  # face, the caller's address, a signed-in caller's identity) and comes back when the caller
  # leaves the other board.
  #
  #   TTG::Network.machine_links('Q99775')        # => [["its games on Commodex BBS", "commodex", nil], …]
  #   TTG::Network.visit(session, 'siliconia', 'machine:Q99775')
  module Network
    # Where the boards answer (+TTG_NETWORK_HOST+, default the loopback of the shared namespace).
    HOST = ENV.fetch('TTG_NETWORK_HOST', '127.0.0.1')

    # The boards by folder: their names.
    BOARDS = { 'commodex' => 'Commodex BBS', 'warp-engine' => 'WarpEngine BBS', 'siliconia' => 'Siliconia BBS' }.freeze

    # The machines the boards share, by Wikidata QID: the name, the WarpEngine BBS Directory of
    # their titles, and whether Commodex BBS has their games.
    MACHINES = {
      'Q99775'   => { name: 'Commodore 64', directory: 'c64', games: true },
      'Q868568'  => { name: 'Commodore Plus/4', directory: 'plus4', games: false },
      'Q1115913' => { name: 'Commodore 16', directory: 'plus4', games: false }
    }.freeze

    # The QID of the Commodore 64, the machine of every Commodex game.
    C64 = 'Q99775'

    class << self
      # The root boards.yml (+TTG_BOARDS_FILE+, default two folders above the board's).
      attr_writer :settings_file

      # The root boards.yml.
      def settings_file = @settings_file || ENV['TTG_BOARDS_FILE'] || File.expand_path('../../boards.yml', Dir.pwd)
    end

    # The port of the board in +folder+ (root boards.yml), or +nil+.
    def self.port(folder)
      settings = YAML.safe_load_file(settings_file) || {}
      settings.dig(folder, 'port')&.to_i
    rescue StandardError
      nil
    end

    # The links of the machine +qid+: [label, folder, place] each.
    def self.machine_links(qid)
      machine = MACHINES[qid] or return []
      [
        (['its games on Commodex BBS', 'commodex', nil] if machine[:games]),
        ["our #{machine[:name]} titles on WarpEngine BBS", 'warp-engine', "directory:#{machine[:directory]}"]
      ].compact
    end

    # The links of a Commodex game: its machine on Siliconia BBS and the C64 Directory.
    def self.game_links
      [['the Commodore 64 on Siliconia BBS', 'siliconia', "machine:#{C64}"],
       ['our C64 titles on WarpEngine BBS', 'warp-engine', 'directory:c64']]
    end

    # The links of the WarpEngine BBS Directory +id+: its machines on Siliconia BBS.
    def self.directory_links(id)
      MACHINES.filter_map { |qid, m| ["the #{m[:name]} on Siliconia BBS", 'siliconia', "machine:#{qid}"] if m[:directory] == id }
    end

    # The links of +links+ whose board answers (has a port).
    def self.reachable(links) = links.select { |_label, folder, _place| port(folder) }

    # The value of +place+ (a String like <tt>machine:Q99775</tt>) when it is of +kind+, or +nil+.
    def self.place_of(place, kind)
      key, value = place.to_s.split(':', 2)
      key == kind && value && !value.empty? ? value : nil
    end

    # Hands the caller on +session+ to the board in +folder+, at +place+ when given. Returns the
    # board's port once the caller is back, or +nil+ when the board has none. Raises IOError when
    # the caller hangs up meanwhile.
    def self.visit(session, folder, place = nil)
      port = port(folder) or return nil
      gateway = Rubbs::Common::Line::Gateway.new(
        host: HOST, port: port, name: BOARDS.fetch(folder, folder), public_only: false, forward: true, audience: "#{folder}-bbs"
      )
      (place ? gateway.to(place) : gateway).call(session)
      port
    end
  end
end

require_relative 'network/screens'
