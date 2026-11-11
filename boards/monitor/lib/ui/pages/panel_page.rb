# frozen_string_literal: true

module UI
  # One panel on the whole screen, drawn as wide as the screen is: a chart
  # with its axes and legend, a table or a log to scroll, the values with
  # their bars. Left and right go to the panel before and after, up and
  # down scroll, S shows one series of a chart at a time (and all again), I
  # shows the panel's description, T and SHIFT-T step the time range, R
  # reloads, Q goes back to the dashboard.
  class PanelPage < Screen
    key(:left, ',') { turn(-1) }
    key(:right, '.') { turn(1) }
    key(:up) { scroll(-1) }
    key(:down) { scroll(1) }
    key(:page_up, '-') { scroll(-(body_rows - 2)) }
    key(:page_down, '+') { scroll(body_rows - 2) }
    key(:home) { @scroll = 0 }
    key('s', 'S') { focus }
    key('i', 'I') { @info = !@info }
    key('t') { step_range(1) }
    key('T') { step_range(-1) }
    key('r', 'R') { load }
    key(:escape, :enter, 'q', 'Q') { back }
    every(0.5) { redraw if changed? }
    every(5) { load if due? }

    # The panel at +index+ of +board+ (a UI::Board).
    def initialize(board, index)
      super()
      @board = board
      @index = index
      @lock  = Mutex.new
    end

    # Loads the panel when it comes on the screen.
    def enter = load

    # The header's words.
    def crumb = "#{@board.crumb.split(' › ').last} › #{panel.name}"

    # The header's right.
    def right = "#{@index + 1}/#{@board.panels.size} · #{@board.range.label}#{" · #{@at.strftime('%H:%M:%S')}" if @at}"

    # The hint line.
    def hint
      return 'crsr scroll/turn  s series  t time  q back' if petscii?

      '←→ panel  ↑↓ scroll  S one series/all  I about  T/⇧T time  R reload  Q back'
    end

    # The panel's description (with I), then the panel.
    def body
      about = if @info && !panel.description.empty?
                Paint.wrap(panel.description, width, 4).map { |l|
                  Paint.run(l, :dim)
                } + [[]]
              else
                []
              end
      shown = visual
      return [*about, Paint.run('loading…', :dim)] unless shown

      [*about, *render(shown, body_rows - about.size, @board.range, scroll: @scroll.to_i, focus: @focus)]
    end

    private

    def panel = @board.panels[@index]

    def visual = @lock.synchronize { @visual } || @board.loader&.[](panel)

    def changed?
      @lock.synchronize do
        was = @changed
        @changed = false
        was
      end
    end

    # Loads the panel as wide as the screen, behind it.
    def load
      @at = Time.now
      wanted = panel
      Thread.new do
        found = @board.service.visual(@board.dashboard, wanted, @board.variables, @board.range, points: width * 2)
        @lock.synchronize do
          next unless wanted == panel

          @visual  = found
          @changed = true
        end
      rescue StandardError => e
        Rubbs.log('monitor', e)
      end
    end

    def due? = @at && Time.now - @at >= [@board.dashboard.refresh || Board::REFRESH, Board::MIN_REFRESH].max

    def turn(step)
      @index = (@index + step) % @board.panels.size
      @lock.synchronize { @visual = nil }
      @scroll = 0
      @focus  = nil
      load
    end

    def scroll(step)
      most = [Render.rows(visual) - 1, 0].max if visual
      @scroll = (@scroll.to_i + step).clamp(0, most || 0)
    end

    # One series after another, then all again.
    def focus
      shown = visual
      return unless shown&.kind == :chart && shown.series.size > 1

      @focus = @focus.nil? ? 0 : @focus + 1
      @focus = nil if @focus >= shown.series.size
    end

    def step_range(step)
      @board.range = @board.range.step(step)
      load
    end
  end
end
