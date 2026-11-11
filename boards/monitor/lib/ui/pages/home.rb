# frozen_string_literal: true

module UI
  # The first page: every dashboard Grafana's token sees, under its group
  # (its folder, else the word before the colon of its title: VPS, BBS,
  # GIT …), the chosen one's description and tags under the list. The
  # arrows choose, RETURN opens, / finds by title, tag or group, Q leaves.
  class Home < Screen
    key(:up) { move(-1) }
    key(:down) { move(1) }
    key(:page_up, '-') { move(-list_rows) }
    key(:page_down, '+') { move(list_rows) }
    key(:home) { @index = 0 }
    key(:enter, :right) { open }
    key('/', 'f', 'F') { find }
    key('r', 'R') { reload }
    key(:escape, :left, 'q', 'Q') { quit }

    # The page for the MonitorService +service+.
    def initialize(service)
      super()
      @service = service
      @filter  = ''
      @index   = 0
      reload
    end

    # The header's words.
    def crumb = @filter.empty? ? 'Dashboards' : "Dashboards › /#{@filter}"

    # The header's right.
    def right = "#{entries.size} of #{@all.size}"

    # The hint line.
    def hint = petscii? ? 'crsr  return open  / find  q leave' : '↑↓ choose  RETURN open  / find  R reload  Q leave'

    # The list by group, the chosen one lit, and its description under it.
    def body
      return Paint.wrap(@error, width).map { |l| Paint.run(l, :bad) } if @error
      if entries.empty?
        return Paint.run(@all.empty? ? 'Grafana shows no dashboards to this token.' : 'Nothing matches.', :dim).then { |l|
          [l]
        }
      end

      rows = list_lines
      top  = scroll_top(rows)
      [*rows[top, list_rows], [], *detail]
    end

    private

    def entries
      @entries ||= @all.select do |e|
        key = @filter.downcase
        key.empty? || [e.title, e.group, *e.tags].any? { |w| w.downcase.include?(key) }
      end
    end

    def list_rows = [body_rows - 4, 3].max

    # The rows: a group's name before its first dashboard; [line, entry index].
    def list_lines
      group = nil
      entries.each_with_index.flat_map do |e, i|
        head = e.group == group ? [] : [[Paint.run(e.group.upcase, :accent), nil]]
        group = e.group
        [*head, [entry_line(e, i), i]]
      end
    end

    def entry_line(entry, index)
      lit  = index == @index
      tags = petscii? || entry.tags.empty? ? '' : "  #{entry.tags.join(' · ')}"
      line = [[lit ? '▸ ' : '  ', :accent], [Paint.plain(entry.short_title), lit ? :bright : :text], [tags, :dim]]
      lit ? Paint.lit(Paint.fit(line, width)) : line
    end

    # The first row shown, so the chosen one is in sight.
    def scroll_top(rows)
      at = rows.index { |_, i| i == @index } || 0
      @top ||= 0
      @top = at - list_rows + 1 if at >= @top + list_rows
      @top = [at - 1, 0].max if at < @top
      @top = @top.clamp(0, [rows.size - list_rows, 0].max)
      rows.map!(&:first)
      @top
    end

    def detail
      entry = entries[@index] or return []
      words = entry.description.empty? ? entry.title : entry.description
      Paint.wrap(words, width, 2).map { |l| Paint.run(l, :dim) }
    end

    def move(step)
      return if entries.empty?

      @index = (@index + step).clamp(0, entries.size - 1)
    end

    def open
      entry = entries[@index] or return
      push(Board.new(@service, entry))
    end

    def find
      text = read_line('Find:', text: @filter, max: 30) or return
      @filter  = text.strip
      @entries = nil
      @index   = 0
      @top     = nil
    end

    def reload
      @error   = nil
      @all     = @service.dashboards
      @entries = nil
    rescue Grafana::Error => e
      @all   = []
      @error = e.message
    end
  end
end
