# frozen_string_literal: true

require 'time'
require_relative 'badges/service'
require_relative 'badges/screen'

module TTG
  # The badges of the TTG network on rubbs' Rubbs::Common::Badges: the
  # network's own (lib/ttg/badges/network.rb) and each board's, in its
  # <tt>badges.rb</tt> beside its <tt>bbs.rb</tt>. A board loads its own and
  # the network's and sends its events:
  #
  #   Rubbs.board 'HackerCave BBS', HackerCaveBBS do
  #     central TTG::CENTRAL
  #     badges  TTG::Badges.load(__dir__)
  #   end
  #
  # The gate (the Central) loads every board's (#load_all) and counts them
  # (Service). A caller sees theirs in the profile, Badges (Screen).
  module Badges
    # The folder of the boards (every one beside ttg-common).
    BOARDS = File.expand_path('../../..', __dir__)
    # Who had an account before this has the Pioneer badge.
    LAUNCH = Time.utc(2026, 11, 8)
    # What a guest is told the first time they do something a badge counts
    # (Rubbs::Common::Badges.guest_hint): an invitation to make an account.
    GUEST_HINT = 'Callers with an account collect badges on every board of the network, and this would have ' \
                 'counted. Make one in your profile: a name and a password, nothing more.'

    # The boards of the network: the folders beside ttg-common with a
    # <tt>bbs.rb</tt>.
    def self.boards = Dir.glob('*/bbs.rb', base: BOARDS).map { |path| File.dirname(path) }.sort

    # Loads the network's badges and the board of +dir+'s own
    # (<tt>badges.rb</tt>, if it has one). Returns the board's name in the
    # badges, its folder's name.
    def self.load(dir)
      network
      own = File.join(dir, 'badges.rb')
      require own if File.file?(own)
      File.basename(dir)
    end

    # Loads the network's badges and every board's: what the Central counts
    # by. Returns the name of the board of +dir+.
    def self.load_all(dir)
      boards.each { |board| load(File.join(BOARDS, board)) }
      load(dir)
    end

    # Loads the network's own badges once, tells the catalog the boards and
    # the guests' invitation, and puts Badges in the profile.
    def self.network
      require_relative 'badges/network'
      Rubbs::Common::Badges.catalog.boards = -> { boards }
      Rubbs::Common::Badges.guest_hint = GUEST_HINT
      Rubbs::Common::Auth::Profile.extra(:badges, 'Badges', hotkey: 'a', if: SIGNED_IN) { |session| Screen.new(session).run }
    end

    # Whether the caller is signed in on a board tied to the Central.
    SIGNED_IN = ->(session) { !Rubbs.config.central.nil? && session.identity.signed_in? }
  end
end
