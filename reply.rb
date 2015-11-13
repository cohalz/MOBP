# coding: utf-8

require 'twitter'
require 'tweetstream'
require 'csv'
require 'natto'
require 'date'
require_relative 'markov'
require_relative 'config'

class ReplyDaemon
  def initialize
    puts 'Start initialization of daemon...'

    @rest = Twitter::REST::Client.new do |config|
      config.consumer_key = YOUR_CONSUMER_KEY
      config.consumer_secret = YOUR_CONSUMER_SECRET
      config.access_token = YOUR_OAUTH_TOKEN
      config.access_token_secret = YOUR_OAUTH_TOKEN_SECRET
    end
    TweetStream.configure do |config|
      config.consumer_key = YOUR_CONSUMER_KEY
      config.consumer_secret = YOUR_CONSUMER_SECRET
      config.oauth_token = YOUR_OAUTH_TOKEN
      config.oauth_token_secret = YOUR_OAUTH_TOKEN_SECRET
    end
    @stream = TweetStream::Client.new

    @pid_file_path = './reply_daemon.pid'
    @error_log_path = './reply_error.log'

    @client = Mysql2::Client.new(:host => 'localhost', :database => 'mobp' , :username => 'root', :password => PASSWD)
    @natto = Natto::MeCab.new
   
    begin 
      @fetch_tweets = @rest.home_timeline.map {|object| 
        normalize_tweet(object.text)
      }
      twi = generate_tweet(@client,0,@fetch_tweets,'')
      `cat ./reply_daemon.pid | xargs kill`
      @rest.update(twi)
      puts 'Finish initialization.'

    rescue => ex
      open(@error_log_path, 'a') { |f| 
        f.puts(Date.today.to_time)
        f.puts(ex.backtrace) 
        f.puts(ex.message) 
        f.puts('') } if @error_log_path
    end
  end

  def run
    daemonize
    begin
      @stream.userstream do |object|
        if object.is_a?(Twitter::Tweet)
                  # sleep(3)
          if object.text.include?('@' + BOT_SCREEN_NAME) && !(object.text.include?('RT'))
          #if object.text.match(/.*@MOBP_.*/) && !(object.text.include?('RT'))
           # if m = object.text.match(/^単語登録:(.*)\((.*)\)$/) 
	     # open("~/dic/user.csv", 'a') { |f| 
              #  f.puts("#{m[1]},,,10,名詞,固有名詞,人名,名,*,*,#{m[1]},*,*")} if m[2] == "人名"
             #   f.puts("#{m[1]},,,10,名詞,固有名詞,一般,*,*,*,#{m[1]},*,*")} if m[2] == "一般"
            #  }
           # else

              reply = '@' + object.user.screen_name + ' ' + generate_tweet(@client,0,@fetch_tweets,object.text)
              @rest.update(reply[0, 140], { 'in_reply_to_status_id' => object.id })
           # end
          end
          if object.user.screen_name != BOT_SCREEN_NAME && !(object.text.include?('RT'))
            create_markov_table(object.text,@client,@natto)
          end
        end
      end
    rescue => ex
      open(@error_log_path, 'a') { |f| 
        f.puts(Date.today.to_time)
        f.puts(ex.backtrace) 
        f.puts(ex.message) 
        f.puts('') } if @error_log_path
      # When something error occured, tell it by replying to admin
      # @rest.update('@' + ADMIN_SCREEN_NAME + ' Error起こっためう')
    end
  end

  def daemonize
    exit!(0) if Process.fork
    Process.setsid
    exit!(0) if Process.fork
    open_pid_file
  end

  def open_pid_file
    open(@pid_file_path, 'w') {|f| f << Process.pid } if @pid_file_path
  end
end

ReplyDaemon.new.run

