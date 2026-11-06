# frozen_string_literal: true

module UI
  module Petscii
    # The 40×25 cell grid of the C64 face: rubbs' Canvas in the lower/upper
    # character set (<tt>Canvas.new(charset: :lower)</tt>), so text keeps
    # its case.
    Canvas = Rubbs::Petscii::Canvas

    # The grid and the drawing helpers of the C64 face: rubbs' kit
    # (Rubbs::Petscii::Kit::Layout).
    Layout = Rubbs::Petscii::Kit::Layout
  end
end
