# frozen_string_literal: true

require_relative 'test_helper'
require 'rubbs/test'

# The pages on a line, with a Grafana that answers from memory.
class UITest < Minitest::Test
  # A MonitorService stand-in: two dashboards, one panel of one series.
  class FakeService
    def dashboards
      [Grafana::Entry.of({ 'uid' => 'h', 'title' => 'VPS: Host', 'tags' => ['vps'] }),
       Grafana::Entry.of({ 'uid' => 'c', 'title' => 'BBS: Calls' })].sort_by(&:group)
    end

    def dashboard(_uid)
      Grafana::Dashboard.of({ 'dashboard' => {
        'uid'    => 'h',
        'title'  => 'VPS: Host',
        'panels' => [{ 'type' => 'stat', 'title' => 'CPU used' }]
      } })
    end

    def variables(_dashboard, variables, _range) = variables

    def visual(*, **)
      value = Grafana::Visual::Value.new(name: 'cpu', number: 0.5, text: '50%', color: [0, 200, 0], fraction: 0.5, spark: [])
      Grafana::Visual::Values.new(values: [value], style: :stat, names: false, notes: [])
    end
  end

  # A flow runner stand-in: the session and what it was told.
  Runner = Struct.new(:session, :said) do
    def line(text, **) = said << text
  end

  def test_the_dashboards_and_a_dashboard
    session = Rubbs::Test::Session.new(cols: 100, rows: 30)
    pages = Rubbs::Common::Screens::Pages.new(session, charset: :lower)
    pages.start(UI::Home.new(FakeService.new))
    assert_includes session.output, 'Host'
    pages.press(:down)
    pages.press(:enter)
    sleep 0.2 until pages.page.loader.done?
    pages.redraw
    assert_includes session.output, 'CPU used'
    assert_includes session.output, '50%'
  end

  def test_the_c64_face
    session = Rubbs::Test::Session.new(petscii: true)
    pages = Rubbs::Common::Screens::Pages.new(session, charset: :lower)
    pages.start(UI::Home.new(FakeService.new))
    refute_empty session.writes
  end

  def test_only_the_grafana_role_comes_in
    guest = Rubbs::Test::Session.new(keys: ['x'])
    runner = Runner.new(guest, [])
    assert_equal :halt, UI::Monitor.call(runner, nil)
    assert_match(/grafana role/, runner.said.first)

    member = Rubbs::Common::Auth::Identity.new(id: 1, name: 'Ada', roles: ['member'], source: :token)
    refute UI::Monitor.allowed?(Rubbs::Test::Session.new(identity: member))
    viewer = Rubbs::Common::Auth::Identity.new(id: 2, name: 'Bob', roles: %w[member grafana], source: :token)
    assert UI::Monitor.allowed?(Rubbs::Test::Session.new(identity: viewer))
  end
end
