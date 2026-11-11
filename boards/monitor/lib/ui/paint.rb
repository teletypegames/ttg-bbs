# frozen_string_literal: true

module UI
  # The words of a screen as runs, drawn the same on either face: a run is
  # <tt>[text, color]</tt> or <tt>[text, color, :lit]</tt> (the chosen row:
  # a dark background on a modern terminal, reversed on a C64), +color+ an
  # RGB triple or a role (+:text+, +:dim+, +:line+, +:accent+, +:bright+,
  # +:good+, +:warn+, +:bad+). A line is an Array of runs. UI::Modern
  # writes a line as ANSI, UI::Petscii on a C64's canvas.
  module Paint
    module_function

    # The columns +line+ takes.
    def width(line) = line.sum { |text, _| text.to_s.length }

    # +line+ cut to +size+ columns (an ellipsis where it was cut) or padded
    # with spaces in the last run's colour.
    def fit(line, size)
      out = []
      left = size
      line.each do |text, color, lit|
        break if left <= 0

        text = text.to_s
        text = "#{text[0, [left - 1, 0].max]}…" if text.length > left
        out << [text, color, lit].compact
        left -= text.length
      end
      left.positive? ? out << [' ' * left, out.last&.[](1) || :text, line.last&.[](2)].compact : out
    end

    # One run of +text+ in +color+.
    def run(text, color = :text, lit = nil) = [[text.to_s, color, lit].compact]

    # +line+ marked as the chosen row.
    def lit(line) = line.map { |text, color| [text, color, :lit] }

    # +text+ on one line: no control characters, tabs as spaces.
    def plain(text) = Rubbs::Common::Text.clean(text.to_s, keep_newlines: false).tr("\t", ' ')

    # +text+ wrapped to +width+ columns, at most +lines+ lines (the last
    # cut with an ellipsis when more would follow).
    def wrap(text, width, lines = 1000)
      out = text.to_s.split("\n").flat_map do |para|
        words = plain(para).split(/\s+/)
        words.empty? ? [''] : words.each_with_object(['']) { |w, acc| place(acc, w, width) }
      end
      out.size > lines ? [*out.first(lines - 1), "#{out[lines - 1][0, width - 1]}…"] : out
    end

    # Puts +word+ on the last line of +acc+ or a new one.
    def place(acc, word, width)
      word.scan(/.{1,#{[width, 1].max}}/).each do |part|
        if acc.last.empty? then acc[-1] = part
        elsif acc.last.length + 1 + part.length <= width then acc[-1] = "#{acc.last} #{part}"
        else acc << part
        end
      end
    end
  end
end
