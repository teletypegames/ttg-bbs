# frozen_string_literal: true

module Discovery
  # The Gate's Global Discovery (TTG_DISCOVERY.md §7): search, the Browse tree
  # built from the tag axes with their counts, New this week, Random board,
  # Recently died and the Graveyard. Each list is sorted online first, then
  # by name; on the C64 face (+petscii+) only PETSCII boards are in it.
  class BrowseService
    DAY = 86_400
    # The axes of Browse: the tag prefix (or the fixed tags) of each.
    AXES = {
      terminal: { label: 'Terminal', tags: %w[ansi petscii atascii ascii] },
      software: { label: 'Software', prefix: 'sw:' },
      country:  { label: 'Country',  prefix: 'cc:' },
      network:  { label: 'Network',  prefix: 'net:' }
    }.freeze
    # Recently died: dead for at most this long.
    RECENT_DEAD = 30 * DAY
    NEW_DAYS    = 7
    Facet = Data.define(:tag, :label, :count)

    # [directory] DirectoryRepository  [config] ConfigRepository
    def initialize(directory, config, random: Random.new)
      @directory = directory
      @config    = config
      @random    = random
    end

    # The axes of Browse a face shows: the C64 has no "by Terminal" (it only
    # lists PETSCII boards).
    def axes(petscii: false) = petscii ? AXES.except(:terminal) : AXES

    # The SearchQuery of +text+.
    def query(text) = SearchQuery.parse(text, vocabulary)

    # The boards of +query+ (a SearchQuery or text); +state+ is the F filter.
    def search(query, petscii: false, state: nil)
      query = query(query) unless query.is_a?(SearchQuery)
      sorted(@directory.listings(ListingFilter.search(query, petscii: petscii, state: state)))
    end

    # Every board of the catalog, the dead and every encoding too (no
    # mailers), or with +petscii+ every PETSCII one, with +tags+ the boards
    # of every one of them; +state+ is the F filter.
    def all(petscii: false, state: nil, tags: [])
      sorted(@directory.listings(ListingFilter.new(dead: true, state: state, petscii: petscii, tags: tags)))
    end

    # The boards of one tag (a Facet of Browse).
    def tagged(tag, petscii: false, state: nil)
      sorted(@directory.listings(ListingFilter.new(tags: [tag], petscii: petscii, state: state)))
    end

    # The Facets of +axis+ (a key of AXES) over the boards a list shows by
    # default (not dead, no mailers), the biggest first.
    def facets(axis, petscii: false)
      spec = AXES.fetch(axis)
      counts = Hash.new(0)
      @directory.listings(ListingFilter.new(petscii: petscii)).each do |listing|
        listing.tags.each { |t| counts[t] += 1 if spec[:tags] ? spec[:tags].include?(t) : t.start_with?(spec[:prefix]) }
      end
      counts.map { |tag, n| Facet.new(tag: tag, label: label(tag), count: n) }
            .sort_by { |f| [-f.count, f.label.downcase] }
    end

    # The boards first seen in the last NEW_DAYS days (not those of the first
    # import), the newest first.
    def new_this_week(petscii: false, now: Time.now.to_i)
      after = [now - (NEW_DAYS * DAY), @directory.started_at + DAY].max
      @directory.listings(ListingFilter.new(petscii: petscii)).select { |l| l.first_seen_at > after }
                .sort_by { |l| [-l.first_seen_at, l.title.downcase] }
    end

    # An online board at random, nil when there is none.
    def random(petscii: false)
      @directory.listings(ListingFilter.new(petscii: petscii, state: 'online')).sample(random: @random)
    end

    # The boards that turned dead in the last RECENT_DEAD, the freshest first.
    def recently_died(petscii: false, now: Time.now.to_i)
      graveyard(petscii: petscii).select { |l| l.state_since.to_i >= now - RECENT_DEAD }
                                 .sort_by { |l| [-l.state_since.to_i, l.title.downcase] }
    end

    # Every dead board: they are never deleted, their history stays.
    def graveyard(petscii: false)
      sorted(@directory.listings(ListingFilter.new(petscii: petscii, state: 'dead')))
    end

    def page(id, now: Time.now.to_i) = @directory.page(id, now: now)

    # The ListingModel of board +id+ as it is now, nil when it is not shown.
    def listing(id) = @directory.listing(id)

    def sources = @directory.sources

    # The counts of the catalog (DirectoryRepository#stats).
    def stats = @directory.stats

    # The shown name of a tag: the software's name, the country code in
    # capitals, the network, the encoding in capitals.
    def label(tag)
      prefix, value = tag.include?(':') ? tag.split(':', 2) : [nil, tag]
      case prefix
      when 'sw' then @config.signatures.find { |s| s.id == value }&.name || value
      when 'net' then NETWORKS.fetch(value, value.capitalize)
      else value.upcase
      end
    end

    NETWORKS = { 'fidonet' => 'FidoNet', 'fsxnet' => 'fsxNet', 'dovenet' => 'DOVE-Net', 'micronet' => 'Micronet',
                 'amiganet' => 'AmigaNet', 'agoranet' => 'AgoraNet', 'hobbynet' => 'HobbyNet', 'tqwnet' => 'tqwNet',
                 'retronet' => 'RetroNet' }.freeze

    private

    def vocabulary
      now = Time.now.to_i
      return @vocabulary if @vocabulary && now - @vocabulary_at < 300

      @vocabulary_at = now
      @vocabulary = @directory.vocabulary.to_set
    end

    def sorted(listings) = listings.sort_by(&:sort_key)
  end
end
