# frozen_string_literal: true

# The badges of WarpEngine BBS (TTG::Badges): the C64 and Plus/4 shelves.
# CatalogService reports :download.
Rubbs.badges :'warp-engine' do
  event :download, ref: 'the title', protocol: 'zmodem or xmodem'

  badge :downloader do
    title  'Downloader'
    hint   'Download games from WarpEngine BBS: 1, 10.'
    emblem '↓', :lightgreen
    on(:download).distinct(:ref).tiers bronze: 1, silver: 10
  end
end
