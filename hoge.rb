require "twitter"
require "curb"
require "json"
require "pry"

class TwitterMonitoring
  def initialize(config)
    @config = config
    @rest = Twitter::REST::Client.new(@config)
    @stream = Twitter::Streaming::Client.new(@config)
    @data = {
      channel: "#chat",
      username: "Monitoring",
      icon_url: ":squirrel:"
    }
  end
  attr_reader :config, :rest, :stream

  def run
    streaming_run
  end

  def verification(tweet)
    puts tweet.user.screen_name
    ENV.fetch("USERS").split(",").include?(tweet.user.screen_name)
  end

  def streaming_run
    @stream.user do |tweet|
      next unless tweet.is_a?(Twitter::Tweet)
      next unless verification(tweet)
      slack_post(tweet)
    end
  end
  def slack_post(tweet)
    attachments = [{
      author_icon:    tweet.user.profile_image_url.to_s,
      author_name:    tweet.user.name,
      author_subname: "@#{tweet.user.screen_name}",
      text:           tweet.full_text,
      author_link:    tweet.uri.to_s,
      color:          tweet.user.profile_link_color
    }]
    unless tweet.media.empty?
      tweet.media.each_with_index do |v, i| 
        attachments[i] ||= {}
        attachments[i].merge!({image_url: v.media_url})
      end
    end
    Curl.post(ENV.fetch("SLACK_WEBHOOKS_TOKEN"), @data.merge(attachments: attachments).to_json)
  end
end

CONFIG = {
  consumer_key:        ENV.fetch("CONSUMER_KEY"),
  consumer_secret:     ENV.fetch("CONSUMER_SECRET"),
  access_token:        ENV.fetch("ACCESS_TOKEN"),
  access_token_secret: ENV.fetch("ACCESS_TOKEN_SECRET")
}

app = TwitterMonitoring.new(CONFIG)
app.run
