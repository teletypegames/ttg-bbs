# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'securerandom'

# The works on the Wall, one JSON file each in data/works/ (ID.json, the id
# sorting by time). The list is read again only when the folder changed, so
# a work removed by the admin script leaves the list at the next look.
class WorkRepository
  ID = /\A\d{8}-\d{6}-[0-9a-f]{4}\z/

  def initialize(dir)
    @dir   = dir
    @lock  = Mutex.new
    @works = []
    @stamp = nil
  end

  # Every work, newest first.
  def all
    @lock.synchronize do
      stamp = folder_stamp
      if stamp != @stamp
        @works = read_all
        @stamp = stamp
      end
      @works
    end
  end

  def find(id) = all.find { |w| w.id == id }

  # Saves a new work and returns it, or nil when it could not be written.
  def add(title:, handle:, canvas:, at: Time.now)
    work = WorkModel.new(id: "#{at.strftime('%Y%m%d-%H%M%S')}-#{SecureRandom.hex(2)}", title: title, handle: handle,
                         created_at: at, canvas: canvas)
    @lock.synchronize do
      FileUtils.mkdir_p(@dir)
      path = File.join(@dir, "#{work.id}.json")
      File.write("#{path}.tmp", JSON.generate(work.to_h))
      File.rename("#{path}.tmp", path)
      @stamp = nil
    end
    work
  rescue SystemCallError => e
    warn "pixelia-bbs: #{@dir}: #{e.class}: #{e.message}"
    nil
  end

  # Removes the work +id+; true when there was one.
  def remove(id)
    return false unless id.to_s.match?(ID)

    path = File.join(@dir, "#{id}.json")
    @lock.synchronize do
      return false unless File.exist?(path)

      File.delete(path)
      @stamp = nil
      true
    end
  rescue SystemCallError => e
    warn "pixelia-bbs: #{path}: #{e.class}: #{e.message}"
    false
  end

  private

  def folder_stamp
    stat = File.stat(@dir)
    [stat.mtime.to_f, Dir.children(@dir).size]
  rescue SystemCallError
    nil
  end

  def read_all
    Dir.glob(File.join(@dir, '*.json')).filter_map do |path|
      WorkModel.from_h(JSON.parse(File.read(path)))
    rescue SystemCallError, JSON::ParserError => e
      warn "pixelia-bbs: #{path}: #{e.class}: #{e.message}"
      nil
    end.sort_by(&:id).reverse
  end
end
