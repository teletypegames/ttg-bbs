# frozen_string_literal: true

require 'time'

# A film on an account's list: the watchlist (to see) or the films seen.
class MarkModel < Rubbs::Common::Storage::Model
  table :marks

  KINDS = %w[watchlist seen].freeze

  def self.of(account_id, kind) = where(account_id: account_id.to_s, kind: kind).reverse(:created_at).all

  def self.marked?(account_id, film_id, kind) = !where(account_id: account_id.to_s, film_id: film_id, kind: kind).empty?

  def self.count_of(account_id, kind) = where(account_id: account_id.to_s, kind: kind).count

  def label = [year, title].compact.join(' ')
end
