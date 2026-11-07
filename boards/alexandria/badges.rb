# frozen_string_literal: true

# The badges of Alexandria BBS (TTG::Badges): Wikipedia. ArticleService
# reports :article.
Rubbs.badges :alexandria do
  event :article, lang: 'the language', ref: 'the title'

  badge :rabbit_hole do
    title  'Rabbit Hole'
    hint   'Read 25 Wikipedia articles in one call.'
    emblem 'W', :white
    on(:article).count.within(:call).reaches 25
  end

  badge :polyglot do
    title  'Polyglot'
    hint   'Read Wikipedia in three languages.'
    emblem 'P', :lightblue
    on(:article).distinct(:lang).reaches 3
  end
end
