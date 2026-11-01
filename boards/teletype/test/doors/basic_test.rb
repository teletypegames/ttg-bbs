# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../../lib/doors/commodore/basic'

# The BASIC V2 of the Commodore doors, driven through its Screen callables.
class BasicTest < Minitest::Test
  def setup
    @out    = +''
    @column = 0
    @input  = []
    screen = Commodore::Basic::Screen.new(
      write:    ->(text) { @out << text; @column += text.length },
      newline:  -> { @out << "\n"; @column = 0 },
      column:   -> { @column },
      cls:      -> { @out << '<CLS>' },
      readline: -> { @input.shift },
      stop?:    -> { false }
    )
    @basic = Commodore::Basic.new(screen, reset_address: 64_738)
  end

  def run_lines(*lines)
    lines.each { |line| @basic.enter(line) }
    @out
  end

  def test_print_zones_and_semicolons
    assert_equal "HELLO 1    2  3 \n", run_lines('PRINT "HELLO";1,2;3')
  end

  def test_nested_for_next
    assert_equal " 1  2  2  4 \n", run_lines('10 FOR I=1 TO 2: FOR J=1 TO 2: PRINT I*J;: NEXT J,I', '20 PRINT', 'RUN')
  end

  def test_step_down_and_next_without_for
    run_lines('10 FOR I=10 TO 1 STEP -3: PRINT I: NEXT I', '20 NEXT', 'RUN')
    assert_equal " 10 \n 7 \n 4 \n 1 \n?NEXT WITHOUT FOR  ERROR IN 20\n", @out
  end

  def test_input_redo_from_start
    @input.replace(['X,2', '1,2'])
    assert_equal "? ?REDO FROM START\n?  3 \n", run_lines('10 INPUT A,B', '20 PRINT A+B', 'RUN')
  end

  def test_gosub_return_and_if
    run_lines('10 GOSUB 100: IF 1 THEN 30', '20 PRINT "NO"', '30 PRINT "YES": END', '100 PRINT "SUB": RETURN', 'RUN')
    assert_equal "SUB\nYES\n", @out
  end

  def test_functions
    assert_equal " 3  2 -1  4 HELLOLLA 65 \n",
                 run_lines('PRINT INT(3.7);ABS(-2);SGN(-5);SQR(16);LEFT$("HELLO",2);RIGHT$("HELLO",3);' \
                           'MID$("HELLO",3,2);CHR$(65);ASC("A")')
  end

  def test_keywords_inside_names_and_errors
    assert_equal "?SYNTAX  ERROR\n?TYPE MISMATCH  ERROR\n?DIVISION BY ZERO  ERROR\n",
                 run_lines('TOTAL=5', 'X$=1', 'PRINT 1/0')
  end

  def test_list_range
    run_lines('10 PRINT 1', '20 PRINT 2', '30 PRINT 3', 'LIST 20-')
    assert_equal "20 PRINT 2\n30 PRINT 3\n", @out
  end

  def test_sys_to_the_reset_vector
    assert_raises(Commodore::Basic::Reset) { @basic.enter('SYS 64738') }
  end
end
