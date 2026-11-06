# frozen_string_literal: true

# A caller's mailbox at a glance: how many letters are new, and whether the Central answered.
MailboxSummaryModel = Data.define(:unread, :reachable) do
  # The summary when the Central does not answer.
  def self.away = new(unread: 0, reachable: false)
end
