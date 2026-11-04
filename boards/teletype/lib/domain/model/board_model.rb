# frozen_string_literal: true

# A message board ("general", "tech"…): its id, as its posts are filed
# under (PostModel), its title and a line about it.
BoardModel = Struct.new(:id, :title, :description)
