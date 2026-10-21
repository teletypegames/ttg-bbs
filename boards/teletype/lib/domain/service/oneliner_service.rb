# frozen_string_literal: true

class OnelinerService
  MAX_LENGTH = 64

  def initialize(repo) = @repo = repo

  def recent(n = 5) = @repo.recent(n)

  def add(username, text)
    return :anonymous if username.to_s.casecmp?(AccountService::ANONYMOUS)

    line = text.to_s.gsub(/[[:cntrl:]]/, '').strip
    return :empty if line.empty?
    return :too_long if line.length > MAX_LENGTH

    @repo.append(username, line)
    :ok
  end
end
