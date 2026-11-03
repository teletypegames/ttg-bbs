# frozen_string_literal: true

module UI
  module Modern
    # The publishers and developers by their first letter.
    module LettersWindow
      extend BBS::Part

      window :letters, :master_detail do
        title 'Publishers & developers'
        height(-6)
        list_width 20
        items      { catalog.letters }
        label      { |(letter, count)| "#{letter.upcase}  (#{count})" }
        detail     { |(letter, _count)| [bright(letter.upcase), '', catalog.companies(letter).map(&:first).join(' · ')] }
        meta       { 'Enter lists the companies' }
        on_pick    { |(letter, _count)| open_letter(letter) }
      end
    end
  end
end
