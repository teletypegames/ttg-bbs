# frozen_string_literal: true

module UI
  # What both faces say to a caller about the domain's answers.
  module Wording
    # OnelinerService#add's refusals.
    ONELINER = {
      anonymous: 'Call again with a name to write on the wall.',
      too_long:  "At most #{OnelinerService::MAX_LENGTH} characters.",
      too_fast:  "One line every #{OnelinerService::COOLDOWN} seconds, please."
    }.freeze

    # Why AccountService#log_on did not let +name+ in.
    def self.turned_away(name, result)
      case result
      when :look_alike then "#{name} looks too much like a registered name. Call again with another one."
      when :locked     then "Too many wrong passwords for #{name} of late. Call again later."
      else "#{name} is a registered name. Call again, or use another name."
      end
    end
  end
end
