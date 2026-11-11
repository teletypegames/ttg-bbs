# frozen_string_literal: true

require 'digest'

# What the board asks Grafana, for every caller: the dashboards (the
# search), a dashboard, its variables' options, and each panel as a
# Grafana::Visual. Answers are kept a little while (Rubbs::Common::Storage::Cache),
# so callers looking at the same dashboard share its queries, and at most
# PARALLEL questions go to Grafana at once.
class MonitorService
  # Questions to Grafana at once, over every caller.
  PARALLEL = 6
  # Seconds the list of dashboards and a dashboard's JSON are kept.
  LIST_TTL = 60
  # Seconds a panel's data is kept.
  PANEL_TTL = 15

  # [client] a Grafana::Client
  def initialize(client)
    @client  = client
    @slots   = SizedQueue.new(PARALLEL).tap { |q| PARALLEL.times { q << true } }
    @lists   = Rubbs::Common::Storage::Cache.new(ttl: LIST_TTL, max_entries: 200)
    @panels  = Rubbs::Common::Storage::Cache.new(ttl: PANEL_TTL, max_entries: 2000, size: ->(_) { 1 })
  end

  # Whether Grafana's token is set.
  def configured? = @client.configured?

  # Every dashboard the token sees (Grafana::Entry), by group and title.
  def dashboards
    @lists.fetch(:search) do
      items = ask { @client.get('/api/search', { 'type' => 'dash-db', 'limit' => '5000' }) }
      Array(items).map { |item| Grafana::Entry.of(item) }.sort_by { |e| [e.group.downcase, e.title.downcase] }
    end
  end

  # The Grafana::Dashboard of +uid+.
  def dashboard(uid)
    @lists.fetch([:dashboard, uid]) { Grafana::Dashboard.of(ask { @client.get("/api/dashboards/uid/#{uid}") }) }
  end

  # The dashboard's +variables+ with their options found over +range+ (a
  # Grafana::TimeRange).
  def variables(dashboard, variables, range)
    from, to = range.millis
    key = [:variables, dashboard.uid, digest(variables), range.span]
    @lists.fetch(key) { resolver.resolve(variables, from: from, to: to, title: dashboard.title) }
  end

  # The Grafana::Visual of +panel+ of +dashboard+ with +variables+ over
  # +range+, drawn in +points+ columns. Errors become a Visual::Text.
  def visual(dashboard, panel, variables, range, points:)
    key = [:panel, dashboard.uid, panel.id, panel.title, digest(variables), range.span, points]
    @panels.fetch(key) { make_visual(dashboard, panel, variables, range, points) }
  rescue Grafana::Error => e
    Grafana::Visual::Text.new(text: e.message, level: :error, notes: [])
  end

  # The Grafana::Visual::Alerts of Grafana's alert rules.
  def alerts
    groups = ask { @client.get('/api/prometheus/grafana/api/v1/rules') }.dig('data', 'groups')
    rules = Array(groups).flat_map { |g| Array(g['rules']).map { |r| rule(g, r) } }
    order = %w[firing pending error nodata normal inactive]
    Grafana::Visual::Alerts.new(rules: rules.sort_by { |r| [order.index(r.state) || 9, r.name] }, notes: [])
  end

  private

  def make_visual(dashboard, panel, variables, range, points)
    from, to = range.millis
    interpolator = Grafana::Interpolator.new(variables, from: from, to: to, dashboard: dashboard.title)
    return text_panel(panel, interpolator) if panel.type == 'text'
    return alerts if panel.type == 'alertlist'
    return library(panel) if panel.library?

    result = result_of(dashboard, panel, interpolator, from, to, points)
    Grafana::Build.visual(panel, result, from: from, to: to)
  end

  def result_of(dashboard, panel, interpolator, from, to, points)
    source = shared_source(dashboard, panel)
    runner.run(source || panel, interpolator, from: from, to: to, points: points)
  end

  # The panel whose results a panel of the Dashboard source reuses.
  def shared_source(dashboard, panel)
    return nil unless Grafana::Datasources.dashboard?(panel.datasource)

    id = panel.targets.first&.dig('panelId')
    dashboard.panel(id) || raise(Grafana::Error, "it shows panel #{id}, which is not on the dashboard")
  end

  def text_panel(panel, interpolator)
    content = interpolator.apply(panel.options['content'].to_s)
    content = content.gsub(%r{<br\s*/?>|</p>|</div>|</li>|</h\d>}i, "\n").gsub(/<[^>]+>/, '') if panel.options['mode'] == 'html'
    Grafana::Visual::Text.new(text: content.strip, level: :text, notes: [])
  end

  def library(panel)
    Grafana::Visual::Text.new(
      text:  "#{panel.name} is a library panel, which this board does not read yet.",
      level: :empty,
      notes: []
    )
  end

  def rule(group, json)
    since = Array(json['alerts']).filter_map { |a| a['activeAt'] }.min
    state = json['health'] == 'error' ? 'error' : json['state'].to_s
    state = 'normal' if state == 'inactive'
    Grafana::Visual::Rule.new(
      name:   json['name'].to_s,
      state:  state,
      health: json['health'].to_s,
      group:  group['name'].to_s,
      since:  since ? Grafana::Frame.time(since) : nil
    )
  end

  def datasources = @lists.fetch(:datasources) { Grafana::Datasources.new(ask { @client.get('/api/frontend/settings') }) }

  def runner = Grafana::QueryRunner.new(SlotClient.new(@client, @slots), datasources)

  def resolver = Grafana::VariableResolver.new(SlotClient.new(@client, @slots), datasources, runner)

  def digest(variables) = Digest::SHA1.hexdigest(Marshal.dump(variables.map { |v| [v.name, v.current] }))

  # Runs the block in a slot (at most PARALLEL at once).
  def ask
    slot = @slots.pop
    yield
  ensure
    @slots << slot if slot
  end

  # A Grafana::Client whose questions each take a slot, for the runner and
  # the resolver (whose calls are not inside #ask).
  class SlotClient
    # The +client+ asked through +slots+.
    def initialize(client, slots)
      @client = client
      @slots  = slots
    end

    # Client#get in a slot.
    def get(...) = take { @client.get(...) }

    # Client#post in a slot.
    def post(...) = take { @client.post(...) }

    private

    def take
      slot = @slots.pop
      yield
    ensure
      @slots << slot if slot
    end
  end
end
