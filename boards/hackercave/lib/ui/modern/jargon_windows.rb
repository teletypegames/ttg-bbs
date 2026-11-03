# frozen_string_literal: true

module UI
  module Modern
    # The windows of the Jargon File: the letters, a list of entries (the
    # entry on the right; Enter opens it), the chapters, and an entry.
    module JargonWindows
      extend BBS::Part

      window :jargon_letters, :master_detail do
        title      'The Jargon Lexicon'
        height     { rows - 8 }
        list_width { [20, (cols / 2) - 4].min }
        items      { letters }
        label      { |(l, _)| l == '0' ? '0-9 and signs' : l }
        detail     { |(_, n)| ["#{n} entries", '', 'Enter lists them.'] }
        on_pick    { |(l, _)| jargon_letter(l) }
      end

      window :jargon_entries, :master_detail do
        title      { heading }
        height     { rows - 8 }
        list_width { [30, (cols / 2) - 4].min }
        items      { entries }
        label      :headword
        empty      'No entries.'
        detail     { |e| ["#{bright(e.headword)} #{dim(e.pron)}", '', e.summary[0, 600], '', dim('Enter reads it.')] }
        meta       { JargonService::CREDIT }
        on_pick    { |e| open_jargon(e) }
        action('Read')  { |e| open_jargon(e) }
        action('Links') { |e| jargon_links(e) }
      end

      window :jargon_sections, :master_detail do
        title      'Jargon File: chapters and appendices'
        height     { rows - 8 }
        list_width { [44, (cols / 2) - 4].min }
        items      { sections }
        label      :title
        detail     { |s| [s.paragraphs.find { |k, _| k == :text }&.last.to_s[0, 400]] }
        on_pick    { |s| open_section(s) }
      end

      window :jargon_entry, :reader do
        title { heading }
        max_width TextWindow::MAX_WIDTH
        lines { |width| paragraph_lines(jargon_paragraphs(entry), width) }
        where { JargonService::CREDIT }
        action('Links')   { jargon_links(entry) }
        action('Ra&ndom') { jargon_random }
      end
    end
  end
end
