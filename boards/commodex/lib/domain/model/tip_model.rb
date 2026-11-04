# frozen_string_literal: true

require 'time'

# A cheat or a tip a caller sent for a game: pending until an admin approves
# it with bin/tips, and only then shown. A seed tip (config/tips.yml)
# carries its seed key, so it goes in once.
class TipModel < BBS::Model
  table :tips

  # The id of the new tip; a seed already in goes in no second time.
  def self.add(game_id:, handle:, text:, status: 'pending', seed: nil)
    dataset.insert_ignore.insert(game_id: game_id, handle: handle, text: text, status: status,
                                 created_at: Time.now.utc.iso8601, seed: seed)
  end

  def self.approved(game_id) = where(game_id: game_id, status: 'approved').order(:id).all

  def self.with_status(status, limit: 100) = where(status: status).reverse(:id).limit(limit).all

  def self.count_approved(game_id) = where(game_id: game_id, status: 'approved').count

  # The number of approved tips of every game that has one.
  def self.approved_counts = where(status: 'approved').group_and_count(:game_id).to_hash(:game_id, :count)

  # The number of tips changed: 0 when there was no such tip.
  def self.change_status(id, status) = where(id: id).update(status: status)

  def author = handle.to_s.empty? ? 'anonymous' : handle

  def date = created_at.to_s[0, 10]

  def approved? = status == 'approved'
end
