# frozen_string_literal: true

# The accounts of the network in numbers (Rubbs::Common::Auth::Directory#statistics),
# written for Prometheus' node-exporter textfile collector as
# data/accounts-metrics.prom; a cron of the server copies it there (a
# container cannot reach the host's textfile directory), as the Discovery
# gauges go. Grafana: VPS: BBS – Users.
class AccountsMetrics
  # Every metric's name starts with it.
  PREFIX = 'ttg_bbs_accounts'

  # Metrics of +accounts+ (a Rubbs::Common::Auth::Directory) into the file +path+.
  def initialize(accounts, path)
    @accounts = accounts
    @path     = path
  end

  # Writes the file anew (a whole file at once: a reader never sees half).
  def write
    temporary = "#{@path}.tmp"
    File.write(temporary, text)
    File.rename(temporary, @path)
  end

  # The metrics as the textfile collector reads them.
  def text(stats = @accounts.statistics)
    [
      *gauge('', 'Accounts of the network (Rubbs::Common::Auth on TTG Gate BBS).', { '' => stats[:accounts] }),
      *gauge('_by_role', 'Accounts with the role.', stats[:roles].transform_keys { |role| %(role="#{role}") }),
      *gauge('_new', 'Accounts made in the window.', { 'window="1d"' => stats[:new_day], 'window="7d"' => stats[:new_week] }),
      *gauge(
        '_seen',
        'Accounts logged in in the window.',
        { 'window="1d"' => stats[:seen_day], 'window="7d"' => stats[:seen_week] }
      )
    ].join("\n") << "\n"
  end

  private

  def gauge(suffix, help, values)
    name = "#{PREFIX}#{suffix}"
    ["# HELP #{name} #{help}", "# TYPE #{name} gauge",
     *values.map { |labels, value| labels.empty? ? "#{name} #{value}" : "#{name}{#{labels}} #{value}" }]
  end
end
