# frozen_string_literal: true

require 'bbs'
require_relative 'lib/domain/blog'
require_relative 'lib/ui/faces'

# The Teletype Games blog on a telnet line, two faces on one port: the caller
# picks a terminal (BBS::Terminal guesses it first), and both faces read and
# write line by line, 80 columns of ANSI or 40 of PETSCII. Readers need no
# account; the editors log in from the menu, and bin/user manages them.
blog = Blog.new(path:       ENV.fetch('TTGBLOG_DB', File.join(__dir__, 'data/ttgblog.sqlite3')),
                categories: Blog.load_categories(ENV.fetch('TTGBLOG_CATEGORIES', File.join(__dir__, 'config/categories.yml'))))

BBS.configure do |config|
  config.mouse            = false
  config.mouse_on_connect = false
  config.idle_seconds     = 900

  config.flow = BBS::Terminal.flow(title: 'TTGBLOG', modern: UI::Faces.modern(blog), c64: UI::Faces.c64(blog))
end

BBS.start
