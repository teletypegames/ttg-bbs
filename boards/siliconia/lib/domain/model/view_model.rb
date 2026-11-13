# frozen_string_literal: true

require 'time'

# How often the page of a machine was opened, for the most-read shelf.
class ViewModel < Rubbs::Common::Storage::Model
  table :views

  def self.count(machine_id)
    now = Time.now.utc.iso8601
    dataset.insert_conflict(target: :machine_id, update: { count: Sequel[:views][:count] + 1, last_at: now })
      .insert(machine_id: machine_id, count: 1, last_at: now)
  end

  # [machine id, views], the most viewed first.
  def self.top(limit) = reverse(:count).order_append(:machine_id).limit(limit).map { |v| [v.machine_id, v.count] }
end
