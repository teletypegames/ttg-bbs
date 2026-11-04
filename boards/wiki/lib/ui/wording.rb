# frozen_string_literal: true

module UI
  # What both faces tell the caller about the index and the private pages,
  # and who may read those: an account of the network with the
  # wiki-supervisor role (BBS::Auth, kept on TTG Gate BBS).
  module Wording
    SUPERVISOR  = 'wiki-supervisor'
    PUBLIC_HOST = 'wiki.teletypegames.org'
    EMPTY_INDEX = 'The wiki index is empty. Try Wiki > Refresh index.'

    REFRESH = { limited: 'The index was just refreshed. Try again in a minute.', failed: 'Could not reach the wiki.' }.freeze

    # The board's line on the goodbye screen: the wiki's address, after the
    # time on line on a C64.
    def self.goodbye(context, session)
      web = "The wiki on the web: #{PUBLIC_HOST}."
      return web unless session.respond_to?(:petscii?) && session.petscii? && context[:started_at]

      "On line #{BBS.duration(context[:started_at])}. #{web}"
    end

    # Whether the caller may read the private pages: signed in with the
    # wiki-supervisor role, here or on TTG Gate BBS before it dialled.
    def supervisor? = role?(SUPERVISOR)

    def locked?(page) = page.private? && !supervisor?

    # Why a signed-in caller without the role cannot read a private page.
    def not_supervisor(name) = "#{name} is not a supervisor: the private pages are for the #{SUPERVISOR} role."

    # What a private page says to anyone but a supervisor.
    def locked_text(how)
      return "This page is private. #{not_supervisor(identity.name)}" if signed_in?

      "This page is private, for the supervisors of the wiki. #{how}"
    end
  end
end
