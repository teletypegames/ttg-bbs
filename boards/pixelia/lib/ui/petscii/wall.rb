# frozen_string_literal: true

module UI
  class Petscii < BBS::Petscii::Face
    # The Wall on a C64: the works newest first as a numbered cursor list, and a
    # work on the whole screen, as it was painted (CRSR down shows its last
    # row).
    module Wall
      private

      def wall_list
        loop do
          works = wall.all
          work = pick('THE WALL', works, empty: 'nothing on the wall yet: paint on the canvas and save it.',
                                         right: "#{works.size} works") { |w| "#{w.title} #{GR}#{w.handle}#{LG}" }
          break unless work

          show_work(work)
        end
      end

      def show_work(work)
        view   = CanvasView.new(session)
        canvas = work.canvas
        loop do
          view.sync(canvas)
          view.status([[" #{work.title[0, 18]}", 1], [" #{work.handle[0, 10]}", 3], [' ret', 7]])
          view.place(0, view.offset)
          case key
          when :down then view.follow?(CanvasModel::ROWS - 1)
          when :up then view.follow?(0)
          else return
          end
        end
      end
    end
  end
end
