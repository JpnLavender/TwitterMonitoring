require "twitter"
require "curb"
require "json"

class TwitterMonitoring
  def initialize(config)
    @config = config
    @rest = Twitter::REST::Client.new(@config)
    @stream = Twitter::Streaming::Client.new(@config)
    @data = {
      channel: "#twitter_monitoring ",
      username: "Monitoring",
      icon_url: ":squirrel:"
    }
  end
  attr_reader :config, :rest, :stream

  def follow_users(screen_name)
    @rest.friend_ids(screen_name).each_slice(100).each do |slice|
      @rest.users(slice).each do |friend|
        @rest.follow(friend.id)
      end
    end
  end

  def streaming_run
    @stream.user do |tweet|
      begin
        next unless tweet.is_a?(Twitter::Tweet)
        next unless tweet.user.screen_name == ENV.fetch("TARGET") || tweet.full_text =~ /#{ENV.fetch("TARGET")}/
        follow_users(ENV.fetch("TARGET"))
        puts tweet.full_text
        slack_post(tweet)
      rescue
        next
      end
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
    Curl.post(
      ENV.fetch("SLACK_WEBHOOKS_TOKEN"), 
      @data.merge(attachments: attachments).to_json
    )
  end
end

CONFIG = {
  consumer_key:        ENV.fetch("CONSUMER_KEY"),
  consumer_secret:     ENV.fetch("CONSUMER_SECRET"),
  access_token:        ENV.fetch("ACCESS_TOKEN"),
  access_token_secret: ENV.fetch("ACCESS_TOKEN_SECRET")
}

app = TwitterMonitoring.new(CONFIG)
app.streaming_run
