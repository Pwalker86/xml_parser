# frozen_string_literal: true

require 'optparse'
require_relative 'xml_parser'

module ISO20022
  # Command-line interface for ISO20022 XML Validator
  class CLI
    attr_reader :options, :rule_files

    def initialize
      @options = { rules_dir: File.join(File.dirname(__FILE__), 'rules') }
      @rule_files = []
    end

    def parse(args)
      option_parser.parse!(args)

      if args.empty?
        puts 'Missing XML file path. Use --help for usage details.'
        exit 1 unless ENV['RUBY_ENV'] == 'test'
        @xml_file = 'dummy_file.xml' # For testing
      else
        @xml_file = args[0]

        unless File.exist?(@xml_file) || ENV['RUBY_ENV'] == 'test'
          puts "Error: File '#{@xml_file}' not found"
          exit 1
        end
      end

      self
    end

    def run
      xml_content = File.read(@xml_file)

      # Create multi-rule validator
      multi_validator = MultiRuleValidator.new(xml_content)

      # Load specified rule files
      rule_files.each do |file|
        if File.exist?(file)
          begin
            rules = JSON.parse(File.read(file))
            name = File.basename(file, '.json')
            multi_validator.add_validator(rules, name)
            puts "Loaded rules from #{file}"
          rescue JSON::ParserError => e
            puts "Error parsing rules file: #{e.message}"
            exit 1
          end
        else
          puts "Error: Rules file '#{file}' not found"
          exit 1
        end
      end

      # Load rules from directory if no specific rules specified
      if rule_files.empty? && File.directory?(options[:rules_dir])
        multi_validator.load_rules_from_directory(options[:rules_dir])
      end

      # Apply payment method check if specified
      if options[:payment_method]
        tag = options[:payment_method][:tag]
        value = options[:payment_method][:value]

        rules = {
          'required_elements' => [tag],
          'expected_values' => { tag => value }
        }

        multi_validator.add_validator(rules, 'PaymentMethodValidator')
        puts "Validating that <#{tag}> contains '#{value}'"
      end

      display_results(multi_validator)
    end

    private

    def option_parser
      OptionParser.new do |opts|
        opts.banner = 'Usage: ruby xml_parser.rb [options] <path_to_xml_file>'

        opts.on('-r', '--rules=FILE', 'JSON file containing validation rules') do |file|
          rule_files << file
        end

        opts.on('-d', '--rules-dir=DIR', 'Directory containing rule files') do |dir|
          options[:rules_dir] = dir
        end

        opts.on('-p', '--payment-method TAG=VALUE', 'Check specific payment method tag and value') do |tag_value|
          tag, value = tag_value.split('=', 2)
          options[:payment_method] = { tag: tag, value: value }
        end

        opts.on('-h', '--help', 'Show this help message') do
          puts opts
          exit(0) unless ENV['RUBY_ENV'] == 'test'
          # When testing, we don't want to exit
        end
      end
    end

    def display_results(validator)
      if validator.validate
        puts 'XML validation successful! The file follows the ISO 20022 format rules.'
        return 0
      else
        puts 'XML validation failed with the following errors:'
        validator.errors.each_with_index do |error, index|
          puts "  #{index + 1}. #{error}"
        end
        return 2
      end
    end
  end
end

# Execute CLI when script is run directly
if __FILE__ == $PROGRAM_NAME
  exit ISO20022::CLI.new.parse(ARGV).run
end
