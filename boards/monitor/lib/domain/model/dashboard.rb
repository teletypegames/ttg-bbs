# frozen_string_literal: true

module Grafana
  # One panel of a dashboard, as its JSON says: what it is (+type+), its
  # title and description, its queries (+targets+) and their data source,
  # how its fields look (+field_config+), its +options+ and
  # +transformations+, and the +section+ (row) it is in.
  Panel = Data.define(
    :id,
    :type,
    :title,
    :description,
    :datasource,
    :targets,
    :field_config,
    :options,
    :transformations,
    :max_data_points,
    :interval,
    :section,
    :raw
  ) do
    # A panel of the JSON +hash+ under +section+ (a row's title, or +nil+).
    def self.of(hash, section)
      new(
        id:              hash['id'],
        type:            hash['type'].to_s,
        title:           hash['title'].to_s.strip,
        description:     hash['description'].to_s.strip,
        datasource:      hash['datasource'],
        targets:         Array(hash['targets']).grep(Hash),
        field_config:    hash['fieldConfig'].is_a?(Hash) ? hash['fieldConfig'] : {},
        options:         hash['options'].is_a?(Hash) ? hash['options'] : {},
        transformations: Array(hash['transformations']).select { |t| t.is_a?(Hash) && !t['disabled'] },
        max_data_points: hash['maxDataPoints'],
        interval:        hash['interval'],
        section:         section,
        raw:             hash
      )
    end

    # The title, or the type's name when it has none.
    def name = title.empty? ? "(#{type})" : title

    # The queries that run (not hidden).
    def queries = targets.reject { |t| t['hide'] }

    # A library panel, whose model this dashboard does not hold.
    def library? = raw.key?('libraryPanel') && targets.empty?
  end

  # A section of a dashboard: a row's title (+nil+ for the panels before the
  # first row) and its panels in reading order.
  Section = Data.define(:title, :panels)

  # A dashboard of Grafana: its +uid+, +title+, +description+, +tags+, the
  # +time+ it looks at by default, its +refresh+ (seconds, or +nil+), its
  # template +variables+ (Variable) and its panels in +sections+.
  Dashboard = Data.define(:uid, :title, :description, :tags, :time, :refresh, :variables, :sections, :folder) do
    # A dashboard of the answer of <tt>/api/dashboards/uid/<uid></tt>.
    def self.of(answer)
      json = answer.fetch('dashboard', {})
      raise Error, 'this dashboard is in a schema the board does not read yet (v2)' if json.key?('elements')

      new(
        uid:         json['uid'].to_s,
        title:       json['title'].to_s,
        description: json['description'].to_s,
        tags:        Array(json['tags']).map(&:to_s),
        time:        TimeRange.of(json['time']),
        refresh:     Dashboard.seconds(json['refresh']),
        variables:   Array(json.dig('templating', 'list')).filter_map { |v| Variable.of(v) },
        sections:    Dashboard.sections(Array(json['panels'])),
        folder:      answer.dig('meta', 'folderTitle').to_s
      )
    end

    # Every panel, section after section.
    def panels = sections.flat_map(&:panels)

    # The panel of +id+, or +nil+.
    def panel(id) = panels.find { |p| p.id == id }

    # The seconds of a refresh like <tt>30s</tt>, <tt>5m</tt>; +nil+ for none.
    def self.seconds(text)
      match = text.to_s.match(/\A(\d+)([smhd])\z/) or return nil
      match[1].to_i * TimeRange::UNITS.fetch(match[2])
    end

    # The +panels+ of a dashboard's JSON in sections: a row starts one; a
    # collapsed row holds its panels, an open one is followed by them.
    # Panels are read top to bottom, left to right.
    def self.sections(panels)
      sections = [[nil, []]]
      ordered(panels).each do |hash|
        next sections.last[1] << Panel.of(hash, sections.last[0]) unless hash['type'] == 'row'

        title = hash['title'].to_s.strip
        sections << [title, ordered(Array(hash['panels'])).map { |inner| Panel.of(inner, title) }]
      end
      sections.reject { |_, list| list.empty? }.map { |title, list| Section.new(title: title, panels: list) }
    end

    # +panels+ by their place on the grid.
    def self.ordered(panels)
      panels.grep(Hash).sort_by.with_index do |p, i|
        grid = p['gridPos'].is_a?(Hash) ? p['gridPos'] : {}
        [grid['y'].to_i, grid['x'].to_i, i]
      end
    end
  end

  # A dashboard on the list of the search: +uid+, +title+, +tags+, the
  # +folder+'s title and the +description+.
  Entry = Data.define(:uid, :title, :tags, :folder, :description) do
    # An entry of one item of <tt>/api/search</tt>.
    def self.of(item)
      new(
        uid:         item['uid'].to_s,
        title:       item['title'].to_s,
        tags:        Array(item['tags']).map(&:to_s),
        folder:      item['folderTitle'].to_s,
        description: item['description'].to_s
      )
    end

    # The group it is listed under: its folder, else the word before a
    # colon of its title (<tt>VPS: Host</tt> is under VPS), else General.
    def group
      return folder unless folder.empty?

      prefix = title[/\A([^:]{1,24}):\s/, 1]
      prefix ? prefix.strip : 'General'
    end

    # The title without the group's prefix.
    def short_title = title.sub(/\A#{Regexp.escape(group)}:\s*/, '')
  end
end
