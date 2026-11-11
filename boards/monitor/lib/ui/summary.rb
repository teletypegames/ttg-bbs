# frozen_string_literal: true

module UI
  # A panel at a glance, in one line of +width+ columns: a chart's
  # sparkline and its highest series now, a stat's values in their
  # colours, a table's size and first row, a log's newest line, the alerts
  # firing. The dashboard's list shows one beside each panel.
  module Summary
    module_function

    # The runs of +visual+ in +width+ columns on +face+.
    def line(visual, width, face)
      return Paint.run('…', :dim) if visual.nil?

      runs = send(:"of_#{visual.kind}", visual, width, face)
      Paint.fit(runs, width)
    end

    def of_text(visual, _width, _face)
      color = { error: :bad, empty: :dim }.fetch(visual.level, :text)
      Paint.run(Paint.plain(visual.text.to_s.lines.first.to_s.strip.delete('#*`')), color)
    end

    def of_chart(visual, width, face)
      return Paint.run('No data', :dim) if visual.series.empty?

      top   = visual.series.max_by { |s| s.last.to_f }
      spark = Charts.spark(top.points.map(&:last), [width / 3, 24].min, face)
      tail  = visual.series.size > 1 ? "#{Paint.plain(top.name)} " : ''
      count = visual.series.size > 1 ? "  #{visual.series.size} series" : ''
      [[spark, top.color], [' ', :text], [tail, :dim], [top.last_text, :bright], [count, :dim]]
    end

    def of_values(visual, _width, _face)
      return Paint.run('No data', :dim) if visual.values.empty?

      visual.values.first(6).flat_map do |v|
        name = visual.names || visual.values.size > 1 ? "#{Paint.plain(v.name)} " : ''
        [[name, :dim], [v.text, v.color], ['  ', :text]]
      end
    end

    def of_table(visual, _width, _face)
      first = visual.rows.first
      words = first ? first.map { |c| Paint.plain(c.text) }.reject(&:empty?).join(' · ') : ''
      [["#{visual.rows.size} row#{'s' unless visual.rows.size == 1}", :bright], ['  ', :text], [words, :dim]]
    end

    def of_logs(visual, _width, _face)
      newest = visual.lines.first
      return Paint.run('No log lines', :dim) unless newest

      [["#{visual.lines.size} lines", :bright], ['  ', :text],
       [Paint.plain(newest.text), Render::LEVEL.fetch(newest.level, :text)]]
    end

    def of_states(visual, _width, _face)
      visual.rows.first(6).flat_map do |name, segments|
        now = segments.last
        [["#{Paint.plain(name)} ", :dim], [now&.text.to_s, now&.color || :dim], ['  ', :text]]
      end
    end

    def of_alerts(visual, _width, _face)
      counts = visual.rules.group_by(&:state).transform_values(&:size)
      return Paint.run('No alert rules', :dim) if counts.empty?

      counts.sort_by { |state, _| Render::STATE.keys.index(state) || 9 }.flat_map do |state, n|
        [["#{n} #{state}", Render::STATE.fetch(state, :text)], ['  ', :text]]
      end
    end
  end
end
