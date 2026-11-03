# frozen_string_literal: true

module UI
  module Modern
    # The chapters of an open book on the left, the start of the one picked
    # on the right; Enter reads it in the reader.
    module ChaptersWindow
      extend BBS::Part

      window :chapters, :master_detail do
        title      { book.short_title }
        height     { rows - 8 }
        list_width { [40, (cols / 2) - 4].min }
        items      { text.chapters }
        label      { |chapter| "#{chapter.number.to_s.rjust(text.size.to_s.size)}. #{chapter.title}" }
        empty      'No chapters.'
        detail do |chapter|
          size = "Chapter #{chapter.number} of #{text.size} · #{(chapter.length / 1024.0).ceil} KB"
          [bright(chapter.title), accent(size), '', "#{reading.preview(text, chapter.number)}…", '', dim('Enter reads it.')]
        end
        meta       { "eBook ##{book.id} from Project Gutenberg · #{book.url}" }
        on_pick    { |chapter| read(book, text, chapter.number) }
        action('Read') { |chapter| read(book, text, chapter.number) }
        action('QR code') { show_qr(book) }
      end
    end
  end
end
