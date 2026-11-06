# frozen_string_literal: true

module UI
  # What both faces say to a caller about the domain's answers.
  module Wording
    # Why a name could not be registered (MemberService#register).
    REGISTER = {
      anonymous:   'Log in with a name first, not as Anonymous.',
      invalid:     'This is not a name an account may have.',
      reserved:    'This name is reserved for the sysop.',
      taken:       'This name is already registered.',
      look_alike:  'This name looks too much like a registered one.',
      too_short:   "At least #{Rubbs::Common::Auth::Directory::MIN_PASSWORD} characters.",
      mismatch:    'The two passwords differ.',
      busy:        'The board is busy. Try again in a moment.',
      unavailable: 'Registering is not possible right now. Try again later.'
    }.freeze
  end
end
