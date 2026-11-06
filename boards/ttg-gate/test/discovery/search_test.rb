# frozen_string_literal: true

require_relative 'test_helper'

module Discovery
  class SearchTest < Minitest::Test
    VOCABULARY = %w[cc:hu cc:us sw:synchronet net:fidonet src:sbl petscii].freeze

    def parse(text) = SearchQuery.parse(text, VOCABULARY)

    def test_tag_words_are_tags_and_the_rest_free_text
      q = parse('petscii hu online')
      assert_equal %w[petscii cc:hu online], q.tags
      assert_empty q.words
      refute q.all?
      q = parse('Synchronet FidoNet amiga lounge')
      assert_equal %w[sw:synchronet net:fidonet], q.tags
      assert_equal %w[amiga lounge], q.words
      assert_equal '"amiga"* "lounge"*', q.match
    end

    def test_fixed_tags_and_prefixed_tags_need_no_board
      assert_equal %w[atascii veteran cc:zz], parse('atascii veteran cc:zz').tags
      assert_equal %w[de], parse('de').words
    end

    def test_all_and_dead_let_the_dead_in
      q = parse('all mystic')
      assert q.all?
      assert_equal %w[mystic], q.words
      assert parse('dead').all?
      refute parse('').all?
      assert parse('').empty?
    end

    def test_punctuation_and_quotes_do_not_reach_fts
      q = parse(%(a"b* (c) ---))
      assert_equal %w[ab c], q.words
      assert_equal '"ab"* "c"*', q.match
      assert_nil parse('online').match
    end

    def test_the_filter_of_a_query_leaves_mailers_out_unless_asked
      refute ListingFilter.search(parse('online')).mailers
      assert ListingFilter.search(parse('sw:ftn-mailer')).mailers
      assert ListingFilter.new(state: 'dead').dead
    end
  end
end
