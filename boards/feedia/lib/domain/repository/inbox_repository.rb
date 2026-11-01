# frozen_string_literal: true

require 'json'

# The admins' inbox: the messages (MessageModel) in the messages table of
# the board's database (BBS::SQLite), the newest KEEP of them; an older one
# goes when a new one comes. The inbox.jsonl of earlier versions is taken
# in once, then renamed inbox.jsonl.imported.
class InboxRepository
  KEEP    = 1000
  COLUMNS = 'kind, at, sender, name, url, text'
  SCHEMA  = <<~SQL
    CREATE TABLE messages (
      id     INTEGER PRIMARY KEY,
      kind   TEXT NOT NULL,
      at     TEXT NOT NULL,
      sender TEXT,
      name   TEXT,
      url    TEXT,
      text   TEXT
    )
  SQL

  # The messages in +db+ (a BBS::SQLite); +legacy+ is the path of an
  # inbox.jsonl to take in when the table is empty.
  def initialize(db, legacy: nil, keep: KEEP)
    @db   = db
    @keep = keep
    @db.migrate(SCHEMA)
    import(legacy) if legacy && File.exist?(legacy)
  end

  # Keeps +message+; true when it is kept, false (and a warning) when it
  # could not be.
  def append(message)
    @db.transaction do
      insert(message)
      prune
    end
    true
  rescue SQLite3::Exception => e
    warn "feedia-bbs: inbox: #{e.class}: #{e.message}"
    false
  end

  # The last +limit+ messages, the newest first.
  def last(limit)
    @db.query("SELECT #{COLUMNS} FROM messages ORDER BY id DESC LIMIT ?", limit).map { |row| message(row) }
  end

  # The number of messages kept.
  def count = @db.get('SELECT COUNT(*) AS n FROM messages')['n']

  private

  def insert(message)
    @db.insert("INSERT INTO messages (#{COLUMNS}) VALUES (?, ?, ?, ?, ?, ?)",
               message.kind, message.at, message.from, message.name, message.url, message.text)
  end

  # Drops all but the newest @keep messages.
  def prune = @db.change('DELETE FROM messages WHERE id <= (SELECT id FROM messages ORDER BY id DESC LIMIT 1 OFFSET ?)', @keep)

  def message(row)
    MessageModel.new(kind: row['kind'], at: row['at'], from: row['sender'], name: row['name'], url: row['url'],
                     text: row['text'])
  end

  # Takes in the JSON lines of +path+ in one transaction, a line that is
  # not a message skipped, then renames the file.
  def import(path)
    return unless count.zero?

    lines    = File.readlines(path, chomp: true).reject { |line| line.strip.empty? }
    messages = lines.filter_map { |line| MessageModel.from_json(line) }
    @db.transaction do
      messages.each { |message| insert(message) }
      prune
    end
    File.rename(path, "#{path}.imported")
    warn "feedia-bbs: imported #{messages.size} messages from #{File.basename(path)} (#{lines.size - messages.size} skipped)"
  end
end
