# frozen_string_literal: true

# The badges of HackerCave BBS (TTG::Badges): the RFCs, the IENs and the
# Jargon File. ReadingService and JargonService report :read.
Rubbs.badges :hackercave do
  event :read, kind: 'rfc, ien or jargon', ref: 'the number or the entry'

  badge :rfc_reader do
    title  'RFC Reader'
    hint   'Read RFCs in HackerCave BBS: 10, 50, 250.'
    emblem '§', :lightgreen
    on(:read, kind: 'rfc').distinct(:ref).tiers bronze: 10, silver: 50, gold: 250
  end

  badge :ien_digger do
    title  'IEN Digger'
    hint   'Read five Internet Experiment Notes.'
    emblem 'I', :green
    on(:read, kind: 'ien').distinct(:ref).reaches 5
  end

  badge :jargon_watcher do
    title  'Jargon Watcher'
    hint   'Read entries of the Jargon File: 10, 100.'
    emblem 'J', :cyan
    on(:read, kind: 'jargon').distinct(:ref).tiers bronze: 10, silver: 100
  end

  badge :avian_carrier, secret: true do
    title  'Avian Carrier'
    hint   'Read the RFC about IP over pigeons.'
    emblem 'V', :white
    on(:read, kind: 'rfc', ref: '1149').once
  end

  badge :wizard, secret: true do
    title  'Wizard'
    hint   'Read twenty Jargon File entries in one call at night.'
    emblem '*', :purple
    on(:read, kind: 'jargon', time_of_day: :night).count.within(:call).reaches 20
  end
end
