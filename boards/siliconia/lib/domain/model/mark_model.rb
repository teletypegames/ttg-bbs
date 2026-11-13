# frozen_string_literal: true

require 'time'

# A machine an account marked: one it had ('owned') or the one it grew up on ('grew_up').
class MarkModel < Rubbs::Common::Storage::Model
  table :marks

  KINDS = %w[owned grew_up].freeze

  def self.of(account_id) = where(account_id: account_id.to_s).reverse(:created_at).all

  def self.marked?(account_id, machine_id, kind) = !mark(account_id, machine_id, kind).empty?

  def self.mark(account_id, machine_id, kind) = where(account_id: account_id.to_s, machine_id: machine_id, kind: kind)

  def self.add(account_id:, handle:, machine_id:, kind:)
    dataset.insert_ignore.insert(
      account_id: account_id.to_s,
      handle:     handle,
      machine_id: machine_id,
      kind:       kind,
      created_at: Time.now.utc.iso8601
    )
  end

  # { kind => number of accounts } of a machine.
  def self.counts(machine_id) = where(machine_id: machine_id).group_and_count(:kind).to_hash(:kind, :count)

  # [machine id, number of accounts] of +kind+, the most marked first.
  def self.top(kind, limit)
    where(kind: kind).group_and_count(:machine_id).reverse(:count).order_append(:machine_id).limit(limit)
      .map { |row| [row[:machine_id], row[:count]] }
  end
end
