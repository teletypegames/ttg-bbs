# frozen_string_literal: true

module TTG
  # What every Teletype Games board says the same way, for BBS.board:
  # the logo before the first screen, teletypegames.org and its QR code on
  # the goodbye screen, the address in the User-Agent of the board's HTTP
  # requests, and the small mark over the caller's profile.
  #
  #   BBS.board 'Feedia BBS', FeediaBBS do
  #     preset TTG::PRESET
  #     …
  #   end
  PRESET = BBS::Preset.new(
    splash:     Logo.splash,
    url:        'teletypegames.org',
    qr:         'HTTPS://TELETYPEGAMES.ORG',
    user_agent: '(+https://teletypegames.org)',
    profile:    Logo.profile
  )
end
