require 'rexml/document'

ADMIN_SCREEN_NAME = 'cohalz'
BOT_SCREEN_NAME = 'MOBP_'

settings = REXML::Document.new(open("#{Dir.home}/settings/settings.xml"))

YOUR_CONSUMER_KEY = settings.elements['root/twitter/mobp/consumerKey'].text
YOUR_CONSUMER_SECRET = settings.elements['root/twitter/mobp/consumerSecret'].text
YOUR_OAUTH_TOKEN = settings.elements['root/twitter/mobp/accessToken'].text
YOUR_OAUTH_TOKEN_SECRET = settings.elements['root/twitter/mobp/accessTokenSecret'].text
DBPASSWD = settings.elements['root/db/mysql/pass'].text
