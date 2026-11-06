# frozen_string_literal: true

module TTG
  # The accounts of the Teletype Games boards (Rubbs::Common::Auth): they live on TTG
  # Gate BBS, the way in and the network's Central (TTG::Central), which hands
  # a signed-in caller on to the board they dial; every other board asks the
  # Central. Every board shares +RUBBS_AUTH_SECRET+.
  #
  #   Rubbs.board 'TTG Blog BBS', TTGBlogBBS do
  #     central TTG::CENTRAL
  #     auth login: :menu
  #   end
  module Auth
    # The accounts on the Central: TTG::Central::URL and <tt>/auth</tt>.
    URL = "#{Central::URL}/auth".freeze
    # The port the gate serves them on, the Central's.
    PORT = Central::PORT
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

  # The accounts of the network on the Central, a Rubbs::Common::Auth::Remote:
  # for a board that names them in +auth+ (<tt>auth TTG::AUTH</tt>); one
  # with <tt>central TTG::CENTRAL</tt> needs no name.
  AUTH = Rubbs::Common::Auth::Remote.new(client: CENTRAL)
end
