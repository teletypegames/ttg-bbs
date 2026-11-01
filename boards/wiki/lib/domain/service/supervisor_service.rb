# frozen_string_literal: true

# The supervisor password that unlocks the private pages for one call. The
# wiki holds the same secret and only serves private page bodies to requests
# carrying it, so the lock holds on the server too.
class SupervisorService
  def initialize(password)
    @password = password.to_s
  end

  def configured? = !@password.empty?

  # :unconfigured when the board has no password, :granted or :wrong.
  def unlock(password)
    return :unconfigured unless configured?

    password == @password ? :granted : :wrong
  end
end
