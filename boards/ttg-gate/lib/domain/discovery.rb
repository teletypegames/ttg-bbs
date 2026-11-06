# frozen_string_literal: true

# Global Discovery: the catalog of the world's telnet BBSes (TTG_DISCOVERY.md).
# The importer and the prober run as their own processes (bin/discovery-*);
# the Gate reads the catalog (BrowseService) and records its dials
# (DialService).
require 'rubbs'
require_relative 'migrations'

%w[
  model/address model/record_model model/probe_result_model model/source_config_model model/listing_filter
  model/search_query model/meta_model model/source_model model/board_model model/board_source_model
  model/probe_model model/board_state_model model/tag_model model/boards_fts_model model/dial_refusal_model
  model/dial_model model/geoip_meta_model model/geoip_v4_model model/geoip_v6_model model/listing_model
  model/board_page_model
  parser/text_decoder parser/nodelist_parser parser/sbl_html_parser parser/syncterm_lst_parser parser/cbbs_json_parser
  parser/tbg_zip_parser parser/parsers
  repository/config_repository repository/optout_repository repository/zip_reader repository/source_fetcher
  repository/geoip_repository
  service/banner_analyzer service/state_rules service/telnet_negotiator service/telnet_probe service/tag_service
  service/alias_service service/import_service service/probe_recorder service/prober_service service/metrics_service
  service/report_service
  service/dial_history_service service/browse_service service/banner_preview service/dial_service
  root
].each { |file| require_relative "discovery/#{file}" }
