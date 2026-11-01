# frozen_string_literal: true

# E-mail on the board: registered names write to each other, and anyone
# with a name leaves feedback for the sysop. The sysops read the "Sysop"
# box besides their own. One letter in COOLDOWN seconds a name and a line;
# a guest's feedback GUEST_DAILY a day a name and a line, and all guests'
# together GUESTS_DAILY, so a crowd cannot fill the sysop's box.
class MailService
  SYSOP        = 'Sysop'
  SUBJECT_MAX  = 40
  BODY_MAX     = 2000
  COOLDOWN     = 30
  GUEST_DAILY  = 3
  GUESTS_DAILY = 30
  DAY          = 86_400

  def initialize(repo, accounts:, sysops:)
    @repo     = repo
    @accounts = accounts
    @sysops   = sysops
    @throttle = Throttle.new(limit: 1, per: COOLDOWN)
    @guest    = Throttle.new(limit: GUEST_DAILY, per: DAY)
    @guests   = BBS::RateLimit.new(limit: GUESTS_DAILY, per: DAY)
  end

  def boxes(username, sysop: false) = sysop ? [username, SYSOP] : [username]

  def inbox(username, sysop: false) = @repo.to(boxes(username, sysop: sysop))

  def unread_count(username, sysop: false) = inbox(username, sysop: sysop).count { |l| !l.read? }

  def mark_read(letter) = @repo.mark_read(letter.id)
  def delete(letter)    = @repo.delete(letter.id)

  # The registered spelling of a recipient, SYSOP for the sysop, nil when
  # nobody by that name can receive mail.
  def recipient(name)
    return SYSOP if name.to_s.strip.casecmp?(SYSOP) || @sysops.include?(name.to_s.strip.downcase)

    @accounts.canonical(name)
  end

  # Guests may only write to the sysop; registered names to anyone.
  # :ok, :anonymous, :unknown, :guest, :empty, :too_fast or :daily_limit.
  def send_letter(from, to, subject, body, registered:, caller_key:)
    target = recipient(to)
    text   = BBS::Text.clean(body).strip
    problem = problem(from, target, text, registered)
    return problem if problem
    return :too_fast unless @throttle.allow?(from, caller_key)
    return :daily_limit unless registered || guest_may_write?(from, caller_key)

    @repo.append(from, target, title(subject), text[0, BODY_MAX])
    :ok
  end

  private

  def problem(from, target, text, registered)
    return :anonymous if from.to_s.casecmp?(AccountService::ANONYMOUS)
    return :unknown if target.nil?
    return :guest unless registered || target == SYSOP

    :empty if text.empty?
  end

  def guest_may_write?(from, caller_key)
    return false unless @guests.wait(:guests).zero?

    @guest.allow?(from, caller_key) && @guests.allow?(:guests)
  end

  def title(subject)
    text = BBS::Text.clean(subject, keep_newlines: false).strip
    text.empty? ? '(no subject)' : text[0, SUBJECT_MAX]
  end
end
