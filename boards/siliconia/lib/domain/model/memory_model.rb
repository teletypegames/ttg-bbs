# frozen_string_literal: true

require 'time'

# A memory a caller wrote of a machine: pending until an admin approves it with bin/memories, and
# only then shown.
class MemoryModel < Rubbs::Common::Storage::Model
  table :memories

  def self.add(account_id:, handle:, machine_id:, text:)
    dataset.insert(
      account_id: account_id.to_s,
      handle:     handle,
      machine_id: machine_id,
      text:       text,
      status:     'pending',
      created_at: Time.now.utc.iso8601
    )
  end

  def self.approved(machine_id) = where(machine_id: machine_id, status: 'approved').order(:id).all

  def self.count_approved(machine_id) = where(machine_id: machine_id, status: 'approved').count

  # The number of approved memories of every machine that has one.
  def self.approved_counts = where(status: 'approved').group_and_count(:machine_id).to_hash(:machine_id, :count)

  def self.with_status(status, limit: 100) = where(status: status).reverse(:id).limit(limit).all

  # The number of memories changed: 0 when there was no such memory.
  def self.change_status(id, status) = where(id: id).update(status: status)

  def date = created_at.to_s[0, 10]
end
