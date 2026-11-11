# frozen_string_literal: true

require_relative 'test_helper'

# The reading of Grafana's JSON: dashboards, variables, frames, units,
# field configs, transformations, and panels made visuals.
class UnitsTest < Minitest::Test
  def test_sizes_rates_and_percentages
    assert_equal '118 MiB', Grafana::Units.format(123_456_789, 'bytes')
    assert_equal '2.3 kB/s', Grafana::Units.format(2300, 'Bps')
    assert_equal '45.7%', Grafana::Units.format(0.4567, 'percentunit')
    assert_equal '12.3 K', Grafana::Units.format(12_345, 'short')
    assert_equal '1.5 tok/s', Grafana::Units.format(1.5, 'suffix: tok/s')
  end

  def test_durations_and_none
    assert_equal '1.5 min', Grafana::Units.format(90, 's')
    assert_equal '2 days, 7 hours', Grafana::Units.format(200_000, 'dtdurations')
    assert_equal '—', Grafana::Units.format(nil, 's')
    assert_equal '3.14', Grafana::Units.format(3.14159, 'none', 2)
  end
end

class InterpolatorTest < Minitest::Test
  def variable(**over)
    Grafana::Variable.of({
      'type'       => 'custom',
      'name'       => 'k',
      'multi'      => true,
      'includeAll' => true,
      'query'      => 'a.b,c',
      'current'    => { 'value' => %w[a.b c] }
    }.merge(over))
  end

  def test_promql_regex_and_sql_lists
    i = Grafana::Interpolator.new([variable], from: 1, to: 2)
    assert_equal 'x=~"(a\\\\.b|c)" [$__rate_interval] 1', i.apply('x=~"$k" [$__rate_interval] $__from', type: 'prometheus')
    assert_equal "IN ('a.b','c')", i.apply('IN ($k)', type: 'mysql')
    assert_equal 'a.b,c', i.apply('${k:csv}')
  end

  def test_all_takes_the_all_value
    all = variable('allValue' => '.+', 'current' => { 'value' => ['$__all'] })
    assert_equal '.+', Grafana::Interpolator.new([all], from: 1, to: 2).apply('$k', type: 'loki')
    assert_equal 'All', all.shown
  end

  def test_a_custom_list_of_texts_and_values
    v = Grafana::Variable.of({ 'type' => 'custom', 'name' => 'm', 'query' => 'excluded : Uptime-Kuma/,included : __none__' })
    assert_equal([%w[excluded Uptime-Kuma/], %w[included __none__]], v.options.map { |o| [o.text, o.value] })
    assert_equal ['Uptime-Kuma/'], v.with_options(v.options).current
  end
end

class DashboardTest < Minitest::Test
  def test_rows_make_sections_in_reading_order
    time = { 'from' => 'now-24h', 'to' => 'now' }
    json = { 'dashboard' => { 'uid' => 'u', 'title' => 'VPS: Host', 'time' => time, 'panels' => [
      { 'type' => 'stat', 'title' => 'B', 'gridPos' => { 'y' => 0, 'x' => 12 } },
      { 'type' => 'stat', 'title' => 'A', 'gridPos' => { 'y' => 0, 'x' => 0 } },
      {
        'type'      => 'row',
        'title'     => 'Closed',
        'collapsed' => true,
        'gridPos'   => { 'y' => 9 },
        'panels'    => [{ 'type' => 'table', 'title' => 'C' }]
      },
      { 'type' => 'row', 'title' => 'Open', 'gridPos' => { 'y' => 5 } },
      { 'type' => 'timeseries', 'title' => 'D', 'gridPos' => { 'y' => 6 } }
    ] } }
    dashboard = Grafana::Dashboard.of(json)
    assert_equal([[nil, %w[A B]], ['Open', ['D']], ['Closed', ['C']]], dashboard.sections.map { |s|
      [s.title, s.panels.map(&:title)]
    })
    assert_equal 86_400, dashboard.time.span
  end

  def test_an_entry_is_grouped_by_the_prefix
    entry = Grafana::Entry.of({ 'uid' => 'x', 'title' => 'BBS: Calls', 'tags' => ['bbs'] })
    assert_equal %w[BBS Calls], [entry.group, entry.short_title]
  end

  def test_a_time_range_steps_through_the_presets
    range = Grafana::TimeRange.of({ 'from' => 'now-6h', 'to' => 'now' })
    assert_equal %w[6h 12h 3h], [range.label, range.step(1).label, range.step(-1).label]
    assert_equal 21_600, Grafana::TimeRange.of({ 'from' => 'now/d', 'to' => 'now/d' }).span
  end
end

