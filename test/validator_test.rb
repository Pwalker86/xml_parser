# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../xml_parser'

class ISO20022ValidatorTest < Minitest::Test
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
      </Document>
    XML

    @invalid_xml = <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <Document>
        <SvcLvl>
          <Prtry>INCORRECT</Prtry>
        </SvcLvl>
        <CtgyPurp>
          <Cd>INVALID</Cd>
        </CtgyPurp>
      </Document>
    XML
  end

  def test_valid_xml_validation
    validator = ISO20022Validator.new(@valid_xml)
    assert validator.validate
    assert_empty validator.errors
  end

  def test_invalid_xml_validation
    validator = ISO20022Validator.new(@invalid_xml)
    refute validator.validate
    refute_empty validator.errors
    assert_equal 2, validator.errors.size
  end

  def test_validation_with_custom_rules
    custom_rules = {
      'required_elements' => ['SvcLvl'],
      'expected_values' => {'SvcLvl/Prtry' => 'CUSTOM'}
    }

    validator = ISO20022Validator.new(@valid_xml, custom_rules)
    refute validator.validate
    refute_empty validator.errors
    assert_match(/Expected: 'CUSTOM', Found: 'NURG'/, validator.errors.first)
  end
end
