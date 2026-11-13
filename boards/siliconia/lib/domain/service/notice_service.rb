# frozen_string_literal: true

# The board's rules over its notices.
class NoticeService
  def initialize(notices)
    @notices = notices
  end

  def all = @notices.all

  # The notice of +id+, or :unknown.
  def find(id) = all.find { |n| n.id == id } || :unknown
end
