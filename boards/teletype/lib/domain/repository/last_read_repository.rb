# frozen_string_literal: true

require 'csv'
require 'fileutils'

# How far a registered name has read each board: the board's message count
# when the name last opened it. The new-message scan at logon compares it
# with the count now.
class LastReadRepository
  def initialize(path)
    @path  = path
    @mu    = Mutex.new
    @marks = load
  end

  def get(username, board_id)
    @mu.synchronize { @marks.dig(username.downcase, board_id) }
  end

  def set(username, board_id, count)
    @mu.synchronize do
      (@marks[username.downcase] ||= {})[board_id] = count
      write_all
    end
  end

  private

  def load
    return {} unless File.exist?(@path)
    CSV.read(@path).each_with_object({}) do |(name, board, count), marks|
      (marks[name] ||= {})[board] = count.to_i
    end
  rescue StandardError
    {}
  end

  def write_all
    FileUtils.mkdir_p(File.dirname(@path))
    tmp = "#{@path}.tmp"
    CSV.open(tmp, 'w') do |csv|
      @marks.each { |name, boards| boards.each { |board, count| csv << [name, board, count] } }
    end
    File.rename(tmp, @path)
  end
end
