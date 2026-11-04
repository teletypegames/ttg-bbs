# frozen_string_literal: true

require_relative 'test_helper'

module Discovery
  class BrowseTest < Minitest::Test
    include TestHelper

    NOW = 1_800_000_000
    DAY = 86_400

    def setup
      database
      MetaModel.store('started_at', NOW - (60 * DAY))
      @ids = {}
      board('alpha.example.org', 'Alpha BBS', 'online', %w[ansi sw:synchronet cc:us net:fidonet])
      board('beta.example.org', 'Beta Commodore', 'online', %w[petscii cc:hu], software: 'Color 64')
      board('gamma.example.org', 'Gamma Lounge', 'down', %w[ansi petscii cc:hu], last_success_at: NOW - (3 * DAY))
      board('delta.example.org', 'Delta Tomb', 'dead', %w[ascii cc:us], state_since: NOW - (2 * DAY))
      board('old.example.org', 'Old Tomb', 'dead', %w[ascii cc:us], state_since: NOW - (90 * DAY))
      board('mail.example.org', 'Mailer Node', 'online', %w[sw:ftn-mailer cc:us net:fidonet])
      board('fresh.example.org', 'Fresh BBS', 'unknown', %w[ansi], first_seen_at: NOW - (2 * DAY))
      board('hidden.example.org', 'Hidden BBS', 'online', %w[ansi], optout: 'hide')
      alias_id = board('alias.example.org', 'Alpha BBS', 'online', %w[ansi])
      BoardModel.set_alias(alias_id, @ids['alpha.example.org'])
      @browse = BrowseService.new(config, random: Random.new(1))
    end

    def board(host, name, state, tags, software: nil, last_success_at: NOW, state_since: NOW - DAY,
              first_seen_at: NOW - (60 * DAY), optout: nil)
      id = BoardModel.id_for(host, 23, first_seen_at)
      BoardModel.where(id: id).update(name: name, optout: optout, first_seen_at: first_seen_at)
      BoardStateModel.save(id, state: state, software: software, last_success_at: last_success_at,
                             state_since: state_since, first_probe_at: NOW - (60 * DAY))
      TagModel.replace(id, tags + (state == 'unknown' ? [] : [state]))
      BoardsFtsModel.index(id)
      @ids[host] = id
    end

    def names(list) = list.map(&:title)

    def test_the_counts_of_the_c64_sidebar_and_sources
      TagModel.replace(@ids['beta.example.org'], %w[petscii claims:petscii online cc:hu])
      assert_equal({ boards: 7, online: 3, petscii: 2, claimed: 1, shared: 0 }, @browse.stats)
    end

    def test_a_list_puts_online_first_and_leaves_dead_hidden_aliases_and_mailers_out
      assert_equal ['Alpha BBS', 'Beta Commodore', 'Gamma Lounge', 'Fresh BBS'], names(@browse.search(''))
    end

    def test_search_words_tags_and_all
      assert_equal ['Beta Commodore', 'Gamma Lounge'], names(@browse.search('hu'))
      assert_equal ['Beta Commodore'], names(@browse.search('petscii hu online'))
      assert_equal ['Gamma Lounge'], names(@browse.search('loun'))
      assert_equal ['Beta Commodore'], names(@browse.search('color'))
      assert_empty @browse.search('tomb')
      assert_equal ['Delta Tomb', 'Old Tomb'], names(@browse.search('tomb all'))
      assert_equal ['Mailer Node'], names(@browse.search('sw:ftn-mailer'))
      assert_empty @browse.search('nosuchword')
    end

    def test_the_state_filter_and_the_c64
      assert_equal ['Gamma Lounge'], names(@browse.search('', state: 'down'))
      assert_equal ['Beta Commodore', 'Gamma Lounge'], names(@browse.search('', petscii: true))
      assert_equal ['Beta Commodore'], names(@browse.search('online', petscii: true))
    end

    def test_facets_count_the_default_list
      assert_equal([%w[cc:hu HU 2], %w[cc:us US 1]], @browse.facets(:country).map { |f| [f.tag, f.label, f.count.to_s] })
      assert_equal [['sw:synchronet', 'Synchronet', 1]], @browse.facets(:software).map(&:deconstruct)
      assert_equal %w[ansi petscii], @browse.facets(:terminal).map(&:tag)
      assert_equal([['cc:hu', 2]], @browse.facets(:country, petscii: true).map { |f| [f.tag, f.count] })
      refute @browse.axes(petscii: true).key?(:terminal)
      assert_equal ['Beta Commodore', 'Gamma Lounge'], names(@browse.tagged('cc:hu'))
    end

    def test_new_random_recently_died_and_graveyard
      assert_equal ['Fresh BBS'], names(@browse.new_this_week(now: NOW))
      assert_equal 'online', @browse.random.state
      assert_equal ['Beta Commodore'], [@browse.random(petscii: true).title]
      assert_equal ['Delta Tomb'], names(@browse.recently_died(now: NOW))
      assert_equal ['Delta Tomb', 'Old Tomb'], names(@browse.graveyard)
    end

    def test_marks_and_status
      list = @browse.search('all').to_h { |l| [l.title, l] }
      assert_equal({ 'Alpha BBS' => '●', 'Gamma Lounge' => '✗', 'Delta Tomb' => '†', 'Fresh BBS' => '?' },
                   list.slice('Alpha BBS', 'Gamma Lounge', 'Delta Tomb', 'Fresh BBS').transform_values(&:mark))
      assert_equal 'down for 3 days', list['Gamma Lounge'].status(NOW)
      assert_equal 'no answer for 5 hours', list['Delta Tomb'].status(NOW + (5 * 3600))
      assert_equal 'not called yet', list['Fresh BBS'].status(NOW)
      assert list['Beta Commodore'].petscii_only?
      refute list['Gamma Lounge'].petscii_only?
      assert_equal '◐', ListingModel.from(id: 1, state: 'flaky').mark
    end

    def test_a_page_has_the_fields_the_strip_and_hides_an_opted_out_banner
      id = @ids['beta.example.org']
      BoardStateModel.save(id, banner: "\x93HELLO".b, encoding: 'petscii', country: 'hu')
      [[NOW - (29 * DAY), 'timeout'], [NOW - (2 * DAY), 'ok'], [NOW - (2 * DAY) + 60, 'refused'], [NOW, 'refused']]
        .each { |at, r| ProbeModel.add(id, probe(r, at: at), kind: 'scheduled', banner_hash: nil) }
      page = @browse.page(id, now: NOW)
      assert_equal "·#{' ' * 26}█ ·", page.strip(NOW, utc_offset: 0)
      assert_equal "\x93HELLO".b, page.banner
      assert_equal([['Name', 'Beta Commodore'], ['Software', 'Color 64'], %w[Country HU], %w[Encoding petscii]],
                   page.fields.map { |f| [f.label, f.value] })
      assert_equal 'DB-IP', page.fields.find { |f| f.label == 'Country' }.source
      BoardModel.set_optout(id, 'no_preview')
      assert_nil @browse.page(id, now: NOW).banner
      assert_nil @browse.page(@ids['hidden.example.org'])
    end
  end
end
