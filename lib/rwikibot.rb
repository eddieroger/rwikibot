# RWikiBot 1.1# 
# This is a framework upon which to create MediaWiki Bots. It provides a set of methods to acccess MediaWiki's API and return information in 
# various forms, depending on the type of information returned. By abstracting these methods into a Bot object, cleaner script code can be
# written later. Furthermore, it facilitates the updating of the API without breaking old bots. Last, but not least, its good to abstract. 
# 
# 
# Author:: Edwin Sidney Roger (mailto:eddieroger@gmail.com)
# Copyright:: Copyright (c) 2007 Edwin Sidney Roger
# License:: GNU/GPL 2.0
require 'net/http'
require 'uri'
require 'cgi'
require 'exceptions'

require 'rubygems'
require 'xmlsimple'

#This is the main bot object. The goal is to represent every API method in some form here, and then write seperate, cleaner scripts in individual bot files utilizing this framework. Basically, this is an include at best.
class RWikiBot

  
	attr_accessor :http, :config, :botname
  
  def initialize ( username = 'RWikiBot', password = 'rwikibot', api_path = 'http://localhost:8888/wiki/api.php', domain = '')


    @config = Hash.new
    
    # This had to come back since I was having config loading issues when being called from MediaWiki
    @config['username'] = username
    @config['password'] = password
    @config['api_path'] = api_path
    @config['domain']   = domain
    @config['cookies']	= ""
    @config['logged_in'] = FALSE
    @config['uri'] = URI.parse(@config.fetch('api_path'))
    
    @http = Net::HTTP.new(@config.fetch('uri').host, @config.fetch('uri').port)

  end

  # Login
  #
  # This is the method that will allow the bot to log in to the wiki. Its not always necessary, but bots need to log in to save changes or retrieve watchlists. 
  #
  # No variables are accepted and none are returned.
  def login
    
    post_me = {'lgname'=>@config.fetch('username'),'lgpassword'=>@config.fetch('password')}
    if @config.has_key?('domain') && (@config.fetch('domain') != nil)
      post_me['lgdomain'] = @config.fetch('domain')
    end
    
    #Calling make_request to actually log in
    login_result = make_request('login', post_me)	
	
    # Now we need to changed some @config stuff, specifically that we're logged in and the variables of that
    # This will also change the make_request, but I'll comment there
    if login_result.fetch('result') == "Success"
      # All lg variables are directly from API and stored in config that way
      @config['logged_in'] 		= TRUE
      @config['lgusername'] 	= login_result.fetch('lgusername')
      @config['lguserid'] 		= login_result.fetch('lguserid')
      @config['lgtoken'] 		= login_result.fetch('lgtoken')
	  @config['cookieprefix'] 	= login_result.fetch('cookieprefix')
      puts "You are now logged in as: " + @config['lgusername'] 
      return TRUE
    else 
      puts "Login railed."
	  login_result.each_pair do |key, value|
		puts "#{key} => #{value}"
	  end
	  return FALSE
    end
    
  end
  
  # Query - Title Normalization
  # http://www.mediawiki.org/wiki/API:Query#Title_Normalization_.28done.29
  #
  # This little ditty returns a normalized version of the title passed to it. It is super useful because it will normalize an otherise poorly entered title, but most importantly it will let us know if an article exists or not by if it is able to normalize. 
  #
  # INPUT:: Titles, either singular or pipe-delimited.
  # OUTPUT:: An array of normalized hashes.
  def normalize (title)
    
    # Prepare the request
    post_me = {'titles' => title}
    
    #Make the request
    normalized_result = make_request('query', post_me)    
    
    return normalized_result.fetch('pages')
  
  end
  
  # Query - Redirects
  # http://www.mediawiki.org/wiki/API:Query#Redirects_.28done.29
  #
  # This will return any redirects from an article title so that you know where it ends. Useful to check for redirects, but mostly here for completeness of the framework.
  #
  # INPUT:: A string of pipe-delimited titles ('Apple|Baseball|Car port'), and an optional hash of API acceptable values.
  # OUTPUT:: An array of redirects.
  def redirects (title, options = nil)
    
    # Prepare the request
    post_me = {'titles' => title, 'redirects'=>'', 'prop' => 'info'}
    
    if options != nil
      options.each_pair do |key, value|
        post_me[key] = value
      end
    end
    
    #Make the request
    redirects_result = make_request('query', post_me)
    
    return redirects_result.fetch('pages')
  
  end
  
  
  # Watchlist
  #
  # This method will get the watchlist for the bot's MediaWiki username. This is really onlu useful if you want the bot to watch a specific list of pages, and would require the bot maintainer to login to the wiki as the bot to set the watchlist. 
  #
  # INPUT:: Options is a hash of API allowed fields that will be passed.
  #
  # OUTPUT:: Returns an array of hashes.
  def watchlist (options=nil)
    # Get the bot's watchlist
    post_me = {'list'=>'watchlist'}
    
    if options != nil
      options.each do |key, value|
        post_me[key] = value
      end
    end
    
    # Make the request
    watchlist_result = make_request('query', post_me)
    
    #Process into a Hash for return
    puts watchlist_result
    return watchlist_result.fetch('watchlist')
    
  end
  
  # Query
  #
  # This method will return Wiki-wide recent changes, almost as if looking at the Special page Recent Changes. But, in this format, a bot can handle it. Also we're using the API. And bots can't read.
  # 
  # INPUT:: A hash of API-allowed keys and values. Default is same as API default.
  # PARAMETERS:: letype (flt), lefrom (paging timestamp), leto (flt), ledirection (dflt=older), leuser (flt), letitle (flt), lelimit (dflt=10, max=500/5000)
  # OUTPUT:: An array of hashes.
  def recent_changes (options=nil)
    
    # This will allow any given bot to get recent changes. Then act on it. But that's another method
    # TODO - Persistent timestamp storage
    
    post_me = {"list" => "recentchanges"} #, 'rclimit' => '5000'}
    if options != nil
      options.each do |key, value|
        post_me[key] = value
      end
    end
    
    # Make the request
    recentchanges_result = make_request('query' , post_me)

    # Done. Return the results
    return recentchanges_result.fetch('recentchanges')
    
  end
  
  # List
  #
  # This will reutrn a list of the most recent log events. Useful for bots who want to validate log events, or even just a notify bot that checks for events and sends them off. 
  #
  # INPUT:: A hash of API-allowed keys and values. Default is same as API default.
  #
  # OUTPUT:: An array of hashes containing log events.
  def log_events (options = nil)
    
    ##@wikibotlogger.debug "LOG EVENTS - Preparing request information..."
    
    # Make the request
    post_me = {"list" => "logevents"}
    
    if options != nil
      options.each_pair do |key, value|
        post_me[key] = value
      end
    end
    
    #Make the request!
    logevents_result = make_request('query', post_me)
    
    # Process results    
    return logevents_result.fetch('logevents')

  end
    
  
  # Query
  #
  # This is a lot like REDIRECTS method, except its just a true/false to validate whether or not an article is a redirect. We could write the logic into the final bot app, but we're awesome and we include a quicky method.
  #
  # INPUT:: Title (please, just one!)
  # OUTPUT:: True/False
  def redirect? (title)
    
    # Prepare the request
    post_me = {'titles' => title, 'redirects'=>'', 'prop' => 'info'}
    
    
    #Make the request
    redirects_result = make_request('query', post_me)
    
    return redirects_result.has_key?('redirects')
    
  end
  
  # Meta
  #
  # This is the only meta method. It will return site information. I chose not to allow it to specify, and it will only return all known properties. 
  # api.php?action=query&meta=siteinfo&siprop=general|namespaces
  #
  # INPUT:: siprop is either 'general' or 'namespaces'. 
  #
  # OUTPUT:: A hash of values about site information.
  def site_info (siprop = 'general')
    
    ##@wikibotlogger.debug "SITE INFO - Preparing request information..."
    
    # Make the request
    post_me = {"meta" => "siteinfo" , "siprop" => siprop}
    
    
    #Make the request!
    siteinfo_result = make_request('query', post_me)
    
    # Process results
    
    if siprop == 'general'
      return siteinfo_result.fetch('general')
    else
      return siteinfo_result.fetch('namespaces')
    end
    
  end
  
  
  # List
  #
  # This will return a list of all pages in a given namespace. It returns a list of pages in with the normalized title and page ID, suitable for usage elsewhere. Accepts all parameters from the API in Hash form.
  # Default is namespace => 0, which is just plain pages. Nothing 'special'. 
  # Also note that if the username the Bot uses is not of type Bot in the Wiki, you will be limited to 50 articles. Also log in, or you get an error.
  #
  # INPUT:: A hash of API-allowed keys and values. Default is same as API default.
  # PARAMETERS:: apfrom (paging), apnamespace (dflt=0), apredirect (flt), aplimit (dflt=10, max=500/5000)
  # OUTPUT:: An array of hashes with information about the pages. 
  def all_pages (options = nil)
    
    # This will get all pages. Limits vary based on user rights of the Bot. Set to bot.
    ##@wikibotlogger.debug "ALL PAGES - Preparing request information..."
    post_me = {'list' => 'allpages', 'apnamespace' => '0', 'aplimit' => '5000'}
    
    
    if options != nil
      options.each_pair do |key, value|
        post_me[key] = value
      end
    end
    
    #make the request
    allpages_result = make_request('query', post_me)
    
    return allpages_result.fetch('allpages')
    
  end

  # List
  #
  # This method fetches any article that links to the article given in 'title'. Returned in alphabetical order.
  # 
  # INPUT:: A normalized article title or titles (pipe delimited), and a hash of API-allowed keys and values. Default is same as API default.
  # PARAMETERS:: blfrom (paging), blnamespace (flt), blredirect (flt), bllimit (dflt=10, max=500/5000)
  # OUTPUT:: An array of hashes with backlinked articles. 
  def backlinks (titles, options = nil)
    
    # This will get all pages. Limits vary based on user rights of the Bot. Set to bot.
    post_me = {'list' => 'backlinks', 'titles' => "#{title}" }
     
    
    if options != nil
      options.each_pair do |key, value|
        post_me[key] = value
      end
    end
    
    #make the request
    backlinks_result = make_request('query', post_me)
    return backlinks_result.fetch('backlinks')
    
  end
  
  # List
  #
  # This method pulls any page that includes the template requested. Please note - the template must be the full name, like "Template:Disputed" or "Template:Awesome". Just one, please.
  # 
  # INPUT:: A normalized template title, and a hash of API-allowed keys and values. Default is same as API default.
  # PARAMETERS:: eifrom (paging), einamespace (flt), eiredirect (flt), eilimit (dflt=10, max=500/5000)
  # OUTPUT:: An array of hashes with articles using said template. 
  def embedded_in (title, options = nil)
    
    # This will get all pages. Limits vary based on user rights of the Bot. Set to bot.
    ##@wikibotlogger.debug "EMBEDDED IN - Preparing request information..."
    post_me = {'list' => 'embeddedin', 'titles' => "#{title}" }
     
    
    if options != nil
      options.each_pair do |key, value|
        post_me[key] = value
      end
    end
    
    #make the request
    embeddedin_result = make_request('query', post_me)
    return embeddedin_result.fetch('embeddedin')
    
  end
  
  # List
  #
  # A whole lot like EMBEDDED_IN, except this bad boy has the job of handling Image: instead of Template:. I guess bots may want to watch images. Its really for completeness. But, people do do things with pictures. Maybe it handles Media: as well, but no promisesses.
  # 
  # INPUT:: A normalized image title, and a hash of API-allowed keys and values. Default is same as API default.
  # PARAMETERS:: iefrom (paging), ienamespace (flt), ielimit (dflt=10, max=500/5000)
  # OUTPUT:: An array of hashes with images page links
  def image_embedded_in (title, options = nil) 
   
     # This will get all pages. Limits vary based on user rights of the Bot. Set to bot.
     ##@wikibotlogger.debug "IMAGE EMBEDDED IN - Preparing request information..."
     post_me = {'list' => 'embeddedin', 'titles' => "#{title}" }
    
   
     if options != nil
       options.each_pair do |key, value|
         post_me[key] = value
       end
     end
   
     #make the request
     imageembeddedin_result = make_request('query', post_me)
     return imageembeddedin_result.fetch('embeddedin')
   
   end
    
  # Prop = Info
  #
  # I decided to split this up since I wanted to normalize the bot framework as much as possible, or in other words, make it as easy to use as possible. I think the sacrifice of more methods is worth having more English looking code. Its the Ruby way. 
  # Info will return information about the page, from namespace to normalized title, last touched, etc. 
  #
  # INPUT:: This method only takes titles, but will accept a pipe-delimited string. Ex: "Apple|Baseball|Horse|Main Page"
  # 
  # OUTPUT:: An array of hashes.
  def info (titles)
    
    # Basic quqery info
    post_me = {"prop" => "info", 'titles' => titles}
    
    # Make the request
    info_result = make_request('query', post_me)
    
    # Result processing    
    return info_result.fetch('pages')
  
  end
  
  # Prop - Revisions
  #
  # This is the main way of accessing content and page specific information from the wiki. It has multiple uses as described in the API, Its also considerably more complex than the other methods. Enjoy it.
  # A final note - I'd really be familiar with this method in the API since I've spent a lot of time trying to figure it out myself.
  #
  # Please be sure to add the RVPROP key at least, otherwise you'll just get the basic information of revid, oldid and pageid. Boring.
  #
  # INPUT:: A string of article titles (pipe-delimited), and a hash of API-allowed keys and values. Default is same as API default.
  #
  # OUTPUT:: An array of hashes. 
  def revisions(titles, options = nil)
    
    # Prepare the request! Notify the logger!
    post_me = {'prop' => 'revisions', 'titles' => titles}
    
    # Handle any additional options
    if options != nil
      options.each_pair do |key, value|
        post_me[key] = value
      end
    end
    
    # Make the request. Becuase we care.
    revisions_result = make_request('query', post_me )
    
    #Process the results    
    return revisions_result.fetch('pages')
    
  end
  
  # Meta
  #
  # This is the only meta method. It will return site information. I chose not to allow it to specify, and it will only return all known properties. 
  # api.php?action=query&meta=siteinfo&siprop=general|namespaces
  #
  # INPUT:: siprop is either 'general' or 'namespaces'. 
  #
  # OUTPUT:: A hash of values about site information.
  def site_info (siprop = 'general')
    
    ##@wikibotlogger.debug "SITE INFO - Preparing request information..."
    
    # Make the request
    post_me = {"meta" => "siteinfo" , "siprop" => siprop}
    
    
    #Make the request!
    siteinfo_result = make_request('query', post_me)
    
    # Process results
    
    if siprop == 'general'
      return siteinfo_result.fetch('general')
    else
      return siteinfo_result.fetch('namespaces')
    end
    
  end
  
  # The point of this method is to iterate through an array of hashes, which most of the other methods return, and remove multiple instances of the same wiki page. We're more than often only concerned with the most recent revision, so we'll delete old ones. 
  #
  # Hashes don't respond to the the Array.uniq method. So this is the same-ish
  # INPUT:: An array of hashes. 
  # OUTPUT:: An array of hashes that are unique. 
  def make_unique(array)
    
    test_array = array
    count = 0
  
    # First, let's make one big loop to go through each item in the array. 
    array.reverse.each do |current_item|
      
      # Now, let's loop double time. 
      test_array.each do |test_item|
        
        # Some comparisons...
        if (current_item.fetch('title') == test_item.fetch('title') && current_item.fetch('revid') > test_item.fetch('revid') )
          
          # At this point, current is the same article as test, and current is newer. Delete test
          array.delete(test_item)
          count += 1
          
        end
      end
    end
    
    puts "Deleted #{count} items."
    
    return array
  end
  
  # This is a little something I cooked up because it seems like a totally logical thing for bots to want to do. Basically, you feed it a page title - any you want (that's the point) - and it returns TRUE or FALSE if the page exists inside the wiki. Technically, it pulls an attribute "missing", and in its presense, reports TRUE since the page is fake.
  # That's something a bot would want to do, right?
  #
  # INPUT:: A title. Just one! 
  #
  # OUTPUT:: TRUE/FALSE, depending on which is correct
  def page_exists? (title)
    
    # Prepare the request
    ##@wikibotlogger.debug "PAGE EXISTS? - Preparing request information..."
    post_me = {'titles' => title}
    
    #Make the request
    page_exists_result = make_request('query', post_me)
    
    if page_exists_result.fetch('pages')[0].has_key?('missing')
      return false
    else
      return true
    end
    
  end
  
  # This method will return the version of the MediaWiki server. This is done by parsing the version number from the generator attribute of the the site_info method. Useful? Yes - maybe yout bot is only compatible with MediaWiki 1.9.0 depending on what methods you use. I like it, anwyay.
  #
  # INPUT:: None
  #
  # OUTPUT:: Version number
  def version
    # Almost TOO simple... 
    return site_info.fetch('generator').split(' ')[1]
  end
  
  # This method turns a pageid into a title. Why? Because I've written the rest of the methods title-centric, and I want to keep it that way. But, sometiumes you get a list of ids and not titles, and we have to do something about that.
  #
  # INPUT:: PageID - just one!
  # OUTPUT:: A title in string form. 
  def pageid_to_title(id)
    
      # Prepare the request! Notify the logger!
      post_me = {'prop' => 'info', 'pageids' => id}

      # Make the request. Becuase we care.
      id_result = make_request('query', post_me )

      #Process the results
      return id_result.fetch('pages')[0].fetch('title')

  end
  
  # The following methods are private and should only be called internally. 
  #
  # So don't screw around in here. Its like a house of cards, people.
  private 
  
  # Make Request is a method that actually handles making the request to the API. Since the API is somewhat standardized, this method is able to accept the action and a hash of variables, and it handles all the fun things MediaWiki likes to be weird over, like cookies and limits and actions. Its very solid, but I didn't want it public because it also does some post processing, and that's not very OO. 
  def make_request (action, post_this)
     
    #Housekeeping. We need to add format and action to the request hash
    post_this['format'] = 'xml'
    post_this['action'] = action
    
    # Despite me coding this the way the API doc says, it doesn't work. Commenting out until clarity is returned. 
    if @config.fetch('logged_in')
      post_this['lgusername'] = @config.fetch('lgusername')
      post_this['lgtoken'] = @config.fetch('lgtoken')
      post_this['lguserid'] = @config.fetch('lguserid')
     end
  
    #change - preparing a POST string instead of hash. 
    post_string = ''
    post_this.each_pair do |key, value|
      post_string << "#{key}=#{value}&"
    end
  
    #Send the actual request with exception handling
    
    if (@config['logged_in'])
      cookies = "#{@config['cookieprefix']}UserName=#{@config['lgusername']}; #{@config['cookieprefix']}UserID=#{@config['lguserid']}; #{@config['cookieprefix']}Token=#{@config['lgtoken']}"
    else
      cookies = ""
    end
    
    #puts post_string
	headers =  {
		'User-agent'=>'RWikiBot/1.1', 
		'Cookie' => cookies
	}
    resp = @http.post( @config.fetch('uri').path , post_string ,  headers )
    return_result = XmlSimple.xml_in(resp.body, { 'ForceArray' => false} )	
	
    if return_result.has_key? action
      return_result = return_result.fetch(action)
    else
      raise MediaWikiException.new(return_result.fetch('error'))
    end
    
    return return_result 
  end
  
end