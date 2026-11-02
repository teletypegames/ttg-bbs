# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'securerandom'

# The works on the Wall, one JSON file each in data/works/ (ID.json, the id
# sorting by time). The works read are kept in memory by id; a look at the
# Wall lists the folder only when it changed and reads only the files it
# does not know yet, so a save costs one file, and a work removed by the
# admin script leaves the list at the next look.
class WorkRepository
  ID = /\A\d{8}-\d{6}-[0-9a-f]{4}\z/

  def initialize(dir)
    @dir    = dir
    @lock   = Mutex.new
    @works  = {}
    @broken = Set.new
    @list   = []
    @stamp  = nil
  end

  # Every work, newest first.
  def all = @lock.synchronize { refresh }

  def find(id) = @lock.synchronize { refresh && @works[id] }

  # Saves a new work and returns it, or nil when it could not be written.
  def add(title:, handle:, canvas:, at: Time.now)
    work = WorkModel.new(id: "#{at.strftime('%Y%m%d-%H%M%S')}-#{SecureRandom.hex(2)}", title: title, handle: handle,
                         created_at: at, canvas: canvas)
    @lock.synchronize do
      write(work)
      remember(work)
    end
    work
  rescue SystemCallError => e
    BBS.log('wall', "#{@dir}: #{e.class}: #{e.message}")
    nil
  end

  # Removes the work +id+; true when there was one.
  def remove(id)
    return false unless id.to_s.match?(ID)

    path = path(id)
    @lock.synchronize do
      return false unless File.exist?(path)

      File.delete(path)
      forget(id)
      true
    end
  rescue SystemCallError => e
    BBS.log('wall', "#{path}: #{e.class}: #{e.message}")
    false
  end

  private

  def path(id) = File.join(@dir, "#{id}.json")

  def write(work)
    FileUtils.mkdir_p(@dir)
    tmp = "#{path(work.id)}.#{SecureRandom.hex(4)}.tmp"
    File.write(tmp, JSON.generate(work.to_h))
    File.rename(tmp, path(work.id))
  end

  # The list, brought in line with the folder when the folder changed.
  def refresh
    stamp = folder_stamp
    return @list if stamp == @stamp

    ids = folder_ids
    (@works.keys - ids).each { |id| forget(id) }
    @broken &= ids
    (ids - @works.keys).each { |id| read(id) }
    @stamp = stamp
    sort
  end

  def folder_ids
    Dir.children(@dir).filter_map { |name| name.delete_suffix('.json') if name.end_with?('.json') }
  rescue SystemCallError
    []
  end

  # Reads the work +id+ once; a file that is not a work is skipped, with one
  # warning, while it is there.
  def read(id)
    return if @broken.include?(id)

    work = WorkModel.from_h(JSON.parse(File.read(path(id))))
    work ? @works[id] = work : broken(id, 'not a work')
  rescue SystemCallError, JSON::ParserError => e
    broken(id, "#{e.class}: #{e.message}")
  end

  def broken(id, reason)
    @broken << id
    BBS.log('wall', "#{path(id)}: #{reason}")
  end

  def remember(work)
    @works[work.id] = work
    sort
  end

  def forget(id)
    @works.delete(id)
    sort
  end

  def sort = (@list = @works.values.sort_by(&:id).reverse.freeze)

  def folder_stamp
    stat = File.stat(@dir)
    [stat.mtime.to_f, Dir.children(@dir).size]
  rescue SystemCallError
    nil
  end
end
