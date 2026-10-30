# frozen_string_literal: true

# One title of a shelf: a line of its INDEX.TXT,
# file|version|size|crc32|title|author|description.
TitleModel = Data.define(:shelf, :file, :version, :size, :crc32, :title, :author, :description) do
  # The title of +line+ on +shelf+; nil for a comment, a blank or a broken line.
  def self.parse(line, shelf)
    return nil if line.start_with?('#')

    file, version, size, crc32, title, author, description = line.chomp.split('|', members.size - 1)
    return nil if description.nil? || file.empty? || !size.match?(/\A\d+\z/) || !crc32.match?(/\A\h{8}\z/)

    new(shelf: shelf, file: file, version: version, size: size.to_i, crc32: crc32.downcase.to_i(16),
        title: title.empty? ? file : title, author: author, description: description)
  end

  def path = "#{shelf.path}/#{file}"

  # The description; the shelf cuts it short, and then it ends in an ellipsis.
  def about = description.match?(/[.!?)]\z/) ? description : "#{description}…"

  # The name the file gets on a Commodore disk: the file name without .PRG.
  def disk_name = file.sub(/\.prg\z/i, '')

  def key = "#{shelf.id}/#{file}"
end
