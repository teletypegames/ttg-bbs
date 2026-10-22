# frozen_string_literal: true

# E-mail on the board: registered names write to each other, and anyone
# with a name leaves feedback for the sysop. The sysops read the "Sysop"
# box besides their own.
class MailService
  SYSOP         = 'Sysop'
  SUBJECT_MAX   = 40
  BODY_MAX      = 2000
  COOLDOWN      = 30

  def initialize(repo, accounts:, sysops:)
    @repo     = repo
    @accounts = accounts
    @sysops   = sysops
    @last     = {}
    @mu       = Mutex.new
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
  def send_letter(from, to, subject, body, registered:, session_id: nil)
    return :anonymous if from.to_s.casecmp?(AccountService::ANONYMOUS)

    target = recipient(to)
    return :unknown if target.nil?
    return :guest unless registered || target == SYSOP

    text = body.to_s.strip
    return :empty if text.empty?
    return :too_fast unless may_send?(session_id)

    title = subject.to_s.gsub(/[[:cntrl:]]/, '').strip
    title = '(no subject)' if title.empty?
    @repo.append(from, target, title[0, SUBJECT_MAX], text[0, BODY_MAX])
    :ok
  end

  private

  def may_send?(session_id)
    return true if session_id.nil?

    now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    @mu.synchronize do
      @last.delete_if { |_, at| now - at > COOLDOWN }
      return false if @last.key?(session_id)

      @last[session_id] = now
      true
    end
  end
end
