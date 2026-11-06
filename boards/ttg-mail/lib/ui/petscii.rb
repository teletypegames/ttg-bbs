# frozen_string_literal: true

require_relative 'logo'

module UI
  # The board on a Commodore 64: PETSCII on a 40×25 screen, a cursor menu, a list of the notices
  # and a page a notice.
  class Petscii < Rubbs::Petscii::Face
    LOGO_COLORS = [LB, LB, CY, CY, WH].freeze

    title 'TTG MAIL BBS'

    masthead do
      gap
      art Logo.petscii(LOGO_COLORS)
      gap
    end

    main_menu do
      item('n', 'notices', -> { "#{notices.all.size} to read" }) { notice_list }
      log_off
    end

    private

    def notice_list
      each_pick('NOTICES', notices.all, label: :title) do |notice|
        page(notice.title.upcase, wrap(notice.body).map { |l| " #{l}" })
      end
    end
  end
end
