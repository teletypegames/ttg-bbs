# frozen_string_literal: true

module Grafana
  # Makes a Visual of a panel and its data: by the panel's type when the
  # data fits it, else by the data's shape (log lines, series over time,
  # single values, a table), so a panel of a type the board has never seen
  # still shows what it holds.
  module Build
    # What each type of Grafana panel is drawn as.
    TYPES = {
      'timeseries'     => :chart,
      'graph'          => :chart,
      'trend'          => :chart,
      'xychart'        => :chart,
      'candlestick'    => :chart,
      'stat'           => :stat,
      'singlestat'     => :stat,
      'gauge'          => :gauge,
      'bargauge'       => :bars,
      'piechart'       => :pie,
      'barchart'       => :barchart,
      'histogram'      => :barchart,
      'table'          => :table,
      'table-old'      => :table,
      'logs'           => :logs,
      'state-timeline' => :states,
      'status-history' => :states
    }.freeze
    # Grafana's defaults of a stat, a gauge, a bar gauge: coloured by
    # thresholds, green and red from 80.
    VALUE_BASE = {
      'color'      => { 'mode' => 'thresholds' },
      'thresholds' => {
        'mode'  => 'absolute',
        'steps' => [{ 'color' => 'green', 'value' => nil }, { 'color' => 'red', 'value' => 80 }]
      }
    }.freeze

    module_function

    # The Visual of +panel+ (a Panel) and +result+ (a Result) over
    # [+from+, +to+] (ms).
    def visual(panel, result, from:, to:)
      steps  = Transformations.new(panel.transformations)
      frames = steps.apply(result.frames)
      notes  = result.errors + steps.skipped.map { |id| "transformation #{id} is not applied here" }
      return empty(result, notes) if frames.none? { |f| f.length.positive? }

      by_type(panel, frames, notes, from, to) || by_shape(panel, frames, notes)
    end

    # What is shown for no data: the errors, or the panel's words for none.
    def empty(result, notes)
      return Visual::Text.new(text: notes.join("\n"), level: :error, notes: []) unless result.errors.empty?

      Visual::Text.new(text: 'No data', level: :empty, notes: notes)
    end

    # The Visual the panel's type asks for, or +nil+ when the data does not
    # fit it.
    def by_type(panel, frames, notes, from, to)
      case TYPES[panel.type]
      when :chart then Charts.chart(panel, frames, notes) if frames.any?(&:series?)
      when :stat, :gauge, :bars, :pie then Values.values(panel, frames, notes, TYPES[panel.type])
      when :barchart then Values.barchart(panel, frames, notes)
      when :table then Tables.table(panel, frames, notes)
      when :logs then Logs.logs(panel, frames, notes)
      when :states then States.states(panel, frames, notes, from, to) if frames.any?(&:time_field)
      end
    end

    # The Visual the data's shape suggests.
    def by_shape(panel, frames, notes)
      return Logs.logs(panel, frames, notes) if Logs.logs?(frames)
      return Charts.chart(panel, frames, notes) if frames.any? { |f| f.series? && f.length > 2 }
      return Values.values(panel, frames, notes, :stat) if frames.all? { |f| f.length <= 1 && f.number_fields.any? }

      Tables.table(panel, frames, notes)
    end

    # The FieldDisplay of +field+ of +frame+ in +panel+ (+index+: its place
    # among the series), with +base+ under the panel's config.
    def display(panel, frame, field, index: 0, base: {})
      FieldDisplay.new(panel.field_config, field, ref_id: frame.ref_id, index: index, base: base)
    end

    # Whether +field+ is hidden in the panel (<tt>custom.hideFrom.viz</tt>,
    # <tt>custom.hidden</tt>).
    def hidden?(display)
      custom = display.custom
      custom['hidden'] == true || custom.dig('hideFrom', 'viz') == true
    end
  end
end
