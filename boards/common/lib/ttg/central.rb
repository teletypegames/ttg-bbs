# frozen_string_literal: true

module TTG
  # The Central of the Teletype Games boards (Rubbs::Common::Central): TTG
  # Gate BBS keeps what the network shares — the accounts and the services
  # of the network — and the other boards ask it on the +interstack+
  # network. Every board shares +RUBBS_AUTH_SECRET+.
  #
  #   Rubbs.board 'TTG Blog BBS', TTGBlogBBS do
  #     central TTG::CENTRAL
  #     auth login: :menu
  #   end
  module Central
    # The gate's address, unless +TTG_CENTRAL_URL+ says otherwise (or the
    # older +TTG_AUTH_URL+, without its <tt>/auth</tt>).
    URL = ENV.fetch('TTG_CENTRAL_URL') { ENV['TTG_AUTH_URL']&.delete_suffix('/auth') || 'http://ttg-gate-bbs:8090' }
    # The port the gate serves it on.
    PORT = 8090
  end

  # The Central of the network for Rubbs.board's +central+ on any board but
  # the gate: a Rubbs::Common::Central::Client on TTG::Central::URL.
  CENTRAL = Rubbs::Common::Central::Client.new(Central::URL)
end
