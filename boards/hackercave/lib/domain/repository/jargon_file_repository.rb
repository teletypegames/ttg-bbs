# frozen_string_literal: true

require 'digest'

# The plain-text Jargon File shipped with the board
# (config/jargon/jarg447.txt): its digest, and its entries and sections
# (JargonParser).
class JargonFileRepository
  def initialize(path)
    @path = path
  end

  # The SHA-256 of the file.
  def digest = Digest::SHA256.file(@path).hexdigest

  # The JargonParser of the file.
  def parse = JargonParser.new(File.binread(@path))
end
