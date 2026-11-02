# frozen_string_literal: true

require 'time'

# A post of the blog. +body+ is Markdown, nil when a list read the post
# without it; +author+ the editor's name, nil when they were removed; +face+
# the terminal it was written on. +status+ is one of STATUSES: a draft is
# kept while an editor writes, an edit of +original_id+ or, without one, a
# new post; +base_updated_at+ is the original's updated_at when the edit
# began.
PostModel = Data.define(:id, :slug, :title, :summary, :body, :category, :author, :face, :status, :original_id,
                        :base_updated_at, :published_at, :created_at, :updated_at) do
  # The face a post was written on: a modern terminal or a Commodore 64.
  const_set(:FACES, %w[modern petscii].freeze)

  # A draft only its editors see in the composer; an unpublished post the
  # editors see; a published one everybody does.
  const_set(:STATUSES, %w[draft unpublished published].freeze)

  # A row of the posts table joined with its author's name.
  def self.from_row(row, body: true)
    new(id: row['id'], slug: row['slug'], title: row['title'], summary: row['summary'],
        body: body ? row['body'] : nil, category: row['category'], author: row['author'], face: row['face'],
        status: row['status'], original_id: row['original_id'], base_updated_at: row['base_updated_at'],
        published_at: row['published_at'] && Time.iso8601(row['published_at']),
        created_at: Time.iso8601(row['created_at']), updated_at: Time.iso8601(row['updated_at']))
  end

  # The address of a post on the web: its date and its title, in plain
  # lower-case ASCII ("2026-10-28-hello-world").
  def self.slug_base(title, time)
    words = title.to_s.unicode_normalize(:nfkd).gsub(/\p{Mn}/, '').downcase.gsub(/[^a-z0-9]+/, '-').gsub(/\A-|-\z/, '')
    [time.utc.strftime('%Y-%m-%d'), words[0, 60].sub(/-\z/, '')].reject(&:empty?).join('-')
  end

  def published? = status == 'published'

  def draft? = status == 'draft'

  def updated? = updated_at - created_at >= 60
end
