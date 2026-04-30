# frozen_string_literal: true

require 'csv'
require 'time'
require 'fileutils'
require_relative '../model/message_model'

class MessageBoardRepository
  def initialize(path)
    @path     = path
    @messages = []
    @mu       = Mutex.new
    load_csv
  end

  def append(username, text)
    msg = MessageModel.new(Time.now.strftime('%m-%d %H:%M'), username, text)
    @mu.synchronize do
      @messages << msg
      FileUtils.mkdir_p(File.dirname(@path))
      CSV.open(@path, 'a') { |csv| csv << [msg.timestamp, msg.username, msg.text] }
    end
    msg
  end

  def last(n = 30)
    @mu.synchronize { @messages.last(n) }
  end

  def count
    @mu.synchronize { @messages.size }
  end

  private

  def load_csv
    return unless File.exist?(@path)
    CSV.foreach(@path) { |row| @messages << MessageModel.new(*row) }
  rescue => e
    warn "MessageBoardRepository load error: #{e}"
  end
end
