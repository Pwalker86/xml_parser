# frozen_string_literal: true

# !/usr/bin/env ruby
# ISO 20022 XML Parser and Validator
# This program parses and validates XML against ISO 20022 format rules

require 'nokogiri'
require 'json'
require 'pathname'

# ISO20022Validator class to handle XML parsing and validation
class ISO20022Validator
  attr_reader :errors, :xml_doc, :rules, :name

  def initialize(xml_content, rules = nil, name = nil)
    @errors = []
    @rules = rules || default_rules
    @name = name || self.class.name
    @xml_content = xml_content

    begin
      @xml_doc = Nokogiri::XML(xml_content, &:strict)
      @xml_doc.errors.each do |error|
        @errors << "XML parsing error: #{error}"
      end
    rescue Nokogiri::XML::SyntaxError => e
      @errors << "Invalid XML: #{e.message}"
    end
  end

  def validate
    # Skip validation if XML parsing failed
    return false unless @errors.empty?

    # Skip validation if none of the required elements are present
    # This allows for optional validation based on document content
    return true unless applicable?

    validate_structure
    validate_content
    validate_custom_rules
    validate_format_rules

    @errors.empty?
  end

  def applicable?
    return true if @rules['required_elements'].nil? || @rules['required_elements'].empty?

    # Skip if XML parsing failed
    return false if @xml_doc.nil?

    # Check if at least one required element exists
    @rules['required_elements'].any? do |element_path|
      @xml_doc.at_xpath("//#{element_path}")
    end
  end

  private

  def default_rules
    {
      'required_elements' => [
        'SvcLvl',
        'SvcLvl/Prtry',
        'CtgyPurp',
        'CtgyPurp/Cd'
      ],
      'expected_values' => {
        'SvcLvl/Prtry' => 'NURG',
        'CtgyPurp/Cd' => 'SUPP'
      }
    }
  end

  def validate_structure
    # Check for required elements based on rules
    @rules['required_elements']&.each do |element_path|
      validate_element_exists(element_path)
    end
  end

  def validate_content
    # Validate specific content values according to rules
    @rules['expected_values']&.each do |element_path, expected_value|
      validate_element_value(element_path, expected_value)
    end
  end

  def validate_custom_rules
    # Check if root element matches expected value
    if @rules['root_element']
      root_name = @xml_doc.root&.name
      unless root_name == @rules['root_element']
        @errors << "Root element is '#{root_name}' but expected '#{@rules['root_element']}'"
      end
    end

    # Check expected content of root element if specified
    return unless @rules['root_content']

    root_content = @xml_doc.root&.text&.strip
    return if root_content == @rules['root_content']

    @errors << "Root element content is '#{root_content}' but expected '#{@rules['root_content']}'"
  end

  def validate_format_rules
    @rules['format_validations']&.each do |xpath, validation|
      element = @xml_doc.at_xpath("//#{xpath}")
      next unless element

      pattern = validation['pattern']
      next unless pattern

      # Convert string pattern from JSON to regex if needed
      pattern = pattern.is_a?(String) ? Regexp.new(pattern) : pattern

      unless element.text.strip.match?(pattern)
        @errors << "Format error for #{xpath}: #{validation['description'] || 'Invalid format'}"
      end
    end
  end

  def validate_element_exists(xpath)
    return if @xml_doc.at_xpath("//#{xpath}")

    @errors << "Required element missing: #{xpath}"
  end

  def validate_element_value(xpath, expected_value)
    element = @xml_doc.at_xpath("//#{xpath}")
    return unless element
    return if element.text.strip == expected_value

    @errors << "Invalid value for #{xpath}. Expected: '#{expected_value}', Found: '#{element.text.strip}'"
  end
end

# MultiRuleValidator class to handle validating XML against multiple rule sets
class MultiRuleValidator
  attr_reader :validators, :errors

  def initialize(xml_content)
    @xml_content = xml_content
    @validators = []
    @errors = []
  end

  def add_validator(rules, name = nil)
    @validators << ISO20022Validator.new(@xml_content, rules, name)
  end

  def load_rules_from_directory(directory)
    Dir.glob(File.join(directory, '*.json')).each do |rule_file|
      rule_name = File.basename(rule_file, '.json')
      rules = JSON.parse(File.read(rule_file))
      add_validator(rules, rule_name)
      puts "Loaded rules from #{rule_file}"
    rescue JSON::ParserError => e
      puts "Error parsing rules file #{rule_file}: #{e.message}"
    end
  end

  def validate
    @errors.clear
    applicable_validators = 0
    successful_validations = 0

    @validators.each do |validator|
      next unless validator.applicable?

      applicable_validators += 1
      if validator.validate
        successful_validations += 1
      else
        validator.errors.each do |error|
          @errors << "[#{validator.name}] #{error}"
        end
      end
    end

    # If no validators were applicable, consider it a success
    return true if @validators.empty? || applicable_validators.zero?

    successful_validations == applicable_validators
  end
end

# Main execution code starts here
if __FILE__ == $PROGRAM_NAME
  require_relative 'cli'
  exit ISO20022::CLI.new.parse(ARGV).run
end
