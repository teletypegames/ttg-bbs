# frozen_string_literal: true

module UI
  module Modern
    # The table of contents of the RFC a reader shows: its headings on the
    # left; Enter takes the reader there.
    module ContentsWindow
      extend Rubbs::Modern::Part

      window :contents, :master_detail do
        title      { "Contents of #{rfc.name} (#{headings.size})" }
        height     { rows - 8 }
        list_width { [52, cols - 24].min }
        items      { headings }
        label      { |(_, text)| text }
        empty      'No headings found in this RFC.'
        detail     { |(line, _)| ["line #{line + 1}", '', 'Enter takes the', 'reader there.'] }
        on_pick do |(line, _)|
          close
          reader.jump(line)
        end
      end
    end
  end
end
