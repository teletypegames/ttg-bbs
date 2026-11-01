# frozen_string_literal: true

module Discovery
  # The parser of each format of config/discovery/sources.yml.
  module Parsers
    BY_FORMAT = {
      'nodelist'     => NodelistParser,
      'sbl_html'     => SblHtmlParser,
      'syncterm_lst' => SynctermLstParser,
      'cbbs_json'    => CbbsJsonParser
    }.freeze

    module_function

    # The parser of +format+; raises KeyError for a format without one.
    def for(format) = BY_FORMAT.fetch(format) { raise KeyError, "no parser for the #{format} format" }
  end
end
