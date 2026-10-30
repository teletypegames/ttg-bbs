# frozen_string_literal: true

require 'bbs'
require_relative 'lib/domain/announcer'
require_relative 'lib/domain/blog'
require_relative 'lib/ui/modern'
require_relative 'lib/ui/petscii'
require_relative 'lib/web/api'

# The Teletype Games blog on a telnet line, two faces on one port: the caller
# picks a terminal (BBS::Terminal guesses it first), and both faces read and
# write line by line, 80 columns of ANSI or 40 of PETSCII. Readers need no
# account; the editors log in from the menu, and bin/user manages them.
# Beside the telnet line, Web::Api serves the posts to teletypegames.org.
blog = Blog.new(path:       ENV.fetch('TTGBLOG_DB', File.join(__dir__, 'data/ttgblog.sqlite3')),
                categories: Blog.load_categories(ENV.fetch('TTGBLOG_CATEGORIES', File.join(__dir__, 'config/categories.yml'))))

webhook = ENV['TTGBLOG_DISCORD_WEBHOOK'].to_s
unless webhook.empty?
  announcer = Announcer.new(webhook: webhook, site: ENV.fetch('TTGBLOG_SITE_URL', 'https://teletypegames.org'))
  blog.on_publish { |post| announcer.call(post) }
end

http_port = ENV.fetch('TTGBLOG_HTTP_PORT', '8080').to_i
Web::Api.new(blog, port: http_port).start if http_port.positive?

BBS.configure do |config|
  config.mouse            = false
  config.mouse_on_connect = false
  config.idle_seconds     = 900

  config.flow = BBS::Terminal.flow(title: 'TTGBLOG', modern: UI::Modern.flow(blog), petscii: UI::Petscii.flow(blog))
end

BBS.start
