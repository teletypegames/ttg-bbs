# frozen_string_literal: true

# The memories callers write of the machines. A memory waits as pending until an admin approves
# it (bin/memories); only approved ones are shown. A caller (by address:
# Rubbs::Common::Line::RateLimit.caller_key, so calling again does not help) may send PER_CALLER
# an hour, one every GAP seconds, and the whole board at most BOARD_MAX an hour.
class MemoryService
  MAX_TEXT   = 600
  PER_CALLER = 3
  GAP        = 30
  BOARD_MAX  = 30
  WINDOW     = 3600

  def initialize(catalog:)
    @catalog    = catalog
    @gap        = Rubbs::Common::Line::RateLimit.new(limit: 1, per: GAP)
    @per_caller = Rubbs::Common::Line::RateLimit.new(limit: PER_CALLER, per: WINDOW)
    @board      = Rubbs::Common::Line::RateLimit.new(limit: BOARD_MAX, per: WINDOW)
  end

  def memories(machine) = MemoryModel.approved(machine.id)

  def count(machine) = MemoryModel.count_approved(machine.id)

  # The machines that have an approved memory, by name.
  def machines_with_memories
    MemoryModel.approved_counts.keys.filter_map { |id| @catalog.find(id) }.sort_by { |m| m.name.downcase }
  end

  # Sends a memory of +machine+ from +caller+ under the account +identity+: :ok, or why not:
  # :account, :empty, :too_long, :rate_limited, :failed.
  def submit(machine, identity:, text:, caller:)
    return :account unless identity.signed_in?

    text = Rubbs::Common::Text.clean(text.to_s).gsub(/[[:space:]]+/, ' ').strip
    return :empty if text.empty?
    return :too_long if text.size > MAX_TEXT
    return :rate_limited unless allowed?(caller)

    save(machine, identity, text)
  end

  def pending(limit = 100) = MemoryModel.with_status('pending', limit: limit)

  def approved_list(limit = 100) = MemoryModel.with_status('approved', limit: limit)

  def machine_of(memory) = @catalog.find(memory.machine_id)

  # :ok or :no_memory.
  def approve(id) = status(id, 'approved')

  def reject(id) = status(id, 'rejected')

  private

  def status(id, value) = MemoryModel.change_status(id.to_i, value).positive? ? :ok : :no_memory

  def allowed?(caller) = Rubbs::Common::Line::RateLimit.allow_all?([[@gap, caller], [@per_caller, caller], [@board, :board]])

  def save(machine, identity, text)
    MemoryModel.add(account_id: identity.id, handle: identity.name.to_s, machine_id: machine.id, text: text)
    Rubbs.achieve(:memory, ref: machine.id.to_s)
    :ok
  rescue StandardError => e
    Rubbs.log('memories', "saving a memory: #{e.class}: #{e.message}")
    :failed
  end
end