class FieldDisplayTest < Minitest::Test
  def field(name = 'Value', labels = {}) = Grafana::Field.new(name: name, type: :number, values: [1.0], labels: labels)

  def test_overrides_thresholds_and_mappings
    config = {
      'defaults'  => {
        'unit'       => 'percent',
        'thresholds' => { 'steps' => [{ 'color' => 'green', 'value' => nil }, { 'color' => 'red', 'value' => 80 }] },
        'color'      => { 'mode' => 'thresholds' }
      },
      'overrides' => [{
        'matcher'    => { 'id' => 'byName', 'options' => 'up' },
        'properties' => [{
          'id'    => 'mappings',
          'value' => [{
            'type'    => 'value',
            'options' => { '1' => { 'text' => 'UP', 'color' => 'green' } }
          }]
        }]
      }]
    }
    plain = Grafana::FieldDisplay.new(config, field)
    assert_equal ['90%', Grafana::Colors.rgb('red')], [plain.text(90.0), plain.color(90.0)]
    assert_equal Grafana::Colors.rgb('green'), plain.color(10.0)
    up = Grafana::FieldDisplay.new(config, field('up'))
    assert_equal 'UP', up.text(1.0)
  end

  def test_a_single_label_names_the_series
    assert_equal 'iowait', field('Value', { 'mode' => 'iowait' }).display_name
  end
end

class TransformTest < Minitest::Test
  def frame(labels, value, ref: 'A')
    Grafana::Frame.new(ref_id: ref, fields: [
      Grafana::Field.new(name: 'Time', type: :time, values: [1000]),
      Grafana::Field.new(name: 'Value', type: :number, values: [value], labels: labels)
    ])
  end

  def test_a_table_query_is_one_table_then_organized_and_sorted
    query = { 'refId' => 'A', 'format' => 'table', 'datasource' => { 'type' => 'prometheus' } }
    frames = Grafana::Tabulate.apply([[query, [frame({ 'c' => 'x' }, 1.0), frame({ 'c' => 'y' }, 5.0)]]])
    steps = Grafana::Transformations.new([
      { 'id' => 'organize', 'options' => { 'excludeByName' => { 'Time' => true }, 'renameByName' => { 'Value' => 'n' } } },
      { 'id' => 'sortBy', 'options' => { 'sort' => [{ 'field' => 'n', 'desc' => true }] } },
      { 'id' => 'heatmapThing' }
    ])
    table = steps.apply(frames).first
    assert_equal [%w[c n], [['y', 5.0], ['x', 1.0]]], [table.fields.map(&:display_name), [table.row(0), table.row(1)]]
    assert_equal ['heatmapThing'], steps.skipped
  end

  def test_reduce_makes_a_row_a_series
    steps = Grafana::Transformations.new([{ 'id' => 'reduce', 'options' => { 'reducers' => %w[max] } }])
    table = steps.apply([frame({ 'c' => 'x' }, 3.0)]).first
    assert_equal [%w[Field Max], ['x', 3.0]], [table.fields.map(&:name), table.row(0)]
  end
end

class BuildTest < Minitest::Test
  def panel(type, options = {}) = Grafana::Panel.of({ 'type' => type, 'title' => 'P', 'options' => options }, nil)

  def series
    Grafana::Frame.new(fields: [
      Grafana::Field.new(name: 'Time', type: :time, values: [1000, 2000, 3000]),
      Grafana::Field.new(name: 'Value', type: :number, values: [1.0, 5.0, 3.0], labels: { 'mode' => 'user' })
    ])
  end

  def visual(type, frames, options = {})
    Grafana::Build.visual(panel(type, options), Grafana::Result.new(frames: frames, errors: []), from: 0, to: 4000)
  end

  def test_each_type_and_the_shape_of_the_data
    assert_equal :chart, visual('timeseries', [series]).kind
    stat = visual('stat', [series])
    assert_equal [:values, '3', Grafana::Colors.rgb('green')], [stat.kind, stat.values.first.text, stat.values.first.color]
    assert_equal :table, visual('table', [series]).kind
    assert_equal :chart, visual('some-plugin', [series]).kind
  end

  def test_no_data_and_errors
    assert_equal :empty, visual('stat', []).level
    failed = Grafana::Build.visual(panel('stat'), Grafana::Result.new(frames: [], errors: ['A: bad']), from: 0, to: 1)
    assert_equal [:error, 'A: bad'], [failed.level, failed.text]
  end

  def test_every_kind_draws_on_both_faces_within_its_box
    [visual('timeseries', [series]), visual('stat', [series]), visual('bargauge', [series]), visual('table', [series]),
     visual('state-timeline', [series])].each do |v|
      %i[modern petscii].each do |face|
        lines = UI::Render.new(v, width: 40, height: 8, face: face, from: 0, to: 4000).lines
        assert_operator lines.size, :<=, 8
        assert(lines.all? { |l| UI::Paint.width(l) == 40 }, "#{v.kind} on #{face}")
      end
    end
  end
end
