# frozen_string_literal: true

module TTG
  # The accounts of the Teletype Games boards (BBS::Auth): they live on TTG
  # Gate BBS, the way in, which hands a signed-in caller on to the board
  # they dial; every other board asks the gate's API on the +interstack+
  # network. Every board shares +RUBBS_AUTH_SECRET+.
  #
  #   BBS.board 'TTG Blog BBS', TTGBlogBBS do
  #     auth TTG::AUTH, login: :menu
  #   end
  module Auth
    # The gate's accounts API, unless +TTG_AUTH_URL+ says otherwise.
    URL = ENV.fetch('TTG_AUTH_URL', 'http://ttg-gate-bbs:8090/auth')
    # The port the gate serves it on.
    PORT = 8090
    # The roles of the network and what each lets an account do.
    ROLES = {
      'member'          => 'every account: post, write mail, keep a profile',
      'sysop'           => 'runs Teletype BBS, gives and takes roles',
      'blogger'         => 'writes and publishes on TTG Blog BBS',
      'wiki-supervisor' => 'the supervisor menu of Wiki BBS'
    }.freeze
    # What a new account gets.
    NEW = %w[member].freeze
  end

  # The accounts of the network for BBS.board's +auth+ on any board but the
  # gate: a BBS::Auth::Remote on TTG::Auth::URL.
  AUTH = BBS::Auth::Remote.new(Auth::URL)
end
