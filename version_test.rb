load "lib/rwikibot.rb"


bot = RWikiBot.new "Test", "Robot", "test", "http://eddieroger.com/wiki/api.php", "wiki_wiki_"

bot.login
puts bot.watchlist