# frozen_string_literal: true

module UI
  module Modern
    # The directories: the directory list, a directory's about and address on the right;
    # Enter opens its titles.
    module DirectoriesWindow
      extend Rubbs::Modern::Part

      window :directories, :master_detail do
        title 'Directories'
        empty 'No directories are configured.'
        list_width { [30, cols / 3].max }
        items      { catalog.directories }
        label      :name
        detail     { |directory| [bright(directory.name), '', directory.about, '', dim("#{catalog.url(directory)}/")] }
        meta       { 'Enter opens the directory' }
        on_pick    { |directory| open_directory(directory) }
        height(-8)
        action('Open') { |directory| open_directory(directory) }
        action('&Machine') { |directory| network(TTG::Network.directory_links(directory.id)) }
      end
    end
  end
end
