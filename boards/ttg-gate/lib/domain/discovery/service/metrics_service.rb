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
    # The Gate's dial limits, as the live file names them.
    LIMITS = %w[window_seconds per_caller per_host idle_seconds].freeze

    # [dials_path] the Gate's live dials (JSON)   [db_path] the catalog file
    # [geoip_path] the DB-IP lookup file          [optout]  OptoutRepository
    # [history]    DialRepository: the refused dials, the dials' time and bytes
    def initialize(path, catalog:, probes:, dials_path: nil, db_path: nil, geoip_path: nil, optout: nil, history: nil)
      @path       = path
      @catalog    = catalog
      @probes     = probes
      @dials_path = dials_path
      @db_path    = db_path
      @geoip_path = geoip_path
      @optout     = optout
      @history    = history
    end

    # Writes the file; +in_flight+ is the prober's calls in progress.
    def write(now: Time.now.to_i, in_flight: 0)
      FileUtils.mkdir_p(File.dirname(@path))
      tmp = "#{@path}.tmp"
      File.write(tmp, text(now, in_flight: in_flight))
      File.rename(tmp, @path)
    rescue SystemCallError => e
      BBS.log('metrics', e.message)
    end

    def text(now, in_flight: 0)
      lines = []
      catalog(lines, now)
      dial_limits(lines, now)
      gauge(lines, 'last_probe_timestamp_seconds', 'When the last probe was made.', { {} => @probes.last_probe_at.to_i })
      sources(lines)
      prober(lines, now, in_flight)
      boards_by(lines)
      files(lines, now)
      gauge(lines, 'metrics_timestamp_seconds', 'When this file was written.', { {} => now })
      lines.join("\n") << "\n"
    end

    private

    # The boards by state, the probes and dials of the last hour, the dials
    # in progress.
    def catalog(lines, now)
      gauge(lines, 'boards', 'Boards of the catalog by state (aliases and hidden boards apart).',
            (BoardStateModel::STATES + ['archived']).to_h { |s| [{ state: s }, @probes.state_counts.fetch(s, 0)] })
      gauge(lines, 'probes_last_hour', 'Probes of the last hour by result.', by_result(@probes.result_counts(now - 3600)))
      gauge(lines, 'dials_last_hour', "The Gate's dials of the last hour by result.",
            by_result(@probes.result_counts(now - 3600, kind: 'dial')))
      gauge(lines, 'dials_live', "The Gate's dials in progress.", { {} => live_dials })
    end

    # +counts+ by result as gauge values, every result named.
    def by_result(counts) = ProbeResultModel::RESULTS.to_h { |r| [{ result: r }, counts.fetch(r, 0)] }

    def sources(lines)
      sources = @catalog.sources
      gauge(lines, 'source_records', 'Records of the last applied import a source.',
            sources.to_h { |s| [{ source: s['id'] }, s['record_count'].to_i] })
      gauge(lines, 'source_last_import_timestamp_seconds', 'When a source was last applied.',
            sources.to_h { |s| [{ source: s['id'] }, s['last_parse_at'].to_i] })
      gauge(lines, 'source_failing', '1 when the last import of a source failed or was refused.',
            sources.to_h { |s| [{ source: s['id'] }, s['last_error'] ? 1 : 0] })
    end

    def prober(lines, now, in_flight)
      gauge(lines, 'probes_in_flight', 'Probes running right now.', { {} => in_flight })
      schedule(lines, now)
      totals = @probes.totals
      gauge(lines, 'probes_total', 'Every stored probe by result and kind (scheduled, c64, dial; counted in the catalog).',
            ProbeResultModel::RESULTS.product(%w[scheduled c64 dial]).to_h do |r, k|
              [{ result: r, kind: k }, totals.fetch([r, k], 0)]
            end)
      durations(lines, now)
    end

    def schedule(lines, now)
      schedule = @probes.schedule(now)
      gauge(lines, 'probes_due', 'Boards whose next probe time has passed (the backlog).', { {} => schedule['due'].to_i })
      next_at = schedule['next_at']
      gauge(lines, 'next_probe_due_seconds', 'Seconds until the earliest next probe, 0 when one is overdue.',
            { {} => next_at ? [next_at - now, 0].max : 0 })
      oldest = schedule['oldest_due_at']
      gauge(lines, 'oldest_overdue_seconds',
            'How long the longest-waiting due board has been due, 0 when none is (a stuck prober makes it grow).',
            { {} => oldest ? [now - oldest, 0].max : 0 })
    end

    def durations(lines, now)
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
      gauge(lines, 'boards_by_software', "Answering boards by software, the top #{TOP}, other, and FTN mailers.",
            by_software(tags, boards).transform_keys { |s| { software: s } })
    end

    # The top software of +boards+, other, and the FTN mailers apart.
    def by_software(tags, boards)
      software = prefixed(tags, 'sw:')
      mailers = software.delete(MAILER).to_i
      top(software, boards - mailers).merge(MAILER => mailers)
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

    def live_dials = live.fetch('live', 0).to_i

    # The Gate's live file (DialService#live_state), {} without one.
    def live
      return {} unless @dials_path && File.exist?(@dials_path)

      JSON.parse(File.read(@dials_path))
    rescue SystemCallError, JSON::ParserError
      {}
    end

    # How near the callers and the boards are to the dial limits, the dials
    # we refused, and the time and traffic of the dials.
    def dial_limits(lines, now)
      state  = live
      limits = LIMITS.to_h { |k| [k, state.dig('limits', k).to_i] }
      gauge(lines, 'dial_limit', "The Gate's dial limits (window_seconds, per_caller, per_host, idle_seconds).",
            limits.transform_keys { |k| { kind: k } })
      callers(lines, state, limits, now)
      gauge(lines, 'dial_host_lines_max', 'The most lines in use to one host now.',
            { {} => state.fetch('host_lines_max', 0).to_i })
      refusals(lines, now)
      traffic(lines, now)
    end

    # The callers nearest the per-caller limit.
    def callers(lines, state, limits, now)
      window = limits['window_seconds']
      counts = Array(state['caller_dials']).map { |times| Array(times).count { |t| t.to_i > now - window } }
      gauge(lines, 'dial_caller_max_in_window', 'The most dials one caller has in the current window.',
            { {} => counts.max.to_i })
      at_limit = limits['per_caller'].positive? ? counts.count { |n| n >= limits['per_caller'] } : 0
      gauge(lines, 'dial_callers_at_limit', 'Callers at the per-caller dial limit now.', { {} => at_limit })
    end

    def refusals(lines, now)
      totals = @history ? @history.refusal_totals : DialRepository::REASONS.product(DialRepository::FACES).to_h { |p| [p, 0] }
      gauge(lines, 'dial_refusals_total', 'Dials the Gate refused, by reason and face (kept as a running total).',
            totals.to_h { |(reason, face), n| [{ reason: reason, face: face }, n] })
      hour = @history ? @history.refusals_since(now - 3600) : DialRepository::REASONS.to_h { |r| [r, 0] }
      gauge(lines, 'dial_refusals_last_hour', 'Dials the Gate refused in the last hour, by reason.',
            hour.transform_keys { |r| { reason: r } })
    end

    def traffic(lines, now)
      count, seconds, bytes = @history ? @history.traffic_since(now - 3600) : [0, 0, 0]
      gauge(lines, 'dial_seconds_last_hour', 'Seconds on the line of the dials that ended in the last hour.',
            { {} => seconds })
      gauge(lines, 'dial_seconds_avg_last_hour', 'The average seconds on the line of those dials.',
            { {} => count.positive? ? (seconds.to_f / count).round(1) : 0 })
      gauge(lines, 'dial_bytes_last_hour', 'Bytes the boards sent through the Gate in the dials of the last hour.',
            { {} => bytes })
      totals = @probes.totals
      gauge(lines, 'dials_total', 'Every dial of the Gate by result (its probes of kind dial).',
            ProbeResultModel::RESULTS.to_h { |r| [{ result: r }, totals.fetch([r, 'dial'], 0)] })
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
