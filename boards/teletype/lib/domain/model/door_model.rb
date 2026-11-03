# frozen_string_literal: true

# A door of the board (BBS::Door) with what the board's lists show about
# it: +cols+, the narrowest screen the program draws for, and +tag+, a few
# words for the C64's list. The door's +petscii+ is the same door drawn for
# 40 columns, when the program itself needs more.
class DoorModel < BBS::Door
  attr_reader :cols, :tag

  def initialize(name, program, cols:, tag:, **)
    super(name, program, **)
    @cols = cols
    @tag  = tag
  end

  def title = label.delete('&')
  def c64? = cols <= 40 || !petscii.nil?
end
