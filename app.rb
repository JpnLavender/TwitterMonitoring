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
      channel: "#twitter_monitoring ",
      username: "Monitoring",
      icon_url: ":squirrel:"
    }
  end
  attr_reader :config, :rest, :stream

  def find_reply_source(id)
    puts "RUN: find_reply_source"
    begin 
      find_reply_source_id = @rest.status(id).in_reply_to_status_id
      find_reply_source_data = @rest.status(find_reply_source_id)
      slack_post(find_reply_source_data)
    rescue
      puts "ERROR: find_reply_source"
    end
  end

  def streaming_run
    puts "RUN: Streaming"
    binding.pry if "develop"== ARGV[0]
    begin
      @stream.user do |tweet|
        next unless tweet.is_a?(Twitter::Tweet)
        puts "@#{tweet.user.screen_name} #{tweet.full_text[0..20]}"
        next unless tweet.user.screen_name == ENV.fetch("TARGET")
        find_reply_source(tweet.id)
        slack_post(tweet)
      end
    rescue
      puts "Error: Streaming"
      streaming_run
    end
  end

  def slack_post(tweet)
    puts "RUN: SlackPost"
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
    puts "OK: Send POST"
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
