# frozen_string_literal: true

class OnlineService
  def initialize(repo) = @repo = repo

  def add(session_id, username, sysop: false) = @repo.add(session_id, username, sysop: sysop)
  def remove(session_id)             = @repo.remove(session_id)
  def activity(session_id, text)     = @repo.activity(session_id, text)
  def node(session_id)               = @repo.find(session_id)
  def nodes                          = @repo.snapshot
  def count                          = @repo.count
  def user_list                      = nodes.map(&:name)
  def online?(username)              = nodes.any? { |n| n.name.casecmp?(username.to_s) }
end
