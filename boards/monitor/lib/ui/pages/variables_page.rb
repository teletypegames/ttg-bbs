# frozen_string_literal: true

module UI
  # The variables of a dashboard a caller can set, each with what is chosen
  # now. RETURN on one types its words (a text box) or opens its options
  # (OptionsPage); the dashboard loads again with each change. Q goes back.
  class VariablesPage < Screen
    key(:up) { @index = (@index - 1).clamp(0, [list.size - 1, 0].max) }
    key(:down) { @index = (@index + 1).clamp(0, [list.size - 1, 0].max) }
    key(:enter, :right) { choose }
    key(:escape, :left, 'q', 'Q') { back }

    # The variables of +board+ (a UI::Board).
    def initialize(board)
      super()
      @board = board
      @index = 0
    end

    # The header's words.
    def crumb = "#{@board.crumb.split(' › ').last} › Variables"

    # The hint line.
    def hint = petscii? ? 'crsr  return set  q back' : '↑↓ choose  RETURN set  Q back'

    # A line a variable.
    def body
      list.each_with_index.map do |v, i|
        line = [[i == @index ? '▸ ' : '  ', :accent], [Paint.plain(v.label).ljust(18)[0, 18], :text], [' ', :text],
                [Paint.plain(v.shown), :bright]]
        i == @index ? Paint.lit(Paint.fit(line, width)) : line
      end
    end

    # Sets the variable +name+ to +values+ and loads the dashboard again.
    def set(name, values)
      @board.variables = @board.variables.map { |v| v.name == name ? v.choose(values) : v }
    end

    private

    def list = @board.editable

    def choose
      variable = list[@index] or return
      return push(OptionsPage.new(self, variable)) unless variable.typed?

      text = read_line("#{variable.label}:", text: variable.current.first.to_s, max: 200) or return
      set(variable.name, [text])
    end
  end

  # The options of a variable: All first when it has it. RETURN takes the
  # lit one; for a variable of several values SPACE marks and unmarks, and
  # RETURN takes the marked ones (or the lit one when none is marked). /
  # finds among them.
  class OptionsPage < Screen
    key(:up) { move(-1) }
    key(:down) { move(1) }
    key(:page_up, '-') { move(-(body_rows - 1)) }
    key(:page_down, '+') { move(body_rows - 1) }
    key(' ') { mark }
    key(:enter) { take }
    key('/') { find }
    key(:escape, :left, 'q', 'Q') { back }

    # The options of +variable+, set through +page+ (a VariablesPage).
    def initialize(page, variable)
      super()
      @page     = page
      @variable = variable
      @marked   = variable.multi && !variable.all? ? variable.current.dup : []
      @index    = 0
      @filter   = ''
    end

    # The header's words.
    def crumb = "#{@variable.label}#{" › /#{@filter}" unless @filter.empty?}"

    # The header's right.
    def right = @variable.multi ? "#{@marked.size} marked" : ''

    # The hint line.
    def hint
      many = if @variable.multi
               petscii? ? '  spc mark' : '  SPACE mark'
             else
               ''
             end
      petscii? ? "crsr  return take#{many}  / find  q back" : "↑↓ choose  RETURN take#{many}  / find  Q back"
    end

    # A line an option, the lit one and the marked ones shown.
    def body
      shown = options
      top = (@index - body_rows + 1).clamp(0, [shown.size - body_rows, 0].max)
      shown[top, body_rows].each_with_index.map do |option, i|
        at   = top + i
        mark = @marked.include?(option.value) ? '■ ' : '  '
        line = [[at == @index ? '▸' : ' ', :accent], [mark, :good], [Paint.plain(option.text), at == @index ? :bright : :text]]
        at == @index ? Paint.lit(Paint.fit(line, width)) : line
      end
    end

    private

    def options
      all = @variable.include_all ? [Grafana::Option.new(text: 'All', value: Grafana::Variable::ALL)] : []
      list = all + @variable.options
      @filter.empty? ? list : list.select { |o| o.text.downcase.include?(@filter.downcase) }
    end

    def move(step) = @index = (@index + step).clamp(0, [options.size - 1, 0].max)

    def mark
      option = options[@index] or return
      return take unless @variable.multi

      @marked = @marked.include?(option.value) ? @marked - [option.value] : @marked + [option.value]
      move(1)
    end

    def take
      option = options[@index]
      values = @variable.multi && @marked.any? ? @marked : [option&.value].compact
      return if values.empty?

      @page.set(@variable.name, values)
      back
    end

    def find
      text = read_line('Find:', text: @filter, max: 30) or return
      @filter = text.strip
      @index  = 0
    end
  end
end
