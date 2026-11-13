# frozen_string_literal: true

require 'yaml'

# The Today tab of the gate (DAILY_HERALD.md): what kind of day it is, the
# weather, the forint, history, earthquakes and the network, on one page.
# The web sources (Herald::Sources) are fetched in the background into a
# small SQLite cache (Herald::Store); a caller's page (Herald::Edition) is
# made from the cache and the Calendar only.
module Herald
  # The board's folder.
  ROOT = File.expand_path('../..', __dir__)
  # The time zone of the day.
  ZONE = 'Europe/Budapest'

  # The table config/herald/<name>.yml.
  def self.config(name) = YAML.safe_load_file(File.join(ROOT, 'config/herald', "#{name}.yml"))

  # +time+ in Budapest.
  def self.local(time) = Rubbs::Common::Season.now(tz: ZONE, at: time).time
end

require_relative 'herald/moon'
require_relative 'herald/calendar'
require_relative 'migrations'
require_relative 'model/herald_model'
require_relative 'herald/store'
require_relative 'herald/sources'
require_relative 'herald/edition'
require_relative 'herald/notes'
require_relative 'herald/service'
