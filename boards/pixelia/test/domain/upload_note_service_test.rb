# frozen_string_literal: true

require 'test_helper'

class UploadNoteServiceTest < Minitest::Test
  # A feedback box that keeps what it is sent and answers +result+.
  class Box
    attr_reader :calls

    def initialize(result)
      @result = result
      @calls  = []
    end

    def call(op, actor, **fields)
      @calls << [op, actor, fields]
      { 'result' => @result }
    end
  end

  def work
    picture = PetsciiModel.from_tcv(TcvModel.parse(tcv_fixture('ttg-logo')))
    WorkModel.new(id: '20261123-120000-abcd', title: 'Logo', handle: 'ada', created_at: Time.now, petscii: picture)
  end

  def test_a_note_is_feedback_of_the_upload_kind_from_the_uploader
    box = Box.new('ok')
    UploadNoteService.new(box).call(work, :ada)
    op, actor, fields = box.calls.first
    assert_equal [:submit, :ada, 'upload'], [op, actor, fields[:kind]]
    assert_equal 'New PETSCII work: Logo', fields[:subject]
    assert_includes fields[:body], 'bin/works remove 20261123-120000-abcd'
    assert_equal 'Exhibition work 20261123-120000-abcd', fields[:context]
  end

  def test_a_note_that_does_not_go_is_logged
    _, err = capture_io { UploadNoteService.new(Box.new('unavailable')).call(work, nil) }
    assert_match(/upload note not sent/, err)
  end
end
