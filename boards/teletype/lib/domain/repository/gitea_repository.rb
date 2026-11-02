# frozen_string_literal: true

require 'time'
require_relative 'http_json'
require_relative '../model/activity_model'

# The public activity of every organisation on the Gitea server, read
# anonymously, so private repositories never show up.
class GiteaRepository
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
  TTL = 300

  def initialize
    @cache = HttpJson::Cache.new(ttl: TTL)
  end

  # The activities of every organisation, each feed read in a thread of
  # its own. Raises BBS::HTTP::Error when the server fails.
  def activities = @cache.fetch(:activities) { organisations.map { |org| Thread.new { feed(org) } }.flat_map(&:value) }

  def repo_url(repo) = "#{BASE_URL}/#{repo}"

  private

  def organisations = HttpJson.get("#{API_URL}/orgs", limit: 50).map { |o| o['username'] }

  def feed(org)
    Thread.current.report_on_exception = false
    HttpJson.get("#{API_URL}/orgs/#{org}/activities/feeds", limit: 30).filter_map { |a| model(a) }
  end

  def model(a)
    kind = KINDS[a['op_type']]
    return unless kind && a['repo']

    content = a['content'].to_s
    payload = parse_payload(content)
    ActivityModel.new(kind: kind, user: a.dig('act_user', 'login').to_s, repo: a.dig('repo', 'full_name').to_s,
                      ref: a['ref_name'].to_s.sub(%r{\Arefs/(heads|tags)/}, ''),
                      created_at: Time.parse(a['created'].to_s), commits: commits(payload),
                      title: payload.empty? ? content : '')
  rescue ArgumentError
    nil
  end

  def commits(payload)
    (payload['Commits'] || [payload['HeadCommit']].compact).map { |c| [c['Sha1'].to_s, c['Message'].to_s] }
  end

  # Pushes and tags carry their commits as JSON (cleaned like the feed); a
  # release only its title.
  def parse_payload(content)
    content.start_with?('{') ? HttpJson.clean(JSON.parse(content)) : {}
  rescue JSON::ParserError
    {}
  end
end
