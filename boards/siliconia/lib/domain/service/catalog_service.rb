# frozen_string_literal: true

require 'digest'

# The museum's catalog: search by name, maker and CPU, browse by kind, decade, maker and CPU, the
# Legends and the Hungarian machines, a machine's family and its CPU's other machines, the most
# viewed. It reads the machines of the catalog file (a Rubbs::Common::Storage::Snapshot) and
# builds its indexes once per snapshot. #refresh_if_stale replaces the snapshot from Wikidata when
# it is older than +ttl+ seconds (SiliconiaBBS runs it in the background, a failed one again after
# RETRY_AFTER seconds). In every list the machines Wikidata says much of come before the sparse
# ones, each part by name.
class CatalogService
  MIN_QUERY   = 2
  MAX_RESULTS = 300
  # The longest family line shown, each way from a machine.
  MAX_FAMILY  = 25
  TOP_SIZE    = 40

  # Wikidata answered, but with no machines: the old snapshot stays.
  class EmptyCatalog < StandardError; end

  SOURCE  = 'Wikidata, https://www.wikidata.org (CC0 1.0)'
  LICENSE = 'CC0-1.0'
  # Seconds before a failed refresh is tried again.
  RETRY_AFTER = 3600

  Index = Data.define(:machines, :by_id, :names, :others, :kinds, :decades, :makers, :cpus, :weekly)

  # The catalog file kept whole in memory: the newer of +seed+ and +path+, its records the
  # machines, in the order of the lists.
  def self.snapshot(seed:, path:)
    Rubbs::Common::Storage::Snapshot.new(seed: seed, path: path, source: SOURCE, meta: { 'license' => LICENSE }) do |records|
      names = {}
      Array(records['machines']).filter_map { |r| MachineModel.from_record(r, names) }.sort_by { |m| order(m) }.freeze
    end
  end

  def self.order(machine) = [machine.sparse? ? 1 : 0, machine.name.downcase, machine.id[1..].to_i]

  def initialize(snapshot, wikidata:, ttl:, legends: [])
    @snapshot = snapshot
    @wikidata = wikidata
    @ttl      = ttl
    @legends  = legends
    @lock     = Mutex.new
    @index    = nil
  end

  def machines = index.machines

  def count = machines.size

  def updated_at = @snapshot.generated_at

  def find(id) = index.by_id[id]

  # The machines whose name (English or Hungarian) holds +query+: the name itself first, then
  # those ending with it (ZX Spectrum for spectrum), starting with it, holding it; then those whose
  # maker or CPU holds it. :too_short for fewer than MIN_QUERY letters or digits.
  def search(query)
    needle = MachineModel.fold(query)
    return :too_short if needle.size < MIN_QUERY

    names = by_name(needle)
    other = index.others.each_index.select { |i| index.others[i].include?(needle) } - names
    (names + other).first(MAX_RESULTS).map { |i| machines[i] }
  end

  # [kind, number of machines] in the order of MachineModel::KINDS.
  def kinds = MachineModel::KINDS.keys.filter_map { |k| [k, index.kinds[k].size] if index.kinds.key?(k) }

  def of_kind(kind) = index.kinds.fetch(kind, [])

  # [decade, number of machines], oldest first; machines without a year left out.
  def decades = index.decades.map { |decade, list| [decade, list.size] }

  def in_decade(decade) = index.decades.fetch(decade, [])

  # [letter, number of makers]: a to z, and # for the rest.
  def letters
    index.makers.keys.group_by { |name| letter(name) }.map { |l, names| [l, names.size] }.sort_by { |l, _| l == '#' ? '' : l }
  end

  # [maker, number of machines] under +letter+.
  def makers(letter) = index.makers.select { |name, _| letter(name) == letter }.map { |name, list| [name, list.size] }

  def of_maker(name) = index.makers.fetch(name, [])

  # [CPU, number of machines], the most used first.
  def cpus = index.cpus.map { |name, list| [name, list.size] }.sort_by { |name, n| [-n, name.downcase] }

  def of_cpu(name) = index.cpus.fetch(name, [])

  # The other machines with a CPU of +machine+.
  def same_cpu(machine) = machine.cpus.flat_map { |cpu| of_cpu(cpu) }.uniq.reject { |m| m.id == machine.id }

  def legends = @legends.filter_map { |id| find(id) }

  def hungarian = machines.select(&:hungarian?)

  def random = machines.reject(&:sparse?).sample || machines.sample

  # The machine of the week of +at+, the same for everyone all ISO week: one of the machines with
  # an English article, a year and a maker, picked by the week.
  def machine_of_the_week(at = Time.now)
    known = index.weekly
    return nil if known.empty?

    known[Digest::SHA256.hexdigest(week(at)).to_i(16) % known.size]
  end

  # The ISO week of +at+, 2026-W46.
  def week(at = Time.now) = at.strftime('%G-W%V')

  def predecessors(machine) = machine.predecessors.filter_map { |id| find(id) }

  def successors(machine) = machine.successors.filter_map { |id| find(id) }

  # The line of +machine+: its first predecessors back to the oldest, itself, its first
  # successors on to the newest, at most MAX_FAMILY each way.
  def family(machine) = walk(machine, :predecessors).reverse + [machine] + walk(machine, :successors)

  # The page of +machine+ was opened: counted for the most viewed, and the :machine event.
  def viewed(machine)
    ViewModel.count(machine.id)
    Rubbs.achieve(:machine, ref: machine.id.to_s, title: machine.name.to_s)
  rescue StandardError => e
    Rubbs.log('views', "#{machine.id}: #{e.class}: #{e.message}")
  end

  # [machine, views] of the most viewed.
  def most_viewed = ViewModel.top(TOP_SIZE).filter_map { |id, n| (m = find(id)) && [m, n] }

  # Reads the catalog from Wikidata when it is +ttl+ old: :ok, or :fresh. Raises when Wikidata
  # does not answer or has no machines, or the snapshot cannot be written; the old one stays then.
  def refresh_if_stale
    @snapshot.refresh_if_older(@ttl) do
      records = @wikidata.records
      raise EmptyCatalog, 'Wikidata answered no machines' if records.empty?

      { 'machines' => records }
    end
  end

  def letter(name)
    first = MachineModel.fold(name)[0]
    first&.match?(/[a-z]/) ? first : '#'
  end

  private

  # The positions of the machines whose names hold +needle+, the best matches first.
  def by_name(needle)
    names = index.names
    names.each_index.select { |i| names[i].any? { |n| n.include?(needle) } }.sort_by { |i| [rank(names[i], needle), i] }
  end

  def rank(names, needle)
    return 0 if names.include?(needle)
    return 1 if names.any? { |n| n.end_with?(needle) }

    names.any? { |n| n.start_with?(needle) } ? 2 : 3
  end

  def walk(machine, direction)
    seen    = [machine.id]
    line    = []
    current = machine
    while line.size < MAX_FAMILY && (step = send(direction, current).find { |m| !seen.include?(m.id) })
      seen << step.id
      line << step
      current = step
    end
    line
  end

  def index
    machines = @snapshot.value
    @lock.synchronize do
      @index = build(machines) unless @index&.machines.equal?(machines)
      @index
    end
  end

  def build(machines)
    Index.new(
      machines: machines,
      by_id:    machines.to_h { |m| [m.id, m] },
      **searched(machines),
      kinds:    group(machines) { |m| [m.kind] },
      decades:  group(machines) { |m| m.year ? [m.year / 10 * 10] : [] }.sort.to_h,
      makers:   group(machines, &:makers).sort_by { |n, _| MachineModel.fold(n) }.to_h,
      cpus:     group(machines, &:cpus)
    )
  end

  # The folded names, and makers and CPUs, of the machines, for the search; the machines the
  # machine of the week is picked from.
  def searched(machines)
    {
      names:  machines.map { |m| [m.name, m.name_hu].compact.map { |n| MachineModel.fold(n) } },
      others: machines.map { |m| MachineModel.fold((m.makers + m.cpus).join(' ')) },
      weekly: machines.select { |m| m.article && m.year && m.makers.any? }.sort_by(&:id).freeze
    }
  end

  # The machines under each of the keys the block gives for a machine, in the catalog's order.
  def group(machines)
    groups = machines.each_with_object(Hash.new { |h, k| h[k] = [] }) do |machine, all|
      yield(machine).each { |key| all[key] << machine }
    end
    groups.transform_values(&:freeze).to_h
  end
end
