# frozen_string_literal: true

# The machines the callers had: an account marks a machine as one it had ('owned') or as the one
# it grew up on ('grew_up'). The network's machines are those most callers grew up on.
class CollectionService
  TOP_SIZE = 40

  def initialize(catalog:)
    @catalog = catalog
  end

  # Whether +identity+ marked +machine+ as +kind+.
  def marked?(identity, machine, kind) = identity.signed_in? && MarkModel.marked?(identity.id, machine.id, kind)

  # Marks +machine+ as +kind+ for +identity+ or takes the mark back: :added, :removed, or :account.
  def toggle(identity, machine, kind)
    return :account unless identity.signed_in?
    return :removed if MarkModel.mark(identity.id, machine.id, kind).delete.positive?

    MarkModel.add(account_id: identity.id, handle: identity.name.to_s, machine_id: machine.id, kind: kind)
    Rubbs.achieve(:mark, ref: machine.id.to_s)
    :added
  end

  # { 'owned' => n, 'grew_up' => n } of +machine+.
  def counts(machine) = MarkModel::KINDS.to_h { |k| [k, 0] }.merge(MarkModel.counts(machine.id))

  # [machine, kinds] of the machines +identity+ marked, the newest first.
  def of(identity)
    return [] unless identity.signed_in?

    MarkModel.of(identity.id).group_by(&:machine_id).filter_map do |id, marks|
      (machine = @catalog.find(id)) && [machine, marks.map(&:kind)]
    end
  end

  # [machine, accounts] of the machines most callers grew up on.
  def grew_up_on = MarkModel.top('grew_up', TOP_SIZE).filter_map { |id, n| (m = @catalog.find(id)) && [m, n] }
end
