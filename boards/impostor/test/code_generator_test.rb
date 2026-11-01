# frozen_string_literal: true

require 'test_helper'

class CodeGeneratorTest < Minitest::Test
  def test_a_code_decrypts_to_the_first_letters_of_its_name
    assert_equal 'NOR', Impostor::CodeGenerator.decrypt(Impostor::CodeGenerator.encrypt('NORMAN'))
    assert_equal 'ATM', Impostor::CodeGenerator.decrypt('265lfi')
  end

  def test_a_malformed_code_decrypts_to_nothing
    assert_equal '???', Impostor::CodeGenerator.decrypt('ABC')
  end
end
