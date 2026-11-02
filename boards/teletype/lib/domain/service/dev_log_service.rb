# frozen_string_literal: true

# What the team pushed, tagged and released lately, newest first.
class DevLogService
  def initialize(repo) = @repo = repo

  # The newest +n+ activities; none while Gitea fails.
  def recent(n = 60) = Remote.read('dev log', []) { @repo.activities }.sort_by { |a| -a.created_at.to_i }.first(n)

  def repo_url(activity) = @repo.repo_url(activity.repo)

  def commit_url(activity, sha) = "#{repo_url(activity)}/commit/#{sha}"

  def release_url(activity) = "#{repo_url(activity)}/releases/tag/#{activity.ref}"
end
