# frozen_string_literal: true

# The profiles of registered names; what a caller typed is cleaned of
# control characters before it is kept.
class ProfileService
  MAX_LENGTH = 200

  # The ProfileModel of +username+, or nil.
  def find(username) = ProfileModel.of(username)

  def update(username, **fields)
    return if username.to_s.strip.empty?

    ProfileModel.upsert(username: username, **fields.transform_values { |v| Rubbs::Common::Text.line(v)[0, MAX_LENGTH] })
  end
end
