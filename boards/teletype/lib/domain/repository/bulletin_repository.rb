# frozen_string_literal: true

# The bulletins written as Markdown files (lib/content/bulletins).
class BulletinRepository
  def initialize(dir) = @dir = dir

  # The text of bulletin +file+ ("rules.md"), or nil when there is none.
  def read(file)
    path = File.join(@dir, File.basename(file.to_s))
    File.file?(path) ? File.read(path, encoding: 'UTF-8') : nil
  end
end
