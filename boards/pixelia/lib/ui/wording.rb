# frozen_string_literal: true

module UI
  # What a caller is told after saving the canvas to the Exhibition, on either face.
  module Wording
    # What a guest is told: a work goes under the caller's account.
    ACCOUNT = 'A work goes on the Exhibition under your name: log in or make an account first (your profile).'

    def self.result(result)
      case result
      when WorkModel then "Saved to the Exhibition: \"#{result.title}\" by #{result.handle}."
      when :no_title then 'A work needs a title.'
      when :no_handle then 'A work needs a handle.'
      when :blank_canvas then 'The canvas is empty: paint something first.'
      when :too_soon then 'One save every few minutes: try again a little later.'
      else 'The Exhibition could not keep it. Try again later.'
      end
    end

    def self.wait(seconds) = "One save every few minutes: try again in #{seconds} seconds."
  end
end
