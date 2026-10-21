# frozen_string_literal: true

require 'csv'
require 'time'
require 'fileutils'
require_relative '../model/message_model'

# Multi-board store. Each board ("general", "tech", "offtopic"…) maps to one
# CSV file inside +base_dir+. Lazy-loaded the first time a board is touched.
class BoardRepository
  BoardMeta = Struct.new(:id, :title, :description)

  DEFAULT_BOARDS = [
    BoardMeta.new('general',  'General',  'Open chat, anything goes'),
    BoardMeta.new('tech',     'Tech',     'Hardware, software, code'),
    BoardMeta.new('offtopic', 'Off-Topic', 'Random topics, jokes'),
    BoardMeta.new('sysop',    'Sysop',     'Notes from the operator')
  ].freeze

  attr_reader :boards

  def initialize(base_dir, boards: DEFAULT_BOARDS, legacy_path: nil)
    @base_dir = base_dir
    @boards   = boards
    @cache    = {}
    @mu       = Mutex.new
    FileUtils.mkdir_p(@base_dir)
    migrate_legacy!(legacy_path) if legacy_path
  end

  def append(board_id, username, text)
    msg = MessageModel.new(Time.now.strftime('%m-%d %H:%M'), username, text)
    @mu.synchronize do
      load_board(board_id) << msg
      CSV.open(path_for(board_id), 'a') { |csv| csv << [msg.timestamp, msg.username, msg.text] }
    end
    msg
  end

  def last(board_id, n = 30)
    @mu.synchronize { load_board(board_id).last(n) }
  end

  def count(board_id)
    @mu.synchronize { load_board(board_id).size }
  end

  def total_count
    @mu.synchronize { @boards.sum { |b| load_board(b.id).size } }
  end

  private

  def migrate_legacy!(legacy_path)
    return unless File.exist?(legacy_path)
    target = path_for('general')
    return if File.exist?(target) # already migrated or general has its own data
    rows = []
    CSV.foreach(legacy_path) { |row| rows << row }
    return if rows.empty?
    CSV.open(target, 'w') { |csv| rows.each { |r| csv << r } }
    warn "BoardRepository: migrated #{rows.size} legacy messages " \
         "from #{legacy_path} to #{target}"
  rescue StandardError => e
    warn "BoardRepository: legacy migration failed: #{e}"
  end

  def path_for(id)
    File.join(@base_dir, "#{id}.csv")
  end

  def load_board(id)
    return @cache[id] if @cache.key?(id)
    list = []
    CSV.foreach(path_for(id)) { |row| list << MessageModel.new(*row) } if File.exist?(path_for(id))
    @cache[id] = list
  rescue StandardError => e
    warn "BoardRepository load error (#{id}): #{e}"
    @cache[id] = []
  end
end
