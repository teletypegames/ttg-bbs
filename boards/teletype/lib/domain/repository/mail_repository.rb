# frozen_string_literal: true

require 'csv'
require 'time'
require 'fileutils'
require 'securerandom'

# Private mail between registered names, and the callers' feedback to the
# sysop (addressed to "Sysop"). One CSV, rewritten whole when a letter is
# read or deleted: a board's mailbag stays small.
class MailRepository
  Letter = Struct.new(:id, :timestamp, :from, :to, :subject, :body, :read) do
    def read? = read == '1'
    def time  = Time.parse(timestamp)
  end

  HEADER = Letter.members.map(&:to_s).freeze

  def initialize(path)
    @path    = path
    @mu      = Mutex.new
    @letters = load
  end

  def append(from, to, subject, body)
    letter = Letter.new(SecureRandom.hex(6), Time.now.iso8601, from, to, subject, body, '0')
    @mu.synchronize do
      @letters << letter
      write_all
    end
    letter
  end

  # Letters to any of the names, newest first.
  def to(names)
    keys = names.map(&:downcase)
    @mu.synchronize { @letters.select { |l| keys.include?(l.to.downcase) }.reverse.map(&:dup) }
  end

  def mark_read(id)
    @mu.synchronize do
      letter = @letters.find { |l| l.id == id }
      next unless letter && !letter.read?

      letter.read = '1'
      write_all
    end
  end

  def delete(id)
    @mu.synchronize do
      next unless @letters.reject! { |l| l.id == id }

      write_all
    end
  end

  private

  def load
    return [] unless File.exist?(@path)
    raw = File.binread(@path).force_encoding(Encoding::UTF_8).scrub
    CSV.parse(raw, headers: true).map { |row| Letter.new(*HEADER.map { |h| row[h] }) }
  rescue StandardError => e
    warn "MailRepository load error: #{e}"
    []
  end

  def write_all
    FileUtils.mkdir_p(File.dirname(@path))
    tmp = "#{@path}.tmp"
    CSV.open(tmp, 'w') do |csv|
      csv << HEADER
      @letters.each { |l| csv << l.to_a }
    end
    File.chmod(0o600, tmp)
    File.rename(tmp, @path)
  end
end
