# frozen_string_literal: true

# A cheat or a tip a caller sent for a game: pending until an admin approves
# it with bin/tips, and only then shown.
TipModel = Data.define(:id, :game_id, :handle, :text, :status, :created_at) do
  def self.from_row(row)
    new(id: row['id'], game_id: row['game_id'], handle: row['handle'].to_s, text: row['text'].to_s,
        status: row['status'], created_at: row['created_at'])
  end

  def author = handle.empty? ? 'anonymous' : handle

  def date = created_at.to_s[0, 10]

  def approved? = status == 'approved'
end
