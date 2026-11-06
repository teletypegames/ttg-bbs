# frozen_string_literal: true

# The board's view of the network's letters (ttg-common TTG::PrivateMessage on the Central): a
# caller's mailbox at a glance. +letters+ gives the service's proxy when asked (the Central is
# tied to the board after the domain starts).
class MailService
  def initialize(letters)
    @letters = letters
  end

  # The MailboxSummaryModel of +actor+ (a Rubbs::Common::Central::Actor): no letters for a guest.
  def summary(actor)
    return MailboxSummaryModel.new(unread: 0, reachable: true) if actor.guest?

    answer = @letters.call.call(:unread, actor)
    return MailboxSummaryModel.away unless answer['result'] == 'ok'

    MailboxSummaryModel.new(unread: answer['count'].to_i, reachable: true)
  end
end
