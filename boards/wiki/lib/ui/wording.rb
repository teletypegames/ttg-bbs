# frozen_string_literal: true

module UI
  # What both faces tell the caller about the index and the supervisor lock.
  module Wording
    PUBLIC_HOST = 'wiki.teletypegames.org'
    EMPTY_INDEX = 'The wiki index is empty. Try Wiki > Refresh index.'
    LOCKED      = "# Supervisor only\n\nThis page is private. Unlock it via **Wiki > Supervisor login**."
    GRANTED     = 'Supervisor access granted.'

    REFRESH = { limited: 'The index was just refreshed. Try again in a minute.',
                failed:  'Could not reach the wiki.' }.freeze

    UNLOCK = { unconfigured: 'No supervisor password configured.',
               locked:       'Too many wrong passwords. Try again later.',
               wrong:        'Wrong password.' }.freeze
  end
end
