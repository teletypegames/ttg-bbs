# frozen_string_literal: true

module UI
  module Modern
    # A window of paragraphs ([kind, text]: :heading, :text, :pre), wrapped
    # to its width again when it is resized: an erratum list or a chapter of
    # the Jargon File, with where it is from under it. A {word} of a Jargon
    # entry is coloured as a link.
    module TextWindow
      extend Rubbs::Modern::Part

      MAX_WIDTH = 84
      LINK = /\{([^{}]+)\}/

      window :text, :reader do
        title     { heading }
        max_width MAX_WIDTH
        lines     { |width| paragraph_lines(paragraphs, width) }
        where     { credit }
      end

      helpers do
        def paragraph_lines(paragraphs, width)
          paragraphs.each_with_index.flat_map do |(kind, text), i|
            [*('' unless i.zero?), *paragraph(kind, text, width)]
          end
        end

        def paragraph(kind, text, width)
          case kind
          when :heading then Rubbs::Modern::FrameBuffer.wrap_ansi(bright(text), width)
          when :pre then text.split("\n").map { |l| dim(l[0, width]) }
          else Rubbs::Modern::FrameBuffer.wrap_ansi(text.gsub(TextWindow::LINK) { accent(::Regexp.last_match(1)) }, width)
          end
        end
      end
    end
  end
end
