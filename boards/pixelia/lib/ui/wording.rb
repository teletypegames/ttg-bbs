# frozen_string_literal: true

module UI
  # What a caller is told after saving the canvas to the Exhibition or
  # uploading a picture to it, on either face.
  module Wording
    # What a guest is told: a work goes under the caller's account.
    ACCOUNT = 'A work goes on the Exhibition under your name: log in or make an account first (your profile).'
    # What a caller is told before an upload.
    UPLOAD = 'A picture of TTG Canvas 64 (a .tcv file, hires, either ROM character set) goes on the Exhibition ' \
             'as it is: its characters, colours, background and border, under a title and your name.'
    # What the board asks the terminal to send (Rubbs::Common::Files::Transfer.upload_start).
    UPLOAD_WHAT = 'your .tcv picture'
    # Why an upload is not taken, by ExhibitionService::Refusal#reason.
    REFUSALS = {
      game_graphics: 'That is game graphics: a multicolour picture or a custom character set, which a terminal ' \
                     'cannot show. The Exhibition takes hires pictures in a ROM character set.',
      blank:         'The picture is empty: paint something first.'
    }.freeze

    def self.result(result)
      case result
      when WorkModel then "On the Exhibition: \"#{result.title}\" by #{result.handle}."
      when :no_title then 'A work needs a title.'
      when :no_handle then 'A work needs a handle.'
      when :blank_canvas then 'The canvas is empty: paint something first.'
      when :too_soon then 'One work every few minutes: try again a little later.'
      else 'The Exhibition could not keep it. Try again later.'
      end
    end

    def self.wait(seconds) = "One work every few minutes: try again in #{seconds} seconds."

    # The words of an ExhibitionService::Refusal.
    def self.refusal(refusal)
      REFUSALS.fetch(refusal.reason) { "That is not a picture the Exhibition can read: #{refusal.detail}." }
    end

    # What a caller is told about a picture that came in, before its title.
    def self.arrived(picture)
      "The picture came in: #{picture.charset} case set, background #{ColorModel[picture.background].name}, " \
        "border #{ColorModel[picture.border].name}."
    end
  end
end
