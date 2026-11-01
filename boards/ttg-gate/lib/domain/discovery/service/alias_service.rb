# frozen_string_literal: true

module Discovery
  # Dedup rule 2 of TTG_DISCOVERY.md §3: two hosts that resolve to the same IP
  # address on the same port are one board. The canonical one is the host
  # more sources list; on a tie the first in alphabetical order. The others
  # get alias_of; a board whose IP moved away loses it. The IPs are those of
  # the last probes (the importer resolves nothing).
  class AliasService
    def initialize(catalog)
      @catalog = catalog
    end

    # Returns the number of aliases.
    def rebuild
      rows = @catalog.addresses
      wanted = {}
      rows.select { |r| r['ip'] }.group_by { |r| [r['ip'], r['port']] }.each_value do |group|
        next if group.size < 2

        canonical = group.min_by { |r| [-r['sources'], r['host']] }
        (group - [canonical]).each { |r| wanted[r['id']] = canonical['id'] }
      end
      @catalog.transaction do
        rows.each { |r| @catalog.set_alias(r['id'], wanted[r['id']]) if r['alias_of'] != wanted[r['id']] }
      end
      wanted.size
    end
  end
end
