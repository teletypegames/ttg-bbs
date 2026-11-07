# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../lib/ui/petscii'

# The YOU tab on a C64: the gate's own profile in its frame; a guest logs in
# with the password shown as stars, an account logs out, the places of the
# profile are numbered in it.
class PetsciiProfileTest < Minitest::Test
  Canvas = Rubbs::Petscii::Canvas

  def setup
    @accounts = Rubbs::Test.accounts(roles: ['member'])
    capture_io { @accounts.register('Tasi', 'secret1') }
    UI::Sysop.offer(@accounts)
    @auth = Rubbs.config.auth
    Rubbs.config.auth = Rubbs::Common::Auth::Setup.new(directory: @accounts, login: :menu, guests: true)
  end

  def teardown
    Rubbs::Common::Auth::Profile.clear_extras
    Rubbs.config.auth = @auth
  end

  def board
    BoardModel.new(
      {
        'id'      => 'b0',
        'name'    => 'Board',
        'summary' => 'A board.',
        'tags'    => [],
        'port'    => 2323,
        'accent'  => '#3cff7a',
        'petscii' => true
      },
      host:        'gw',
      public_host: 'teletypegames.org'
    )
  end

  def gate(keys, identity: Rubbs::Common::Auth::Identity.guest)
    @line = Rubbs::Test::Session.new(keys: keys, identity: identity, petscii: true)
    UI::Petscii::Gate.new(@line, boards: [board], browse: nil, dials: nil).tap(&:start)
  end

  def screens = @line.writes.each_with_object([Canvas.new]) { |w, all| all << all.last.dup.feed(w) }

  def shown = screens.last.to_s

  def test_a_guest_logs_in_on_you
    g = gate([*'Tasi'.chars, :enter, *'secret1'.chars, :enter])
    g.press('y')
    assert_equal :account, g.view.section
    assert_includes shown, 'Not logged in.'
    g.press(:enter)
    assert_equal 'Tasi', @line.identity.name
    assert(screens.any? { |s| s.to_s.include?('Password: *******') })
    refute(screens.any? { |s| s.to_s.include?('secret1') })
    assert_includes shown, 'Welcome, Tasi.'
    assert_includes shown, 'Change password'
  end

  def test_a_sysop_finds_the_console_and_logs_out
    sysop = Rubbs::Common::Auth::Identity.new(id: 1, name: 'Tasi', roles: %w[member sysop], source: :login)
    g = gate([], identity: sysop)
    g.press('p')
    assert_includes shown, 'SysOp'
    assert_includes shown, 'member sysop'
    g.press('2')
    refute @line.identity.signed_in?
    assert_includes shown, 'You are logged out.'
  end
end
