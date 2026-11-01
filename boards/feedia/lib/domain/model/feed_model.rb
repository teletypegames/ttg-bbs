# frozen_string_literal: true

# One feed of the list: its name, its address, and the group, language and
# description shown with it.
FeedModel = Data.define(:name, :url, :group, :lang, :about) do
  # An entry of config/feeds.yml; nil when it has no name or no http(s) url.
  def self.from_entry(entry)
    return nil unless entry.is_a?(Hash) && entry['name'] && entry['url'].to_s.match?(%r{\Ahttps?://}i)

    new(name: entry['name'].to_s, url: entry['url'].to_s, group: entry['group'].to_s, lang: entry['lang'].to_s,
        about: entry['about'].to_s)
  end
end
