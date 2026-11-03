# frozen_string_literal: true

module UI
  module Modern
    # The text-art files of a pack on the left, the SAUCE facts of the one
    # picked on the right.
    module FilesWindow
      extend BBS::Part

      window :files, :master_detail do
        title      { pack.name }
        list_width { [24, cols / 3].max }
        items      { files }
        label      :name
        empty      'No text art in this pack.'
        detail     { |f| [bright(f.name), accent(f.credits), '', *file_facts(f), '', dim(gallery.file_url(f))] }
        meta       { 'Enter shows it' }
        on_pick    { |f| view_piece(f) }
        height(-6)
        action('View') { |f| view_piece(f) }
      end

      helpers do
        def file_facts(file)
          [['Title', file.title], ['Author', file.author], ['Group', file.group], ['Artists', file.artists.join(', ')],
           ['Date', file.date], ['Width', file.width&.to_s], ['Colours', file.ice? ? 'iCE (16 backgrounds)' : nil]]
            .reject { |_, v| v.to_s.empty? }.map { |k, v| "#{paint(:label, k.ljust(8))}#{v}" }
        end
      end
    end
  end
end
