# frozen_string_literal: true

module UI
  # Loads a dashboard's panels behind the screen, a few at a time, so the
  # caller sees each as it comes: the variables first (their options found
  # anew), then each panel's Grafana::Visual. A page asks #[] and redraws
  # while #changed?. A new Loader replaces one whose variables or range
  # changed; #stop leaves an old one's work unfinished.
  class Loader
    # Panels loaded at once for one caller.
    WORKERS = 3

    # The variables in effect (with their options, once found).
    attr_reader :variables
    # The time the load began.
    attr_reader :started

    # [service]   the MonitorService
    # [dashboard] the Grafana::Dashboard
    # [variables] its Grafana::Variables as the caller set them
    # [range]     the Grafana::TimeRange
    # [points]    the columns a chart has
    def initialize(service, dashboard, variables, range, points:)
      @service   = service
      @dashboard = dashboard
      @variables = variables
      @range     = range
      @points    = points
      @visuals   = {}
      @lock      = Mutex.new
      @changed   = true
      @started   = Time.now
    end

    # Begins: the variables, then +panels+ (the shown ones first). Returns
    # +self+.
    def start(panels)
      @queue = Queue.new
      panels.each { |p| @queue << p }
      @queue.close
      @threads = [Thread.new { load_variables }]
      self
    end

    # The Visual of +panel+, or +nil+ while it loads.
    def [](panel) = @lock.synchronize { @visuals[panel] }

    # Whether a panel came since the last ask (and forgets it).
    def changed?
      @lock.synchronize do
        was = @changed
        @changed = false
        was
      end
    end

    # Whether every panel has come.
    def done? = @threads&.none?(&:alive?)

    # Whether the variables have been found.
    def variables_ready? = @lock.synchronize { @variables_ready ? true : false }

    # Leaves the work: the threads end after the panel each is on.
    def stop
      @stopped = true
      @queue&.clear
    end

    private

    def load_variables
      found = @service.variables(@dashboard, @variables, @range)
      @lock.synchronize do
        @variables = found
        @variables_ready = true
        @changed = true
      end
    rescue StandardError => e
      Rubbs.log('monitor', "variables of #{@dashboard.uid}: #{e.message}")
      @lock.synchronize { @variables_ready = true }
    ensure
      workers = Array.new(WORKERS) { Thread.new { work } }
      workers.each(&:join)
    end

    def work
      while !@stopped && (panel = @queue.pop)
        visual = visual_of(panel)
        @lock.synchronize do
          @visuals[panel] = visual
          @changed = true
        end
      end
    end

    def visual_of(panel)
      @service.visual(@dashboard, panel, @variables, @range, points: @points)
    rescue StandardError => e
      Rubbs.log('monitor', "#{@dashboard.uid} / #{panel.name}: #{e.class}: #{e.message}")
      Grafana::Visual::Text.new(text: "This panel could not be drawn here (#{e.class}).", level: :error, notes: [])
    end
  end
end
