require 'rexml/document'

ADMIN_SCREEN_NAME = 'cohalz'
BOT_SCREEN_NAME = 'MOBP_'

settings = REXML::Document.new(open("#{Dir.home}/settings/settings.xml"))

YOUR_CONSUMER_KEY = settings.elements['root/twitter/mobp/consumerKey'].text
YOUR_CONSUMER_SECRET = settings.elements['root/twitter/mobp/consumerSecret'].text
YOUR_OAUTH_TOKEN = settings.elements['root/twitter/mobp/accessToken'].text
YOUR_OAUTH_TOKEN_SECRET = settings.elements['root/twitter/mobp/accessTokenSecret'].text

#DB_PASSWD = settings.elements['root/db/mysql/localpass'].text
DB_PASSWD = settings.elements['root/db/mysql/pass'].text
DB_NAME = settings.elements['root/db/mysql/mobp/dbname'].text

MASTER_TABLE = settings.elements['root/db/mysql/mobp/master/tablename'].text

MARKOV_TABLE = settings.elements['root/db/mysql/mobp/markov/tablename'].text
FIRST_COLUMN = settings.elements['root/db/mysql/mobp/markov/first'].text
SECOND_COLUMN = settings.elements['root/db/mysql/mobp/markov/second'].text
THIRD_COLUMN = settings.elements['root/db/mysql/mobp/markov/third'].text
FOURTH_COLUMN = settings.elements['root/db/mysql/mobp/markov/fourth'].text
