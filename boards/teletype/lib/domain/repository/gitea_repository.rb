# frozen_string_literal: true

require 'time'
require_relative 'http_json'
require_relative '../model/activity_model'

# The public activity of every organisation on the Gitea server, read
# anonymously, so private repositories never show up.
class GiteaRepository
  include HttpJson

  BASE_URL = 'https://git.teletypegames.org'
  API_URL  = "#{BASE_URL}/api/v1".freeze
  KINDS    = {
    'commit_repo'     => :push,
    'push_tag'        => :tag,
    'publish_release' => :release,
    'create_repo'     => :repo,
    'transfer_repo'   => :repo,
    'rename_repo'     => :repo
  }.freeze

  def activities
    cached(:activities) do
      organisations.map do |org|
        Thread.new do
          get_json("#{API_URL}/orgs/#{org}/activities/feeds", limit: 30).filter_map { |a| model(a) }
        rescue StandardError => e
          warn "GiteaRepository feed error (#{org}): #{e}"
          []
        end
      end.flat_map(&:value)
    end
  rescue StandardError => e
    warn "GiteaRepository error: #{e}"
    []
  end

  def repo_url(repo) = "#{BASE_URL}/#{repo}"

  private

  def organisations = get_json("#{API_URL}/orgs", limit: 50).map { |o| o['username'] }

  def model(a)
    kind = KINDS[a['op_type']]
    return unless kind && a['repo']

    content = a['content'].to_s
    payload = content.start_with?('{') ? (JSON.parse(content) rescue {}) : {}
    commits = (payload['Commits'] || [payload['HeadCommit']].compact).map { |c| [c['Sha1'].to_s, c['Message'].to_s] }
    ActivityModel.new(kind: kind, user: a.dig('act_user', 'login').to_s, repo: a.dig('repo', 'full_name').to_s,
                      ref: a['ref_name'].to_s.sub(%r{\Arefs/(heads|tags)/}, ''),
                      created_at: Time.parse(a['created'].to_s), commits: commits,
                      title: payload.empty? ? content : '')
  rescue ArgumentError
    nil
  end
end
