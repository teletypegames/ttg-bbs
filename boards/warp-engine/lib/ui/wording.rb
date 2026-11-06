# frozen_string_literal: true

module UI
  # What both faces tell the caller about a download that cannot go.
  module Wording
    NO_ANSWER = 'The archive did not answer. Try again later.'

    # Why a fetch gave no bytes (CatalogService#fetch).
    def self.refusal(reason, title)
      case reason
      when :too_big then "#{title.file} is too big for a download on this line."
      when :changed then "#{title.file} has just been updated on the archive. Read the shelf again and pick it anew."
      else NO_ANSWER
      end
    end
  end
end
