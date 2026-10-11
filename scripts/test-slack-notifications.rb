require 'minitest/autorun'
require_relative '../fastlane/slack_notifications'
class SlackNotificationsTest < Minitest::Test
  def test_disabled_and_unsafe_urls_do_not_send
    sends = []; warnings = []
    post = ->(*args) { sends << args }
    FlixieSlack.notify('fixture', env: {}, post: post)
    FlixieSlack.notify('fixture', env: { 'SLACK_RELEASES_WEBHOOK_URL' => 'http://localhost/services/secret' }, post: post, warn: ->(text) { warnings << text })
    assert_empty sends
    assert_equal 1, warnings.size
    refute_includes warnings.first, 'secret'
  end
  def test_send_plain_text_and_network_failure_is_nonfatal
    payload = nil
    env = { 'SLACK_RELEASES_WEBHOOK_URL' => 'https://hooks.slack.com/services/fixture' }
    FlixieSlack.notify('Submitted; not yet live', env: env, post: ->(_uri, body) { payload = JSON.parse(body) })
    assert_equal false, payload['mrkdwn']
    assert_equal 'Submitted; not yet live', payload['text']
    warnings = []
    FlixieSlack.notify('fixture', env: env, post: ->(*) { raise 'private URL' }, warn: ->(text) { warnings << text })
    assert_equal 1, warnings.size
    refute_includes warnings.first, 'private URL'
  end
end
