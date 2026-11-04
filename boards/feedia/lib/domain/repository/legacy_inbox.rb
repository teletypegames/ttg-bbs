# frozen_string_literal: true

# The inbox.jsonl of earlier versions (one JSON message a line), taken into
# an empty messages table (MessageModel) once, in one transaction, a line
# that is not a message skipped; then renamed inbox.jsonl.imported.
class LegacyInbox
  def initialize(path)
    @path = path
  end

  # Imports the file when it exists and the inbox is empty. Returns the
  # counts [imported, skipped], or nil when there was nothing to do.
  def import
    return unless File.exist?(@path) && MessageModel.empty?

    lines    = File.readlines(@path, chomp: true).reject { |line| line.strip.empty? }
    messages = lines.filter_map { |line| MessageModel.from_json(line) }
    MessageModel.append(*messages)
    File.rename(@path, "#{@path}.imported")
    BBS.log('inbox', "imported #{messages.size} messages from #{File.basename(@path)} (#{lines.size - messages.size} skipped)")
    [messages.size, lines.size - messages.size]
  end
end
