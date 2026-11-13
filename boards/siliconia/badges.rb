# frozen_string_literal: true

# The badges of Siliconia BBS (TTG::Badges): CatalogService reports :machine (a machine's page
# opened; The Hunt can send callers there), CollectionService :mark, MemoryService :memory.
Rubbs.badges :siliconia do
  event :machine, ref: 'the machine', title: 'its name'
  event :mark, ref: 'the machine'
  event :memory, ref: 'the machine'

  badge :curator do
    title  'Curator'
    hint   'Open the pages of machines in Siliconia BBS: 10, 50, 200.'
    emblem 'S', :lightgreen
    on(:machine).distinct(:ref).tiers bronze: 10, silver: 50, gold: 200
  end

  badge :collector do
    title  'Collector'
    hint   'Mark the machines you had in Siliconia BBS: 1, 5, 20.'
    emblem 'C', :cyan
    on(:mark).distinct(:ref).tiers bronze: 1, silver: 5, gold: 20
  end

  badge :nostalgic do
    title  'Nostalgic'
    hint   'Write memories of machines in Siliconia BBS: 1, 5.'
    emblem 'N', :yellow
    on(:memory).distinct(:ref).tiers bronze: 1, silver: 5
  end
end
