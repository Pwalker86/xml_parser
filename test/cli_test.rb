# frozen_string_literal: true

require 'minitest/autorun'
require 'stringio'
require_relative '../cli'

class CLITest < Minitest::Test
  def setup
    ENV['RUBY_ENV'] = 'test'
    @cli = ISO20022::CLI.new
  end

  def test_initialize
    # Just check that the path ends with 'rules'
    assert_match(/rules$/, @cli.options[:rules_dir])
    assert_empty @cli.rule_files
  end

  def test_parse_rules_option
    @cli.parse(['-r', 'test_rules.json', 'dummy_file.xml'])
    assert_equal ['test_rules.json'], @cli.rule_files
  end

  def test_parse_rules_dir_option
    @cli.parse(['-d', 'custom_rules', 'dummy_file.xml'])
    assert_equal 'custom_rules', @cli.options[:rules_dir]
  end

  def test_parse_payment_method_option
    @cli.parse(['-p', 'Tag=Value', 'dummy_file.xml'])
    assert_equal({tag: 'Tag', value: 'Value'}, @cli.options[:payment_method])
  end

  def test_help_option
    stdout_capture = capture_output do
      @cli.parse(['-h'])
    end
    assert_match(/Usage:/, stdout_capture.string)
  end

  private

  def capture_output
    original_stdout = $stdout
    $stdout = StringIO.new
    yield
    $stdout
  ensure
    $stdout = original_stdout
  end
end
