# frozen_string_literal: true

# The accounts of the network in numbers (Rubbs::Common::Auth::Directory#statistics),
# and the feedback and walls the gate keeps for every board (ttg-common
# TTG::Feedback, TTG::Wall), the badges (TTG::Badges) and the sources of the
# Today tab (Herald), written for Prometheus' node-exporter textfile
# collector as data/accounts-metrics.prom; a cron of the server copies it
# there (a container cannot reach the host's textfile directory), as the
# Discovery gauges go. Grafana: BBS: Users, BBS: Messages, BBS: Badges & Today.
class AccountsMetrics
  # Every metric's name starts with it.
  PREFIX = 'ttg_bbs_accounts'

  # Metrics of +accounts+ (a Rubbs::Common::Auth::Directory), of the
  # Central's +services+ (a Hash of path => service, or +nil+ before the
  # Central serves) and of +herald+ (a Herald::Service, or +nil+) into the
  # file +path+.
  def initialize(accounts, path, services: nil, herald: nil)
    @accounts = accounts
    @path     = path
    @services = services
    @herald   = herald
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
      ),
      *messages,
      *badges,
      *today
    ].join("\n") << "\n"
  end

  private

  def messages
    feedback = stats_of('/feedback')
    wall     = stats_of('/wall')
    [*(feedback ? feedback_gauges(feedback) : []), *(wall ? wall_gauges(wall) : [])]
  end

  def badges
    stats = (@services || {})['/badges']&.engine&.statistics
    return [] unless stats

    [*gauge('ttg_bbs_badges_awarded', 'Accounts with the badge and tier.', pairs(stats[:awards], 'badge', 'tier'), prefix: false),
     *gauge('ttg_bbs_badges_accounts', 'Accounts with any badge.', { '' => stats[:accounts] }, prefix: false),
     *gauge(
       'ttg_bbs_badge_events',
       'Events kept for the badges, by event and board.',
       pairs(stats[:events], 'event', 'board'),
       prefix: false
     ),
     *gauge(
       'ttg_bbs_badges_defined',
       'Badges declared, by board.',
       stats[:defined].transform_keys { |b| %(board="#{b}") },
       prefix: false
     )]
  end

  def today
    ages = @herald&.ages or return []

    [*gauge(
      'ttg_bbs_herald_age_seconds',
      'Seconds since the Today tab\'s source came.',
      ages.reject { |_, (age, _)| age.nil? }.to_h { |key, (age, _)| [%(source="#{key}"), age] },
      prefix: false
    ),
     *gauge(
       'ttg_bbs_herald_fresh',
       'Whether the source\'s part of the Today tab is shown (1) or left out (0).',
       ages.to_h { |key, (_, fresh)| [%(source="#{key}"), fresh ? 1 : 0] },
       prefix: false
     )]
  end

  def pairs(counts, first, second)
    counts.to_h { |(a, b), n| [%(#{first}="#{a}",#{second}="#{b}"), n] }
  end

  def stats_of(path)
    service = (@services || {})[path]
    service&.store&.statistics
  end

  def feedback_gauges(stats)
    states = TTG::Feedback::Store::STATES.to_h { |state| [%(state="#{state}"), stats[:states].fetch(state, 0)] }
    boards = stats[:boards].to_h { |(board, kind), count| [%(board="#{board}",kind="#{kind}"), count] }
    [*gauge('ttg_bbs_feedback', 'Feedback of the network on TTG Gate BBS, by state.', states, prefix: false),
     *gauge(
       'ttg_bbs_feedback_by_board',
       'Feedback of the network, by the board it came from and its kind.',
       boards,
       prefix: false
     )]
  end

  def wall_gauges(stats)
    notes = stats[:notes].to_h { |(board, guest), count| [%(board="#{board}",writer="#{guest ? 'guest' : 'account'}"), count] }
    [*gauge('ttg_bbs_wall_notes', 'Visible notes on the walls of the boards, by board and who wrote them.', notes, prefix: false),
     *gauge('ttg_bbs_wall_hidden', 'Notes the sysops hid or the writers took back.', { '' => stats[:hidden] }, prefix: false)]
  end

  def gauge(suffix, help, values, prefix: true)
    name = prefix ? "#{PREFIX}#{suffix}" : suffix
    ["# HELP #{name} #{help}", "# TYPE #{name} gauge",
     *values.map { |labels, value| labels.empty? ? "#{name} #{value}" : "#{name}{#{labels}} #{value}" }]
  end
end
