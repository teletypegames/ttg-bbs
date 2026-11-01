# frozen_string_literal: true

# A door of the board. +cols+: the narrowest screen the program draws for;
# +petscii+: the same door drawn for 40 columns, when the program itself
# needs more. +tag+ is a few words for the C64's list, +hint+ the line of
# the modern statusbar, +about+ the Door Lobby's paragraph.
DoorModel = Struct.new(:name, :program, :label, :cols, :petscii, :tag, :hint, :about, keyword_init: true) do
  def title = label.delete('&')
  def c64? = cols <= 40 || !petscii.nil?
end
