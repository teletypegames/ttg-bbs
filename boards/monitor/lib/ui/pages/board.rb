# frozen_string_literal: true

module UI
  # A dashboard: its panels under their rows, each with what it shows now
  # in one line (UI::Summary), the chosen one drawn in full under the list
  # when the screen is tall enough. The panels load behind the screen
  # (UI::Loader) and come in as they are ready; the dashboard refreshes
  # itself as often as it says (at least every REFRESH seconds).
  #
  # The arrows choose, RETURN opens a panel on the whole screen, T and
  # SHIFT-T step the time range, V sets the variables, R reloads, Q goes
  # back to the list.
  class Board < Screen
    # Seconds between refreshes when the dashboard sets none.
    REFRESH = 60
    # The shortest refresh.
    MIN_REFRESH = 15
    # The columns of a panel's title in the list.
    TITLE = { modern: 34, petscii: 15 }.freeze

    key(:up) { move(-1) }
    key(:down) { move(1) }
    key(:page_up, '-') { move(-list_rows) }
    key(:page_down, '+') { move(list_rows) }
    key(:enter, :right) { open_panel }
    key('t') { step_range(1) }
    key('T') { step_range(-1) }
    key('v', 'V') { push(VariablesPage.new(self)) if editable.any? }
    key('r', 'R') { load }
    key(:escape, :left, 'q', 'Q') { stop_and_back }
    every(0.5) { redraw if @loader&.changed? }
    every(5) { load if due? }

    # The dashboard (a Grafana::Dashboard), the range (a
    # Grafana::TimeRange), the MonitorService and the Loader.
    attr_reader :dashboard, :range, :service, :loader

    # The variables in effect: as the loader found them, once it has.
    def variables = @loader&.variables_ready? ? @loader.variables : @variables

    # The page of the dashboard of +entry+ (a Grafana::Entry), asked of
    # +service+ (a MonitorService).
    def initialize(service, entry)
      super()
      @service = service
      @entry   = entry
      @index   = 0
    end

    # Opens the dashboard and begins loading it.
    def enter
      @dashboard = @service.dashboard(@entry.uid)
      @variables = @dashboard.variables
      @range     = @dashboard.time
      load
    rescue Grafana::Error => e
      @error = e.message
    end

    # Coming back from a panel or the variables: shown as they were.
    def resume = redraw

    # Sets the variables (from the variables page) and loads again.
    def variables=(list)
      @loader&.stop
      @loader    = nil
      @variables = list
      load
    end

    # Sets the range (a Grafana::TimeRange) and loads again.
    def range=(range)
      @range = range
      load
    end

    # The panels in order.
    def panels = @dashboard ? @dashboard.panels : []

    # The variables a caller can set.
    def editable = Array(variables).select(&:editable?)

    # The header's words.
    def crumb = "#{@entry.group} › #{@entry.short_title}"

    # The header's right.
    def right
      return '' unless @loader

      state = @loader.done? ? @loader.started.strftime('%H:%M:%S') : 'loading…'
      "#{@range.label} · #{state}"
    end

    # The hint line.
    def hint
      vars = if editable.any?
               petscii? ? '  v vars' : '  V variables'
             else
               ''
             end
      petscii? ? "ret open  t time#{vars}  r  q back" : "↑↓ choose  RETURN open  T/⇧T time#{vars}  R reload  Q back"
    end

    # The variables' line, the list and, with room, the chosen panel.
    def body
      return Paint.wrap(@error, width).map { |l| Paint.run(l, :bad) } if @error
      return [Paint.run('This dashboard has no panels.', :dim)] if panels.empty?

      [*variables_line, *list, *preview]
    end

    private

    def variables_line
      shown = editable
      return [] if shown.empty?

      line = shown.flat_map { |v| [["#{Paint.plain(v.label)} ", :dim], [Paint.plain(v.shown), :bright], ['  ', :text]] }
      [line]
    end

    # The rows of the list and of the preview under it: [list, preview].
    def layout
      room = body_rows - (editable.any? ? 1 : 0)
      return [room, 0] if petscii? || room < 20

      wanted = panels.size + panels.map(&:section).uniq.compact.size
      list = wanted.clamp(6, [room * 3 / 5, 6].max)
      [list, room - list]
    end

    def list_rows = layout.first

    # The rows of the list: a row's title before its first panel.
    def list
      rows = []
      section = :none
      panels.each_with_index do |panel, i|
        rows << [Paint.run(panel.section.to_s.upcase, :accent), nil] if panel.section != section && panel.section
        section = panel.section
        rows << [panel_line(panel, i), i]
      end
      window(rows, list_rows)
    end

    def window(rows, size)
      at = rows.index { |_, i| i == @index } || 0
      @top ||= 0
      @top = at - size + 1 if at >= @top + size
      @top = [at - 1, 0].max if at < @top
      @top = @top.clamp(0, [rows.size - size, 0].max)
      rows[@top, size].map(&:first)
    end

    def panel_line(panel, index)
      lit   = index == @index
      title = TITLE.fetch(face)
      line  = [[lit ? '▸' : ' ', :accent], [Paint.plain(panel.name)[0, title].ljust(title), lit ? :bright : :text], [' ', :text]]
      line += Summary.line(@loader&.[](panel), width - title - 2, face)
      lit ? Paint.lit(Paint.fit(line, width)) : line
    end

    def preview
      rows  = layout.last
      panel = panels[@index]
      return [] if rows < 4 || panel.nil?

      title = [[Paint.plain(panel.name), :bright], ["  #{Paint.plain(panel.description)}", :dim]]
      visual = @loader&.[](panel)
      return [title, Paint.run('loading…', :dim)] unless visual

      [Paint.run('─' * width, :line), title, *render(visual, rows - 2, @range)]
    end

    def move(step) = @index = (@index + step).clamp(0, [panels.size - 1, 0].max)

    def open_panel
      return if panels.empty?

      push(PanelPage.new(self, @index))
    end

    def step_range(step)
      self.range = @range.step(step) if @range
    end

    # Loads the dashboard anew: the panels in sight first.
    def load
      return unless @dashboard

      @variables = variables
      @loader&.stop
      shown = panels.drop(@index) + panels.take(@index)
      @loader = Loader.new(@service, @dashboard, @variables, @range, points: width).start(shown)
    end

    # Whether it is time for a refresh.
    def due?
      return false unless @loader&.done?

      every = [@dashboard.refresh || REFRESH, MIN_REFRESH].max
      Time.now - @loader.started >= every
    end

    def stop_and_back
      @loader&.stop
      back
    end
  end
end
