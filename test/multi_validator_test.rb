# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../xml_parser'

class MultiRuleValidatorTest < Minitest::Test
  def setup
    @valid_xml = <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <Document>
        <SvcLvl>
          <Prtry>NURG</Prtry>
        </SvcLvl>
        <CtgyPurp>
          <Cd>SUPP</Cd>
        </CtgyPurp>
        <CdtrAgt>
          <FinInstnId>
            <BIC>BOFAUS3N</BIC>
          </FinInstnId>
        </CdtrAgt>
      </Document>
    XML

    @multi_validator = MultiRuleValidator.new(@valid_xml)
  end

  def test_add_validator
    # First add a validator that should pass
    @multi_validator.add_validator({
      'required_elements' => ['SvcLvl/Prtry', 'CtgyPurp/Cd'],
      'expected_values' => {
        'SvcLvl/Prtry' => 'NURG',
        'CtgyPurp/Cd' => 'SUPP'
      }
    }, 'TestValidator1')

    # Then add a validator that should fail
    @multi_validator.add_validator({
      'required_elements' => ['CdtrAgt/FinInstnId/BIC'],
      'expected_values' => {'CdtrAgt/FinInstnId/BIC' => 'INVALIDBIC'}
    }, 'TestValidator2')

    # Validation should fail because of the second validator
    refute @multi_validator.validate
    assert_equal 1, @multi_validator.errors.size
    assert_match(/TestValidator2/, @multi_validator.errors.first)
    assert_match(/Expected: 'INVALIDBIC', Found: 'BOFAUS3N'/, @multi_validator.errors.first)
  end

  def test_validate_with_no_validators
    # Test with no validators added - should pass
    assert @multi_validator.validate
    assert_empty @multi_validator.errors
  end
end
