# frozen_string_literal: true

class MessageService
  def initialize(repo) = @repo = repo

  def recent(count = 30) = @repo.last(count)
  def count              = @repo.count

  def post(username, text)
    return :empty if text.strip.empty?
    @repo.append(username, text.strip[0...200])
    :ok
  end
end
