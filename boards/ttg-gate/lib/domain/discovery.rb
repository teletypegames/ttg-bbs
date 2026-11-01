# frozen_string_literal: true

# Global Discovery: the catalog of the world's telnet BBSes (TTG_DISCOVERY.md).
# The importer and the prober run as their own processes (bin/discovery-*);
# the Gate does not read the catalog yet.
%w[
  model/address model/record_model model/probe_result_model model/board_state_model model/source_model
  parser/text_decoder parser/nodelist_parser parser/sbl_html_parser parser/syncterm_lst_parser parser/parsers
  repository/database repository/catalog_repository repository/probe_repository repository/config_repository
  repository/optout_repository repository/zip_reader repository/source_fetcher repository/geoip_repository
  service/banner_analyzer service/state_rules service/telnet_negotiator service/telnet_probe service/tag_service
  service/alias_service service/import_service service/prober_service service/metrics_service service/report_service
  root
].each { |file| require_relative "discovery/#{file}" }
