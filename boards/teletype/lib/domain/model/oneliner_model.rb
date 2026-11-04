# frozen_string_literal: true

require 'time'

# A line on the oneliners wall: one short line per caller, newest last.
class OnelinerModel < BBS::Model
  table :oneliners

  def self.append(username, text) = create(timestamp: Time.now.iso8601, username: username, text: text)

  # The newest +n+, newest first.
  def self.recent(n) = reverse(:id).limit(n).all
end
