#!/usr/bin/env ruby
# Exercise the actual lane definitions without SDKs, credentials or network.
require 'minitest/autorun'
require 'tmpdir'

module UI
  def self.user_error!(message)
    raise ArgumentError, message
  end
end

class LaneHarness
  attr_reader :calls, :lanes
  def initialize
    @calls = []
    @lanes = {}
    instance_eval(File.read(File.expand_path('../fastlane/Fastfile', __dir__)),
                  File.expand_path('../fastlane/Fastfile', __dir__))
    define_singleton_method(:release_file) { |path| File.expand_path(path, File.expand_path('..', __dir__)) }
  end
  def platform(name)
    @platform = name
    yield
  end
  def desc(*) ; end
  def lane(name, &block)
    @lanes[[@platform, name]] = block
  end
  def run(platform, name, options = {})
    @platform = platform
    @lanes.fetch([platform, name]).call(options)
  end
  def build(options); run(@platform, :build, options); end
  def promote(options); run(@platform, :promote, options); end
  def release_file(path); File.expand_path(path, File.expand_path('..', __dir__)); end
  def sh(command); @calls << [:shell, Shellwords.split(command).join(" ")]; end
  def app_store_connect_api_key(**options); @calls << [:key, options]; :fake_key; end
  def upload_to_testflight(**options); @calls << [:apple, options]; end
  def upload_to_play_store(**options); @calls << [:play, options]; end
end

class FastlaneTest < Minitest::Test
  def setup
    @previous_env = ENV.to_h
    ENV['PLAY_STORE_KEY_FILE'] = '/tmp/fake.json'
    ENV.delete('PLAY_STORE_TRACK')
    @runner = LaneHarness.new
  end
  def teardown
    ENV.replace(@previous_env)
  end
  def test_internal_draft_builds_production_entrypoint
    @runner.run(:android, :draft, build_number: '123')
    command = @runner.calls.find { |type, _| type == :shell }.last
    assert_includes command, '--target=lib/main.dart'
    assert_includes command, '--build-number=123'
    assert_includes command, '--dart-define=API_BASE_URL=https://flixie-api-'
    uploads = @runner.calls.select { |type, _| type == :play }
    assert_equal 1, uploads.length
    assert_equal 'internal', uploads.first.last[:track]
    assert_equal 'draft', uploads.first.last[:release_status]
    assert uploads.first.last[:skip_upload_changelogs]
  end
  def test_both_creates_drafts_and_promotes_exact_version
    @runner.run(:android, :draft, build_number: '123', track: 'both')
    uploads = @runner.calls.select { |type, _| type == :play }.map(&:last)
    assert_equal 2, uploads.length
    assert_equal 'production', uploads.last[:track_promote_to]
    assert_equal 'draft', uploads.last[:track_promote_release_status]
    assert_equal 123, uploads.last[:version_code]
    assert uploads.last[:skip_upload_aab]
  end
  def test_promotion_does_not_build
    @runner.run(:android, :promote, build_number: '123')
    assert_equal [:play], @runner.calls.map(&:first)
  end
  def test_invalid_inputs_do_nothing
    ['', '0', '-1', '123;echo bad'].each do |number|
      assert_raises(ArgumentError) { @runner.run(:android, :draft, build_number: number) }
    end
    assert_raises(ArgumentError) { @runner.run(:android, :draft, build_number: '123', track: 'beta') }
    assert_empty @runner.calls
  end
  def test_missing_credentials_fail_before_build
    ENV.delete('PLAY_STORE_KEY_FILE')
    assert_raises(ArgumentError) { @runner.run(:android, :draft, build_number: '123') }
    ENV.delete('APP_STORE_CONNECT_KEY_ID')
    assert_raises(ArgumentError) { @runner.run(:ios, :beta, build_number: '123') }
    assert_empty @runner.calls
  end
  def test_apple_upload_does_not_distribute_externally
    ENV['APP_STORE_CONNECT_KEY_ID'] = 'fake'
    ENV['APP_STORE_CONNECT_ISSUER_ID'] = 'fake'
    ENV['APP_STORE_CONNECT_KEY_FILE'] = '/tmp/fake.p8'
    @runner.define_singleton_method(:build) { |_options| '/tmp/fake.ipa' }
    @runner.run(:ios, :beta, build_number: '123')
    upload = @runner.calls.last.last
    assert_equal false, upload[:distribute_external]
    assert_equal true, upload[:skip_waiting_for_build_processing]
    assert_equal 'com.flixie.flixieApp', upload[:app_identifier]
  end
  def test_ios_build_command
    @runner.flutter_release('ipa', '123')
    assert_includes @runner.calls.last.last, '--export-method=app-store'
    assert_includes @runner.calls.last.last, '--target=lib/main.dart'
  end
end
