# frozen_string_literal: true

# The profiles of registered names; what a caller typed is cleaned of
# control characters before it is kept.
class ProfileService
  MAX_LENGTH = 200

  def initialize(repo) = @repo = repo

  def find(username) = @repo.find(username)

  def update(username, **fields)
    return if username.to_s.strip.empty?

    @repo.upsert(username: username,
                 **fields.transform_values { |v| BBS::Text.line(v)[0, MAX_LENGTH] })
  end
end
