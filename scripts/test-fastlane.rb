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
  attr_reader :calls, :lanes, :shell_environments
  def initialize
    @calls = []
    @shell_environments = []
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
  def sh(command)
    @shell_environments << ENV.to_h
    @calls << [:shell, Shellwords.split(command).join(" ")]
  end
  def app_store_connect_api_key(**options); @calls << [:key, options]; :fake_key; end
  def upload_to_testflight(**options); @calls << [:apple, options]; end
  def upload_to_app_store(**options); @calls << [:apple_screenshots, options]; end
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
  def test_production_submit_sends_for_review_and_includes_notes
    @runner.run(:android, :submit, build_number: 99)
    upload = @runner.calls.find { |kind, _| kind == :play }.last
    assert_equal 'production', upload[:track]
    assert_equal 'completed', upload[:release_status]
    assert_equal false, upload[:changes_not_sent_for_review]
    assert_equal false, upload[:rescue_changes_not_sent_for_review]
    assert_equal false, upload[:skip_upload_changelogs]
    assert_equal true, upload[:skip_upload_screenshots]
  end

  def test_apple_submit_preserves_manual_release_and_supplies_notes
    ENV['APP_STORE_CONNECT_KEY_ID'] = 'fixture-key'
    ENV['APP_STORE_CONNECT_ISSUER_ID'] = 'fixture-issuer'
    ENV['APP_STORE_CONNECT_KEY_FILE'] = '/tmp/fixture.p8'
    ENV['RELEASE_VERSION'] = '2.0.1'
    @runner.define_singleton_method(:build) { |_| '/tmp/fixture.ipa' }
    @runner.run(:ios, :submit, build_number: 99, uploaded: true)
    upload = @runner.calls.find { |kind, _| kind == :apple_screenshots }.last
    assert_equal true, upload[:submit_for_review]
    assert_equal false, upload[:automatic_release]
    assert_equal false, upload[:reject_if_possible]
    assert_equal '99', upload[:build_number]
    assert_equal '2.0.1', upload[:app_version]
    assert_equal true, upload[:skip_screenshots]
    assert_match(/without signing in/, upload[:release_notes]['en-GB'])
    @runner.run(:ios, :submit, build_number: 100, uploaded: true, replace_review: true)
    replacement = @runner.calls.reverse.find { |kind, _| kind == :apple_screenshots }.last
    assert_equal true, replacement[:reject_if_possible]
    assert_equal '100', replacement[:build_number]
  end

  def test_screenshot_sdk_process_does_not_inherit_fastlane_bundle
    ENV['BUNDLE_GEMFILE'] = '/tmp/fastlane-only-Gemfile'
    ENV['BUNDLE_PATH'] = '/tmp/fastlane-only-gems'
    @runner.run(:ios, :screenshots)
    child_env = @runner.shell_environments.fetch(0)
    refute child_env.key?('BUNDLE_GEMFILE')
    refute child_env.key?('BUNDLE_PATH')
    assert_equal '/tmp/fastlane-only-Gemfile', ENV['BUNDLE_GEMFILE']
  end
  def test_tablet_capture_passes_category_without_uploading
    @runner.run(:android, :screenshots, type: 'sevenInchScreenshots')
    assert_equal [:shell], @runner.calls.map(&:first)
    assert_includes @runner.calls.first.last, '--android-type sevenInchScreenshots'
  end
  def test_internal_draft_builds_production_entrypoint
    @runner.run(:android, :draft, build_number: '123')
    command = @runner.calls.find { |type, value| type == :shell && value.include?('flutter build appbundle') }.last
    guard = @runner.calls.index { |type, value| type == :shell && value.include?('check-google-oauth.py') }
    build = @runner.calls.index { |type, value| type == :shell && value.include?('flutter build appbundle') }
    assert_operator guard, :<, build
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
  def test_ios_build_validates_signed_ipa_before_returning
    original_glob = Dir.method(:[])
    Dir.define_singleton_method(:[]) { |*_args| ['/tmp/fake.ipa'] }
    assert_equal '/tmp/fake.ipa', @runner.run(:ios, :build, build_number: '123')
    assert_equal [:shell, :shell], @runner.calls.map(&:first)
    assert_includes @runner.calls.last.last, 'scripts/validate-ios-ipa.py /tmp/fake.ipa'
  ensure
    Dir.define_singleton_method(:[], original_glob)
  end

  def test_ios_build_command
    @runner.flutter_release('ipa', '123')
    assert_includes @runner.calls.last.last, '--export-method=app-store'
    assert_includes @runner.calls.last.last, '--target=lib/main.dart'
  end

  def test_screenshot_capture_is_separate_from_build_and_upload
    [:ios, :android].each do |platform|
      runner = LaneHarness.new
      runner.run(platform, :screenshots, device: 'dedicated-device')
      assert_equal [:shell], runner.calls.map(&:first)
      assert_includes runner.calls.first.last, "store-screenshots.py #{platform} --device dedicated-device"
    end
  end

  def test_ios_screenshots_validate_then_upload_without_submission
    ENV['APP_STORE_CONNECT_KEY_ID'] = 'fake'
    ENV['APP_STORE_CONNECT_ISSUER_ID'] = 'fake'
    ENV['APP_STORE_CONNECT_KEY_FILE'] = '/tmp/fake.p8'
    @runner.run(:ios, :upload_screenshots)
    assert_equal [:shell, :key, :apple_screenshots], @runner.calls.map(&:first)
    assert_includes @runner.calls.first.last, 'prepare-store-screenshots.py --validate'
    upload = @runner.calls.last.last
    assert upload[:screenshots_path].end_with?('/fastlane/store-presentation')
    assert upload[:skip_binary_upload]
    assert upload[:skip_metadata]
    assert_equal true, upload[:skip_app_version_update]
    assert_equal false, upload[:run_precheck_before_submit]
    assert_equal false, upload[:submit_for_review]
    assert_equal false, upload[:automatic_release]
  end

  def test_ios_presentation_is_separate_from_capture_and_upload
    @runner.run(:ios, :prepare_screenshots)
    assert_equal [:shell], @runner.calls.map(&:first)
    assert_includes @runner.calls.first.last, 'prepare-store-screenshots.py'
  end

  def test_android_presentation_does_not_upload
    @runner.run(:android, :prepare_screenshots)
    assert_equal [:shell], @runner.calls.map(&:first)
    assert_includes @runner.calls.first.last, 'prepare-store-screenshots.py android'
  end

  def test_android_screenshots_upload_only_images
    @runner.run(:android, :upload_screenshots)
    assert_equal [:shell, :play], @runner.calls.map(&:first)
    assert_includes @runner.calls.first.last, "prepare-store-screenshots.py android --validate"
    upload = @runner.calls.last.last
    assert upload[:metadata_path].end_with?("/fastlane/store-presentation-android")
    assert_equal false, upload[:skip_upload_screenshots]
    [:skip_upload_aab, :skip_upload_apk, :skip_upload_metadata,
     :skip_upload_images, :skip_upload_changelogs].each { |key| assert upload[key] }
  end
end
