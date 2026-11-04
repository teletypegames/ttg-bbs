# frozen_string_literal: true

# What the board adds to the impostor gem's debrief terminal: the goodbye
# under the debrief's last words, on a C64 a green bar and IMPOSTOR in
# reversed blocks.
module UI
  include BBS::Petscii::Colors

  LOGO = BBS::BlockFont.petscii('IMPOSTOR', colors: [GN, GN, GN, YE, YE], indent: 2).freeze

  GOODBYE = { clear: false, color: GN, bar: 'Thanks for calling Impostor BBS', art: [*LOGO, ''] }.freeze
end
