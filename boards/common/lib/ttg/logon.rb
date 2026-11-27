# frozen_string_literal: true

module TTG
  # What a caller hears on every TTG board when they sign in
  # (Rubbs::Common::Auth::Logins): the day of the network once a day
  # (TTG::Bulletin), and the letters that came since they were last told
  # (TTG::PrivateMessage.news), in one notice over the first screen. The
  # Central is asked in a thread of its own for at most WAIT seconds; when it
  # is slow or away, there is no notice.
  module Logon
    # Seconds a sign-in waits for the Central.
    WAIT = 2

    class << self
      # A line under the bulletin on this board (the gate points at its Today tab), or +nil+.
      attr_accessor :hint
    end

    # Registers the notice for every sign-in of the process. Returns the block.
    def self.offer = Rubbs::Common::Auth::Logins.on_login { |session| greet(session) }

    # Leaves the caller on +session+ the notice of their sign-in, when there
    # is something to say. Returns the notice's text, or +nil+.
    def self.greet(session)
      return nil if Rubbs.config.central.nil?

      Feedback::Outbox.resume
      lines, letters = ask(session)
      text = words(lines, letters) or return nil
      session.notice(text, title: lines.empty? ? 'Mail' : 'Today on the network')
      text
    end

    # The notice of +lines+ (the bulletin) and +letters+ (a count), or +nil+ when both are empty.
    def self.words(lines, letters)
      parts = lines.dup
      parts << hint if hint && !lines.empty?
      parts << letter_words(letters) if letters.positive?
      parts.empty? ? nil : parts.join("\n")
    end

    # The line of +count+ new letters.
    def self.letter_words(count) = "#{count} unread #{count == 1 ? 'letter' : 'letters'}: M in your profile reads them."

    # [the bulletin's lines, the new letters] from the Central, or nothing when it does not answer in time.
    def self.ask(session)
      worker = Thread.new { [Bulletin.today(session), PrivateMessage.news(session)] }
      worker.report_on_exception = false
      worker.join(WAIT)&.value || [[], 0]
    rescue StandardError => e
      Rubbs.log('logon', e, level: :warn)
      [[], 0]
    end
  end
end
