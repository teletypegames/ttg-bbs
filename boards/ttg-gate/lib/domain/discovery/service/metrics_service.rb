# frozen_string_literal: true

require 'fileutils'

module Discovery
  # data/discovery-metrics.prom: the numbers of Global Discovery in the
  # Prometheus text format, for node-exporter's textfile collector. Written
  # whole into a temporary file and renamed, so a scrape never reads half.
  class MetricsService
    PREFIX = 'ttg_gate_bbs_discovery'

    def initialize(path, catalog:, probes:)
      @path    = path
      @catalog = catalog
      @probes  = probes
    end

    def write(now: Time.now.to_i)
      FileUtils.mkdir_p(File.dirname(@path))
      tmp = "#{@path}.tmp"
      File.write(tmp, text(now))
      File.rename(tmp, @path)
    rescue SystemCallError => e
      warn "ttg-gate-bbs-discovery: metrics: #{e.message}"
    end

    def text(now)
      lines = []
      gauge(lines, 'boards', 'Boards of the catalog by state (aliases and hidden boards apart).',
            (BoardStateModel::STATES + ['archived']).to_h { |s| [{ state: s }, @probes.state_counts.fetch(s, 0)] })
      counts = @probes.result_counts(now - 3600)
      gauge(lines, 'probes_last_hour', 'Probes of the last hour by result.',
            ProbeResultModel::RESULTS.to_h { |r| [{ result: r }, counts.fetch(r, 0)] })
      gauge(lines, 'last_probe_timestamp_seconds', 'When the last probe was made.', { {} => @probes.last_probe_at.to_i })
      sources = @catalog.sources
      gauge(lines, 'source_records', 'Records of the last applied import a source.',
            sources.to_h { |s| [{ source: s['id'] }, s['record_count'].to_i] })
      gauge(lines, 'source_last_import_timestamp_seconds', 'When a source was last applied.',
            sources.to_h { |s| [{ source: s['id'] }, s['last_parse_at'].to_i] })
      gauge(lines, 'source_failing', '1 when the last import of a source failed or was refused.',
            sources.to_h { |s| [{ source: s['id'] }, s['last_error'] ? 1 : 0] })
      gauge(lines, 'metrics_timestamp_seconds', 'When this file was written.', { {} => now })
      lines.join("\n") << "\n"
    end

    private

    def gauge(lines, name, help, values)
      lines << "# HELP #{PREFIX}_#{name} #{help}" << "# TYPE #{PREFIX}_#{name} gauge"
      values.each do |labels, value|
        label = labels.empty? ? '' : "{#{labels.map { |k, v| "#{k}=\"#{v}\"" }.join(',')}}"
        lines << "#{PREFIX}_#{name}#{label} #{value}"
      end
    end
  end
end
