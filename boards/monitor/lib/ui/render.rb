# frozen_string_literal: true

module UI
  # A panel's Grafana::Visual drawn in a box of +width+ × +height+ cells on
  # +face+ (+:modern+ or +:petscii+): lines of runs (UI::Paint), never more
  # than +height+. +scroll+ is the first row of a table or log shown, and
  # +focus+ the one series a chart shows alone (+nil+: all).
  class Render
    # The columns of a chart's value axis.
    AXIS = { modern: 9, petscii: 6 }.freeze
    # The colour of each log level.
    LEVEL = { error: :bad, warn: :warn, info: :good, debug: :dim, unknown: :text }.freeze
    # The colour of each alert state.
    STATE = { 'firing' => :bad, 'error' => :bad, 'pending' => :warn, 'nodata' => :warn, 'normal' => :good }.freeze

    # The box and what is in it; see the class.
    def initialize(visual, width:, height:, face:, from:, to:, scroll: 0, focus: nil)
      @visual = visual
      @width  = [width, 10].max
      @height = [height, 1].max
      @face   = face
      @from   = from
      @to     = to
      @scroll = scroll
      @focus  = focus
    end

    # The lines.
    def lines
      body = send(@visual.kind)
      notes = Array(@visual.respond_to?(:notes) ? @visual.notes : []).map { |n| Paint.run("! #{n}", :warn) }
      body = body.first([@height - notes.size, 1].max) + notes.first(@height - [body.size, 1].min)
      body.first(@height).map { |line| Paint.fit(line, @width) }
    end

    # How many rows a table or log has (for scrolling), else 0.
    def self.rows(visual)
      case visual.kind
      when :table, :states then visual.rows.size
      when :logs then visual.lines.size
      when :alerts then visual.rules.size
      when :values then visual.values.size
      else 0
      end
    end

    private

    def petscii? = @face == :petscii

    def text
      color = { error: :bad, empty: :dim }.fetch(@visual.level, :text)
      Paint.wrap(@visual.text, @width, @height).map { |l| Paint.run(l, color) }
    end

    # Lines over time: the value axis at the left, the plot, the time under
    # it, then the legend as far as there is room.
    def chart
      series = @focus ? [@visual.series[@focus % @visual.series.size]] : @visual.series
      return Paint.wrap('No data', @width).map { |l| Paint.run(l, :dim) } if series.empty?

      legend = legend_lines(series)
      plot_h = [@height - 1 - [legend.size, (@height / 3)].min, 2].max
      plot(series, plot_h) + [time_axis] + legend.first(@height - plot_h - 1)
    end

    def plot(series, plot_h)
      low, high = range(series)
      axis = AXIS.fetch(@face)
      rows = Charts.plot(
        series,
        width:   @width - axis,
        height:  plot_h,
        from:    @from,
        to:      @to,
        low:     low,
        high:    high,
        face:    @face,
        stacked: @visual.stacked && @focus.nil?
      )
      rows.each_with_index.map do |row, i|
        label = if i.zero?
                  high
                else
                  (i == rows.size - 1 ? low : nil)
                end
        label = (low + high) / 2.0 if i == rows.size / 2 && rows.size > 4
        [[axis_label(label, axis), :dim], *merge(row)]
      end
    end

    def axis_label(value, axis)
      return ' ' * axis if value.nil?

      text = @visual.look ? Grafana::Units.format(value, @visual.look.unit) : Grafana::Units.number(value)
      text = text.delete(' ') if text.length >= axis
      "#{text[0, axis - 1].rjust(axis - 1)} "
    end

    # The range of the value axis: the panel's min and max, else the data's
    # (from zero when the data does not go below it), stacked when stacked.
    def range(series)
      values = (if @visual.stacked && @focus.nil?
                  Charts.stack(series).flat_map { |_, p|
                    p
                  }
                else
                  series.flat_map(&:points)
                end).map(&:last)
      low  = @visual.min || [values.min || 0.0, 0.0].min
      high = @visual.max || values.max || 1.0
      high = low + 1.0 if high <= low
      [low, high]
    end

    def time_axis
      axis  = AXIS.fetch(@face)
      left  = clock(@from)
      right = clock(@to)
      gap   = [@width - axis - left.length - right.length, 1].max
      [[' ' * axis, :dim], [left, :dim], [' ' * gap, :dim], [right, :dim]]
    end

    def clock(ms)
      at = Time.at(ms / 1000.0)
      if @to - @from >= 86_400_000
        at.strftime(petscii? ? '%m-%d' : '%m-%d %H:%M')
      else
        at.strftime('%H:%M')
      end
    end

    # One line a series: its colour, name, last value and the legend's
    # figures.
    def legend_lines(series)
      series.map do |s|
        stats = petscii? ? [] : s.stats.filter_map { |name, text| "#{name.downcase} #{text}" unless name == 'Last *' }
        tail = [s.last_text, *stats].join('  ')
        name = Paint.plain(s.name)
        [[petscii? ? '█' : '■', s.color], [' ', :text], [name[0, [@width - tail.length - 4, 8].max], :text], ['  ', :text],
         [tail, :bright]]
      end
    end

    def merge(runs)
      runs.each_with_object([]) do |(text, color), out|
        out.last && out.last[1] == color ? out.last[0] += text : out << [text.dup, color]
      end
    end

    # Values: big tiles of a few, a bar each when many, a pie's shares.
    def values
      list = @visual.values.drop(@scroll)
      return Paint.wrap('No data', @width).map { |l| Paint.run(l, :dim) } if list.empty?
      return tiles(list) if @visual.style == :stat && list.size <= tile_count

      list.map { |v| value_bar(v) }
    end

    def tile_count = petscii? ? 2 : [@width / 24, 1].max * [@height / 4, 1].max

    def tiles(list)
      per_row = list.size.clamp(1, [@width / 24, 1].max)
      per_row = 1 if petscii?
      size = @width / per_row
      list.each_slice(per_row).flat_map do |row|
        names = row.map { |v| [Paint.plain(@visual.names ? v.name : '').ljust(size)[0, size], :dim] }
        big   = row.map { |v| [v.text.ljust(size)[0, size], v.color] }
        spark = row.map { |v| [Charts.spark(v.spark.map(&:last), size - 2, @face).ljust(size), v.color] }
        [names, big, spark, []]
      end
    end

    def value_bar(value)
      name_w = @visual.values.map { |v| Paint.plain(v.name).length }.max.to_i.clamp(4, [@width / 3, 4].max)
      text_w = [@visual.values.map { |v| v.text.length }.max.to_i, 4].max
      bar_w  = [@width - name_w - text_w - 3, 1].max
      fraction = value.fraction || 0
      share = @visual.style == :pie && value.fraction ? " #{(value.fraction * 100).round}%" : ''
      [[Paint.plain(value.name)[0, name_w].ljust(name_w), :text], [' ', :text],
       [Charts.bar(fraction, bar_w - share.length, @face).ljust(bar_w - share.length), value.color], [share, :dim],
       [' ', :text], [value.text.rjust(text_w), value.color]]
    end

    def table
      widths = column_widths
      head = @visual.columns.each_with_index.map { |c, i| [cell_text(Paint.plain(c), widths[i], false), :accent] }
      rows = @visual.rows.drop(@scroll).first(@height - 1).map do |row|
        row.each_with_index.map { |cell, i| [cell_text(Paint.plain(cell.text), widths[i], cell.numeric), cell.color || :text] }
      end
      more = @visual.tables > 1 ? [Paint.run("1 of #{@visual.tables} tables", :dim)] : []
      [spaced(head), *rows.map { |r| spaced(r) }, *more]
    end

    def cell_text(text, width, right) = right ? text[0, width].rjust(width) : text[0, width].ljust(width)

    def spaced(cells) = cells.flat_map { |c| [c, [' ', :text]] }

    # Each column as wide as its widest words, shrunk to share the width.
    def column_widths
      want = @visual.columns.each_with_index.map do |c, i|
        ([c.length] + @visual.rows.first(200).map { |r| Paint.plain(r[i]&.text).length }).max.clamp(1, 60)
      end
      room = @width - want.size
      while want.sum > room && want.max > 4
        widest = want.index(want.max)
        want[widest] -= 1
      end
      want
    end

    def logs
      lines = @visual.lines.drop(@scroll).first(@height)
      return Paint.wrap('No log lines', @width).map { |l| Paint.run(l, :dim) } if lines.empty?

      lines.map do |line|
        stamp = if line.time
                  Time.at(line.time / 1000.0).strftime(petscii? ? '%H:%M' : '%m-%d %H:%M:%S')
                else
                  ''
                end
        [[stamp, :dim], [' ', :text], [Paint.plain(line.text), LEVEL.fetch(line.level, :text)]]
      end
    end

    # States over time: a row a series, its stretches as coloured blocks
    # across the range, and its state now.
    def states
      name_w = petscii? ? 10 : [@visual.rows.map { |n, _| n.length }.max.to_i, @width / 4].min
      now_w  = petscii? ? 6 : 12
      strip  = [@width - name_w - now_w - 2, 4].max
      @visual.rows.drop(@scroll).first(@height).map do |name, segments|
        now = segments.last
        [[Paint.plain(name)[0, name_w].ljust(name_w), :text], [' ', :text], *strip_runs(segments, strip),
         [' ', :text], [(now&.text || '—')[0, now_w], now&.color || :dim]]
      end
    end

    def strip_runs(segments, width)
      span = [@to - @from, 1].max.to_f
      cells = Array.new(width) do |i|
        at = @from + (span * (i + 0.5) / width)
        segments.reverse.find { |s| s.time <= at }
      end
      merge(cells.map { |s| [s ? '█' : '·', s&.color || :line] })
    end

    def alerts
      rules = @visual.rules.drop(@scroll).first(@height)
      return Paint.wrap('No alert rules', @width).map { |l| Paint.run(l, :dim) } if rules.empty?

      rules.map do |r|
        since = r.since ? " since #{Time.at(r.since / 1000.0).strftime('%m-%d %H:%M')}" : ''
        [[r.state.upcase.ljust(8), STATE.fetch(r.state, :text)], [Paint.plain(r.name), :text], [since, :dim]]
      end
    end
  end
end
