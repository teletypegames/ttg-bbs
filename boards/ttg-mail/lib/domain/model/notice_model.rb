# frozen_string_literal: true

# One notice of config/notices.yml.
NoticeModel = Data.define(:id, :title, :body) do
  def self.from_entry(entry)
    new(id: entry.fetch('id').to_s, title: entry.fetch('title').to_s, body: entry['body'].to_s)
  end
end
