# frozen_string_literal: true

module UI
  module Petscii
    # The 40×25 cell grid of the C64 face: rubbs' Canvas in the lower/upper
    # character set (<tt>Canvas.new(charset: :lower)</tt>), so text keeps
    # its case.
    Canvas = BBS::Petscii::Canvas

    # The grid and the drawing helpers of the C64 face: rubbs' kit
    # (BBS::Kit::Petscii::Layout).
    Layout = BBS::Kit::Petscii::Layout
  end
end
