# frozen_string_literal: true

require 'fileutils'
require 'json'

module Discovery
  # data/discovery-metrics.prom: the numbers of Global Discovery in the
  # Prometheus text format, for node-exporter's textfile collector. Written
  # whole into a temporary file and renamed, so a scrape never reads half.
  # The Gate's dials in progress come from its own small file (+dials_path+,
  # written by DialService), the dials of the last hour from the probes of
  # kind dial.
  class MetricsService
    PREFIX = 'ttg_gate_bbs_discovery'

    # The most countries and software a gauge names; the rest are "other".
    TOP = 15
    ENCODINGS = %w[ansi petscii atascii ascii].freeze
    MAILER = 'ftn-mailer'

    # [dials_path] the Gate's live dials (JSON)   [db_path] the catalog file
    # [geoip_path] the DB-IP lookup file          [optout]  OptoutRepository
    def initialize(path, catalog:, probes:, dials_path: nil, db_path: nil, geoip_path: nil, optout: nil)
      @path       = path
      @catalog    = catalog
      @probes     = probes
      @dials_path = dials_path
      @db_path    = db_path
      @geoip_path = geoip_path
      @optout     = optout
    end

    # Writes the file; +in_flight+ is the prober's calls in progress.
    def write(now: Time.now.to_i, in_flight: 0)
      FileUtils.mkdir_p(File.dirname(@path))
      tmp = "#{@path}.tmp"
      File.write(tmp, text(now, in_flight: in_flight))
      File.rename(tmp, @path)
    rescue SystemCallError => e
      warn "ttg-gate-bbs-discovery: metrics: #{e.message}"
    end

    def text(now, in_flight: 0)
      lines = []
      gauge(lines, 'boards', 'Boards of the catalog by state (aliases and hidden boards apart).',
            (BoardStateModel::STATES + ['archived']).to_h { |s| [{ state: s }, @probes.state_counts.fetch(s, 0)] })
      counts = @probes.result_counts(now - 3600)
      gauge(lines, 'probes_last_hour', 'Probes of the last hour by result.',
            ProbeResultModel::RESULTS.to_h { |r| [{ result: r }, counts.fetch(r, 0)] })
      dials = @probes.result_counts(now - 3600, kind: 'dial')
      gauge(lines, 'dials_last_hour', "The Gate's dials of the last hour by result.",
            ProbeResultModel::RESULTS.to_h { |r| [{ result: r }, dials.fetch(r, 0)] })
      gauge(lines, 'dials_live', "The Gate's dials in progress.", { {} => live_dials })
      gauge(lines, 'last_probe_timestamp_seconds', 'When the last probe was made.', { {} => @probes.last_probe_at.to_i })
      sources = @catalog.sources
      gauge(lines, 'source_records', 'Records of the last applied import a source.',
            sources.to_h { |s| [{ source: s['id'] }, s['record_count'].to_i] })
      gauge(lines, 'source_last_import_timestamp_seconds', 'When a source was last applied.',
            sources.to_h { |s| [{ source: s['id'] }, s['last_parse_at'].to_i] })
      gauge(lines, 'source_failing', '1 when the last import of a source failed or was refused.',
            sources.to_h { |s| [{ source: s['id'] }, s['last_error'] ? 1 : 0] })
      prober(lines, now, in_flight)
      boards_by(lines)
      files(lines, now)
      gauge(lines, 'metrics_timestamp_seconds', 'When this file was written.', { {} => now })
      lines.join("\n") << "\n"
    end

    private

    def prober(lines, now, in_flight)
      gauge(lines, 'probes_in_flight', 'Probes running right now.', { {} => in_flight })
      schedule = @probes.schedule(now)
      gauge(lines, 'probes_due', 'Boards whose next probe time has passed (the backlog).', { {} => schedule['due'].to_i })
      next_at = schedule['next_at']
      gauge(lines, 'next_probe_due_seconds', 'Seconds until the earliest next probe, 0 when one is overdue.',
            { {} => next_at ? [next_at - now, 0].max : 0 })
      totals = @probes.totals
      gauge(lines, 'probes_total', 'Every stored probe by result and kind (scheduled, c64, dial; counted in the catalog).',
            ProbeResultModel::RESULTS.product(%w[scheduled c64 dial]).to_h do |r, k|
              [{ result: r, kind: k }, totals.fetch([r, k], 0)]
            end)
      avg, max = @probes.durations(now - 3600)
      gauge(lines, 'probe_duration_seconds_avg_last_hour', 'The average whole call (DNS to hang-up) of the last hour.',
            ProbeResultModel::RESULTS.to_h { |r| [{ result: r }, seconds(avg[r])] })
      gauge(lines, 'probe_duration_seconds_max_last_hour', 'The longest call of the last hour.', { {} => seconds(max) })
      gauge(lines, 'banner_bytes_avg_last_hour', 'The average banner read in the last hour.',
            { {} => @probes.banner_bytes(now - 3600).to_f.round(1) })
    end

    def boards_by(lines)
      tags, boards = @probes.answering_tags
      encodings = ENCODINGS.to_h { |e| [e, tags.fetch(e, 0)] }
      encodings['unknown'] = [boards - encodings.values.sum, 0].max
      gauge(lines, 'boards_by_encoding', 'Answering boards (online, flaky) by the encoding of their banner.',
            encodings.transform_keys { |e| { encoding: e } })
      gauge(lines, 'boards_by_network', 'Answering boards by network (a board can be in several).',
            prefixed(tags, 'net:').transform_keys { |n| { network: n } })
      gauge(lines, 'boards_by_country', "Answering boards by country, the top #{TOP} and other.",
            top(prefixed(tags, 'cc:'), boards).transform_keys { |c| { country: c } })
      software = prefixed(tags, 'sw:')
      mailers = software.delete(MAILER).to_i
      by_software = top(software, boards - mailers)
      by_software[MAILER] = mailers
      gauge(lines, 'boards_by_software', "Answering boards by software, the top #{TOP}, other, and FTN mailers.",
            by_software.transform_keys { |s| { software: s } })
    end

    def files(lines, now)
      geoip = @geoip_path && File.exist?(@geoip_path) ? now - File.mtime(@geoip_path).to_i : 0
      gauge(lines, 'geoip_age_seconds', 'The age of the DB-IP lookup file.', { {} => geoip })
      size = @db_path && File.exist?(@db_path) ? File.size(@db_path) : 0
      gauge(lines, 'db_bytes', 'The size of discovery.sqlite3 (its WAL apart).', { {} => size })
      counts = @optout ? @optout.counts : OptoutRepository::LEVELS.to_h { |l| [l, 0] }
      gauge(lines, 'optout_hosts', 'The entries of the opt-out list a level.', counts.transform_keys { |l| { level: l } })
    end

    def prefixed(tags, prefix)
      tags.filter_map { |t, n| [t.delete_prefix(prefix), n] if t.start_with?(prefix) }.to_h
    end

    # The +TOP+ biggest of +counts+, the rest of +total+ as other (boards
    # without the tag included).
    def top(counts, total)
      shown = counts.sort_by { |k, n| [-n, k] }.first(TOP).to_h
      shown.merge('other' => [total - shown.values.sum, 0].max)
    end

    def seconds(ms) = ms ? (ms / 1000.0).round(3) : 0

    def live_dials
      return 0 unless @dials_path && File.exist?(@dials_path)

      JSON.parse(File.read(@dials_path)).fetch('live', 0).to_i
    rescue SystemCallError, JSON::ParserError
      0
    end

    def gauge(lines, name, help, values)
      lines << "# HELP #{PREFIX}_#{name} #{help}" << "# TYPE #{PREFIX}_#{name} gauge"
      values.each do |labels, value|
        label = labels.empty? ? '' : "{#{labels.map { |k, v| "#{k}=\"#{v}\"" }.join(',')}}"
        lines << "#{PREFIX}_#{name}#{label} #{value}"
      end
    end
  end
end
