# frozen_string_literal: true

require 'minitest/autorun'
require 'bbs'
require 'tmpdir'
require 'domain'

# A temporary data folder for each test, removed after it.
module TmpDir
  def setup
    super
    @dir = Dir.mktmpdir('pixelia-test')
  end

  def teardown
    FileUtils.rm_rf(@dir)
    super
  end
end

# A canvas with one red A in the top-left corner.
def painted_canvas
  blank = CanvasModel.blank
  chars = blank.chars.dup
  fg = blank.fg.dup
  chars[0] = 'A'
  fg[0] = 2
  CanvasModel.new(chars, fg, blank.bg)
end
