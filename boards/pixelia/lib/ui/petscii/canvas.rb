# frozen_string_literal: true

module UI
  class Petscii < Rubbs::Petscii::Face
    # The shared canvas on a C64. The cursor keys move, a typed character
    # paints itself in the ink (or its glyph in glyph mode), DEL rubs out
    # the cell on the left. F3 and F4 step the ink, F5 turns reverse on and
    # off, F6 glyph mode; RETURN (or RUN/STOP, ←) opens the command line:
    # ink, reverse, glyphs, save to the Wall, help, quit. F1 and F7 stay
    # free: UltimateTerm keeps them.
    #
    # What others paint shows up after every key and every POLL seconds,
    # cell by cell.
    class Canvas
      POLL = 3
      HEX  = '0123456789abcdef'

      HELP = [
        " #{WH}one canvas, everyone paints on it.#{LG} 40×25, the c64's own screen: it looks the same here and on " \
        'a modern terminal.', '',
        " #{YE}crsr#{LG} move  #{YE}home#{LG} top left", " #{YE}a key#{LG} paints it in the ink", " #{YE}del#{LG} rubs out",
        " #{YE}f3/f4#{LG} ink  #{YE}f5#{LG} reverse  #{YE}f6#{LG} glyphs", " #{YE}return#{LG} commands: ink, save …", '',
        ' Reverse paints black on the ink: a space is a solid block of colour.', '',
        " #{WH}glyph mode#{LG} (f6): the letters paint graphics, shaped like the keyboard:",
        *GlyphKeys.legend(6).map { |l| "  #{CY}#{l}#{LG}" }, '',
        " #{GR}Save to the wall keeps the canvas as it is now under a title and your handle.#{LG}"
      ].freeze

      # The canvas for the caller of +face+ (the UI::Petscii of the call).
      def initialize(face)
        @face    = face
        @canvas  = face.canvas
        @wall    = face.wall
        @who     = face.session.session_id
        @caller  = face.caller_key
        @view    = CanvasView.new(face.session)
        @x       = 0
        @y       = 0
        @ink     = 1
        @rvs     = false
        @glyphs  = false
        @message = nil
      end

      def run
        @canvas.touch(@who)
        refresh(full: true)
        loop do
          k = @face.key(timeout: POLL)
          @message = nil unless k == :idle
          return if key(k) == :quit

          refresh
        end
      ensure
        @canvas.leave(@who)
      end

      private

      # Does what the key +k+ asks; :quit leaves the canvas.
      def key(k)
        case k
        when :up, :down, :left, :right, :home then move(k)
        when :backspace then rub_out
        when :f3 then @ink = (@ink + 1) % ColorModel.count
        when :f4 then @ink = (@ink - 1) % ColorModel.count
        when :f5 then @rvs = !@rvs
        when :f6 then @glyphs = !@glyphs
        when :enter, :escape then command
        when String then paint(k)
        end
      end

      def refresh(full: false)
        @canvas.touch(@who)
        snapshot = @canvas.snapshot
        full ? @view.redraw(snapshot) : @view.sync(snapshot)
        @view.status(@message || status_runs)
        @view.place(@x, @y)
      end

      def status_runs
        [[' ', nil], [' ', @ink, true], [@rvs ? ' rvs' : ' ink', 15],
         [@glyphs ? ' gfx' : ' txt', @glyphs ? 7 : 15],
         [" #{@canvas.painters} painting", 3], ['  return: menu', 11]]
      end

      def move(key)
        case key
        when :up    then @y -= 1
        when :down  then @y += 1
        when :left  then @x -= 1
        when :right then @x += 1
        when :home  then @x = @y = 0
        end
        @x = @x.clamp(0, CanvasModel::COLS - 1)
        @y = @y.clamp(0, CanvasModel::ROWS - 1)
        @view.follow?(@y)
        nil
      end

      def paint(key)
        char = @glyphs ? GlyphKeys.glyph(key) : key
        result = @canvas.paint(@who, @x, @y, char, @ink, reverse: @rvs)
        case result
        when :ok then @x = [@x + 1, CanvasModel::COLS - 1].min
        when :too_fast then flash('slow down: 20 cells a second', 10)
        when :bad_glyph then flash('the canvas has no such glyph', 10)
        end
      end

      def rub_out
        @x -= 1 if @x.positive?
        flash('slow down: 20 cells a second', 10) if @canvas.erase(@who, @x, @y) == :too_fast
      end

      def flash(text, color) = (@message = [[" #{text}", color]])

      # The command line on the status row; :quit leaves the canvas.
      def command
        @view.status([[' i', 7], ['nk ', 15], ['r', 7], ['vs ', 15], ['g', 7], ['lyphs ', 15], ['s', 7], ['ave ', 15],
                      ['h', 7], ['elp ', 15], ['q', 7], ['uit', 15]])
        case @face.key
        when 'i', 'I' then pick_ink
        when 'r', 'R' then @rvs = !@rvs
        when 'g', 'G' then @glyphs = !@glyphs
        when 's', 'S' then save
        when 'h', 'H' then help
        when 'q', 'Q' then return :quit
        end
        nil
      end

      def pick_ink
        swatches = HEX.chars.each_with_index.map do |c, i|
          i.zero? ? [c, 11] : [c, i, true]
        end
        @view.status([[' ink ', 15], *swatches, [' ? ', 15]])
        k = @face.key
        index = k.is_a?(String) ? HEX.index(k.downcase) : nil
        @ink = index if index
      end

      def help
        @face.page('THE CANVAS', HELP)
        @view.forget!
      end

      def save
        @face.title('SAVE TO THE WALL')
        wait = @wall.wait(@caller)
        wait.positive? ? @face.alert(Wording.wait(wait)) : ask_and_save
        @view.forget!
      end

      def ask_and_save
        @face.puts
        @face.say('The canvas as it is now goes on the wall under a title and your handle.', color: GR)
        @face.puts
        title  = Rubbs::Common::Screens::Field.ask(@face.session, " #{WH}title#{LG}  ", max: WallService::MAX_TITLE)
        handle = title && Rubbs::Common::Screens::Field.ask(@face.session, " #{WH}handle#{LG} ", text: @handle.to_s, max: WallService::MAX_HANDLE)
        return unless title && handle

        @handle = handle
        @face.puts
        @face.say(Wording.result(@wall.save(@caller, title: title, handle: handle)), color: WH)
        @face.pause
      end
    end
  end
end
