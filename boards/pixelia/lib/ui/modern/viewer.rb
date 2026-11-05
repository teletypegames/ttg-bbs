# frozen_string_literal: true

module UI
  module Modern
    # A piece on the whole screen, the way the art viewers of the old boards
    # showed it: centred when it fits, the arrows, PgUp/PgDn and Home/End
    # scroll it, ← and → pan it when the window is narrower than the piece,
    # and a status line at the bottom. Q, Esc or Enter go back. Runs inside
    # Application#with_line.
    class Viewer
      STATUS = "\e[0;30;47m"
      PAN    = 8
      BACK   = ['q', 'Q', :escape, :enter].freeze

      # Shows +height+ rows of +width+ columns; +line+ gives the ANSI line of
      # row y from column x, w cells wide. Returns nil when the caller hung up.
      def self.run(session, width:, height:, title:, &line) = new(session, width, height, title, line).run

      def initialize(session, width, height, title, line)
        @session = session
        @width   = width
        @height  = height
        @title   = title
        @line    = line
        @top     = 0
        @left    = 0
      end

      def run
        loop do
          measure
          @session.write(frame)
          key = @session.readkey
          return nil if key.nil?
          return true if BACK.include?(key)

          scroll(key)
        end
      end

      private

      # The terminal's size now, and the view kept inside the piece.
      def measure
        @cols   = @session.term_cols || 80
        @rows   = @session.term_rows || 24
        @view_h = [@rows - 1, 1].max
        @view_w = [@cols, @width].min
        @top    = @top.clamp(0, [@height - @view_h, 0].max)
        @left   = @left.clamp(0, [@width - @cols, 0].max)
      end

      def scroll(key)
        case key
        when :up        then @top -= 1
        when :down      then @top += 1
        when :page_up   then @top -= @view_h - 1
        when :page_down, ' ' then @top += @view_h - 1
        when :home      then @top = 0
        when :end       then @top = @height
        when :left      then @left -= PAN
        when :right     then @left += PAN
        end
      end

      def frame
        margin = [(@cols - @width) / 2, 0].max
        out = +"\e[?25l"
        @view_h.times do |i|
          y = @top + i
          out << "\e[#{i + 1};1H\e[0m\e[2K"
          out << "\e[#{i + 1};#{margin + 1}H" << @line.call(y, @left, @view_w) if y < @height
        end
        out << "\e[#{@rows};1H#{STATUS}" << status << "\e[0m"
      end

      def status
        parts = [" #{@title}"]
        parts << "#{@top + 1}-#{[@top + @view_h, @height].min}/#{@height}" if @height > @view_h
        parts << "cols #{@left + 1}-#{[@left + @cols, @width].min}/#{@width} ←→" if @width > @cols
        parts << '↑↓ PgUp PgDn' if @height > @view_h
        parts << 'q back '
        Rubbs::Modern::FrameBuffer.clip_ansi(parts.join(' · '), @cols).ljust(@cols)
      end
    end
  end
end
