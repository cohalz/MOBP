# coding: utf-8

require 'natto'
require 'nkf'
require 'mysql2'
require_relative 'config'

#ランダム性と速度をここで調整
LIMIT = ' and rand() < 0.05 limit 40'

def normalize_tweet(tweet1)
  return "" if tweet1 == nil
  tweet = tweet1.dup.to_s # 数字だけのツイートでunpack('U*')がエラーを吐くので全てtoString
  tweet.force_encoding('utf-8')
  #return nil if NKF.guess(tweet) != NKF::UTF8
  tweet.gsub!(/\.?@[0-9A-Za-z_:]+/, '')  # リプライをすべて削除
  tweet.gsub!(/RT/, '')  # RT削除
  tweet.gsub!(/https?:[\w\/\.]+/, '')  # URLを削除
  tweet.gsub!(/#/, ' #') #ハッシュタグ化
  tweet.gsub!(/[「」【】『』）]/, '') #括弧削除
  tweet.gsub!(/"/, '') #インジェクションやばそう対策
  tweet.gsub!(/'/, '') #インジェクションやばそう対策
  tweet.gsub!(/’/, '') #インジェクションやばそう対策
  tweet.gsub!(/\\\\/, '\\') #インジェクションやばそう対策
  tweet.gsub!(/.*(\\)/, '') #括弧削除
  tweet.gsub!(/&gt;/, '>') #実体参照
  tweet.gsub!(/&lt;/, '<') #実体参照
  tweet.gsub!(/&amp;/, '&') #実体削除
  # tweet.gsub!(/#[0-9A-Za-z_]+/, '')  # ハッシュタグを削除
  tweet
end

def wakatu(tweet,natto)
  tmp = []
  nomtwi = normalize_tweet(tweet)
  if nomtwi != nil
    natto.parse(nomtwi) do |n|
      tmp.push(n.surface)
    end
  end
  tmp
end

def first_is_particle?(tweet)
  particle = '助詞'
  natto = Natto::MeCab.new
  nomtwi = normalize_tweet(tweet)

  if nomtwi != nil
    natto.parse(nomtwi) do |n|
      hinshi = n.feature.split(',')
      return hinshi[0] == particle
    end
  end
  false
end



def create_markov_table(tweet,client,natto)
  # 形態素4つずつから成るテーブルを生成
  order = 4

  wakati_array = Array.new
  wakati_array += wakatu(tweet,natto)

  i = 0
  loop do
    wakati = wakati_array[i..(i+order-1)]
    break if wakati[order - 1] == nil
    query = "insert into  #{MARKOV_TABLE} values ('#{wakati[0]}', '#{wakati[1]}', '#{wakati[2]}', '#{wakati[3]}')"
    query.gsub!(/\\\'/,"'")
    client.query(query)
    i += 1
  end
  nomtwi = normalize_tweet(tweet)
  query = "insert into #{MASTER_TABLE} values ('#{nomtwi}')"
  query.gsub!(/\\\'/,"'")
  client.query(query)
end


def gen_first(tweet)
  wakati = []
  whitelist = ['名詞', '感動詞']
  blacklist = ['接尾', '代名詞', '形容動詞語幹']
  natto = Natto::MeCab.new  
  nomtwi = normalize_tweet(tweet)

  if nomtwi != nil
    natto.parse(nomtwi) do |n|
      hinshi = n.feature.split(',')
      wakati.push(n.surface) if whitelist.include?(hinshi[0]) && !blacklist.include?(hinshi[1])
    end
  end
  wakati.sample
end



def gen_words(client,fetch_tweets,tweet,count=5)
  if count == 0 or tweet == nil
    query = "select * from #{MARKOV_TABLE} where rand() < 0.001 limit 1"
    results = client.query(query)
  else
    if tweet == ''
      if rand(3) < 2
        query = "select * from #{MARKOV_TABLE} where #{FIRST_COLUMN} = '#{gen_first(fetch_tweets.sample)}'"
        results = client.query(query)
      else
        query = "select * from #{MARKOV_TABLE} where #{SECOND_COLUMN} = '#{gen_first(fetch_tweets.sample)}'"
        results = client.query(query).select { |result|
          !first_is_particle?(result[FIRST_COLUMN]+result[SECOND_COLUMN]+result[THIRD_COLUMN]+result[FOURTH_COLUMN])
        }
      end
    results
    else
      if rand(3) < 2
        query = "select * from #{MARKOV_TABLE} where #{FIRST_COLUMN} = '#{gen_first(tweet)}'"
        results = client.query(query)
      else
        query = "select * from #{MARKOV_TABLE} where #{SECOND_COLUMN} = '#{gen_first(tweet)}'"
        results = client.query(query).select { |result|
          !first_is_particle?(result[FIRST_COLUMN]+result[SECOND_COLUMN]+result[THIRD_COLUMN]+result[FOURTH_COLUMN])
        }
      end
      if results.count == 0
        gen_words(client,fetch_tweets,tweet,count-1)
      else
        results
      end
    end
  end
  results
end

def generate_tweet(client,count,fetch_tweets,tweet)
  # 先頭を選択(取得できなかったら繰り返す)
  results = gen_words(client,fetch_tweets,tweet)
  while results.size == 0 do
    results = gen_words(client,fetch_tweets,tweet)
  end
  selected = results.to_a.sample
  markov_tweet = selected[FIRST_COLUMN] + selected[SECOND_COLUMN] +
                 selected[THIRD_COLUMN] + selected[FOURTH_COLUMN]

  while true
    # 以後、''で終わるものを拾うまで連鎖を続ける
    loop do
      query = "select * from #{MARKOV_TABLE} where
                #{FIRST_COLUMN} = '#{selected[FOURTH_COLUMN]}'" + LIMIT
      results = client.query(query)
      break if results.count == 0 # 連鎖できなければ諦める
      selected = results.to_a.sample
      markov_tweet += selected[SECOND_COLUMN] + selected[THIRD_COLUMN] +
                      selected[FOURTH_COLUMN]
      break if selected[FOURTH_COLUMN] == '' #  or
    end

    markov_tweet = normalize_tweet(markov_tweet)

    #文字数オーバーしたら数回再試行
    if count < 3 and markov_tweet.size > 50
      markov_tweet = generate_tweet(client,count+1,fetch_tweets,tweet)
    end

    break
  end
  markov_tweet.gsub!(/　/,'')
  markov_tweet
end
