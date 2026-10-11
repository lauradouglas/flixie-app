require 'net/http'
require 'json'
require 'uri'

# Notification failure never changes the result of a store upload/submission.
module FlixieSlack
  def self.notify(text, env: ENV, post: nil, warn: ->(message) { $stderr.puts(message) })
    raw = env['SLACK_RELEASES_WEBHOOK_URL'].to_s
    return if raw.empty?
    uri = URI(raw)
    unless uri.scheme == 'https' && uri.host == 'hooks.slack.com' && uri.port == 443 && uri.userinfo.nil? && uri.path.start_with?('/services/')
      raise ArgumentError, 'Invalid Slack destination'
    end
    payload = JSON.generate(text: text, mrkdwn: false, unfurl_links: false, unfurl_media: false)
    if post
      post.call(uri, payload)
    else
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 5
      http.read_timeout = 5
      request = Net::HTTP::Post.new(uri.request_uri, 'Content-Type' => 'application/json')
      request.body = payload
      response = http.request(request)
      raise 'Slack delivery failed' unless response.code == '200' && response.body == 'ok'
    end
  rescue StandardError
    warn.call('Flixie Slack notification failed; check channel configuration. Store operation result is unchanged.')
  end
end
