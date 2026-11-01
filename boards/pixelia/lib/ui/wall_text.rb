# frozen_string_literal: true

module UI
  # What a caller is told after saving the canvas to the Wall, on either face.
  module WallText
    def self.result(result)
      case result
      when WorkModel then "Saved to the Wall: \"#{result.title}\" by #{result.handle}."
      when :no_title then 'A work needs a title.'
      when :no_handle then 'A work needs a handle.'
      when :blank_canvas then 'The canvas is empty: paint something first.'
      when :too_soon then 'One save every few minutes: try again a little later.'
      else 'The Wall could not keep it. Try again later.'
      end
    end

    def self.wait(seconds) = "One save every few minutes: try again in #{seconds} seconds."
  end
end
