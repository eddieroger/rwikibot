# This is a framework upon which to create MediaWiki Bots. It provides a set of methods to acccess MediaWiki's API and return information in 
# various forms, depending on the type of information returned. By abstracting these methods into a Bot object, cleaner script code can be
# written later. Furthermore, it facilitates the updating of the API without breaking old bots. Last, but not least, its good to abstract. # 
# 
# Author:: Eddie Roger (mailto:eddieroger@gmail.com)
# Copyright:: Copyright (c) 2008 Eddie Roger
# License:: GNU/GPL 2.0
require 'net/http'
require 'uri'
require 'cgi'
require 'errors'

require 'rubygems'
require 'xmlsimple'

#This is the main bot object. The goal is to represent every API method in some form here, and then write seperate, cleaner scripts in individual bot files utilizing this framework. Basically, this is an include at best.
class RWikiBot

  def initialize ( username = 'rwikibot', password = '', api_path = 'http://www.rwikibot.net/wiki/api.php', domain = '')


    @config = Hash.new
    
    # This had to come back since I was having config loading issues when being called from MediaWiki
    @config['username'] = username
    @config['password'] = password
    @config['api_path'] = api_path
    @config['domain']   = domain
    @config['cookies']	= ""
    @config['logged_in'] = FALSE
    @config['uri'] = URI.parse(@config.fetch('api_path'))
    
	  # This has to be last methinks
	  @config['api_version'] = version.to_f

  end
  
  # logged_in?
  #
  # A quick (and public) method of checking whether or not we're logged in, since I don't want @config exposed
  #
  # INPUT:: None
  # OUTPUT:: boolean
  def logged_in?
    return @config['logged_in']
  end

  # Login
  #
  # This is the method that will allow the bot to log in to the wiki. Its not always necessary, but bots need to log in to save changes or retrieve watchlists. 
  #
  # No variables are accepted. Returns a Result object of true or false
  def login
    require("login",0,0)
    
    post_me = {'lgname'=>@config.fetch('username'),'lgpassword'=>@config.fetch('password')}
    if @config.has_key?('domain') && (@config.fetch('domain') != nil)
      post_me['lgdomain'] = @config.fetch('domain')
    end
    
    #Calling make_request to actually log in
    login_result = make_request('login', post_me)	
    
    # Now we need to changed some @config stuff, specifically that we're logged in and the variables of that
    # This will also change the make_request, but I'll comment there
    if login_result['result'] == "Success"
      # All lg variables are directly from API and stored in config that way
      @config['logged_in'] 		  = TRUE
      @config['lgusername'] 	  = login_result.fetch('lgusername')
      @config['lguserid'] 		  = login_result.fetch('lguserid')
      @config['lgtoken'] 		    = login_result.fetch('lgtoken')
      @config['_session']       = login_result.fetch('sessionid')
	    @config['cookieprefix'] 	= login_result.fetch('cookieprefix') 
      # puts "You are now logged in as: #{@config['lgusername']}"
      return true
    else 
      # puts "Error logging in. Error was: "
      raise LoginError, "#{login_result['result']}: #{login_result['details']}"
	  
	  end
    
  end
  
  # Query - Title Normalization
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

  	return normalized_result.get_result.fetch('pages')
	  
  end
  
  # Query - Redirects
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
    
    return redirects_result.get_result.fetch('pages')
  
  end
  
  # is_redirect?
  #
  # Tests to see if a given page title is redirected to another page. Very Ruby.
  #
  # INPUT:: A string page title
  # OUTPUT:: bool T/F 
  def is_redirect? (title)
    
    post_me = {'titles' => title, 'redirects'=>'', 'prop' => 'info'}

    result = make_request('query', post_me)
    
    if (result.success?) && (result.get_result.has_key?("redirects"))
      return true
    else
      return false
    end
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
    if watchlist_result.success?
      return watchlist_result.get_result.fetch('watchlist')
    else
      return watchlist_result.get_message 
    end
    
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
    
    post_me = {"list" => "recentchanges", 'rclimit' => '5000'}
    if options != nil
      options.each do |key, value|
        post_me[key] = value
      end
    end
    
    # Make the request
    recentchanges_result = make_request('query' , post_me)

    # Done. Return the results
    if recentchanges_result.success?
      return recentchanges_result.get_result.fetch('recentchanges').fetch('rc')
    else
      return recentchanges_result.get_message
    end
    
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
    if logevents_result.success? 
      return logevents_result.get_result.fetch('logevents')
    else
      return logevents_result.get_message
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
    
    if allpages_result.success?
      return allpages_result.get_result.fetch('allpages')['p']
    else
      return allpages_result.get_message
    end
    
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
    
    if backlinks_result.success?
      return backlinks_result.get_result.fetch('backlinks')
    else
      return backlinks_result.get_message
    end
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
    
    if embeddedin_result.success?
      return embeddedin_result.get_result.fetch('embeddedin')
    else
      return embeddedin_result.get_message
    end
    
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
     
     if imageembeddedin_result.success?
       return imageembeddedin_result.get_result.fetch('embeddedin')
     else
       return imageembeddedin_result.get_message
      end
   
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
    if info_result.success? 
      return info_result.get_result.fetch('pages').fetch('page')
    else
      return info_result.get_message
    end
  
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
    if revisions_result.success?
      return revisions_result.get_result.fetch('pages')
    else
      return revisions_result.get_message
    end
    
  end
  
  # Prop - Revisions - Custom
  #
  # This will get only the content of the article. It is a modification of revisions to specifically pull the content. I thought it would be useful.
  #
  # INPUT :: An article title
  # OUTPUT :: Content! IN STRING FORM! Please note that. If you want more than just a string of content, use revisions
  def get_content(titles, options = nil)
    
    post_me = {'prop' => 'revisions', 'titles' => titles, 'rvprop' => 'content'}
    
    # Handle any additional options
    if options != nil
      options.each_pair do |key, value|
        post_me[key] = value
      end
    end
    
    # Why waste a trip if the article doesn't exist?
    # OK, it's still a trip, but error prevention is my name.
    if page_exists?(titles) == false
      return "Article \"#{titles}\" does not exist."
    end
    
    # Make the request. Becuase we care.
    revisions_result = make_request('query', post_me )
    
    #Process the results    
    if revisions_result.success?
      return revisions_result.get_result.fetch('pages').fetch('page').fetch('revisions').fetch('rev')
    else
      return revisions_result.get_message
    end
    
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
  
  # Meta
  #
  # Get information about the current user
  #
  # INPUT::  uiprop - What pieces of information to include
  #
  # OUTPUT:: A hash of values about the user.
  def user_info (uiprop = nil)
        
    # Make the request
    post_me = {"meta" => "userinfo" }
    post_me['uiprop'] =  uiprop unless uiprop.nil?
    
    
    #Make the request!
    userinfo_result = make_request('query', post_me)
    
    # Process results
    if userinfo_result.success?
      return userinfo_result.get_result.fetch('userinfo')
    else
      return userinfo_result.get_message
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
    post_me = {'titles' => title}
    
    #Make the request
    page_exists_result = make_request('query', post_me)
    
    if page_exists_result.success?
      # if page_exists_result.get_result.fetch('pages')[0].has_key?('missing')
      #   return false
      # else
      #   return true
      # end
      if page_exists_result.get_result.fetch('pages').fetch('page').has_key?('missing')
        return false
      else
        return true
      end
    else
      return page_exists_result.get_message
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
      if id_result.success?
        return id_result.get_result.fetch('pages').fetch('page').fetch('title')
      else
        return id_result.get_message
      end

  end
  
  # This method is used to edit pages. Not much more to say about it. Be sure you're logged in and got a token (get_token). Options is an array (or hash) of extra values allowed by the API. 
  #
  # Aliased by create_page
  #
  # INPUT:: title, token, content, summary, options
  # OUTPUT:: Boolean (T/F) on success or error message if save attempt fails
  def edit_page(title, content, summary = nil, options = nil)
  
    # this is necessary since create_page can pass nil, and if the user enters options, they can enter nil as well. 
    if summary.nil?
      summary = "Change made by [[User:Rwikibot|RWikiBot]]"
    end
      
	  post_me = {
	    'text' => "#{content}" , 
	    'token' => get_token(title, "edit") , 
	    'title' => "#{title}" , 
      'lgtoken' => @config['lgtoken'] ,
	    'summary' => "#{summary}" ,
	    'edittime' => Time.now.strftime("%Y%m%d%H%M%S") ,
	    'userid' => @config.fetch('lguserid') , 
	  }
	  
	  if options.nil? == FALSE
	    options.each do |key, value|
	      post_me[key] = value
	    end
	  end
	  edit_result = make_request('edit', post_me)
	  if edit_result.success?
      if edit_result.get_result.fetch('result') == "Success"
        return true
      else
        return false
      end
    else
      return edit_result.get_message
    end
  end
  
  # This method is a wrapper for edit page. The functionality is the same, but semanticly they are different, in that you create new pages but edit existing ones. So, ease of use. Use edit - that's the better function.
  #
  # For documentation, see edit_page
  def create_page(title, content, summary = nil, options = nil)
    edit_page(title, content, summary, options)
  end
  
  # This method will let you move a page from one name to another. A move token is required for this to work. Keep that in mind. (get_token much?)
  #
  # http://www.mediawiki.org/wiki/API:Edit_-_Move
  #
  # INPUT:: from, to, token, reason, movetalk (T/F), noredirect (T/F)
  # OUTPUT:: Boolean (T/F) on success or error message
  def move_page(from, to, reason = "Moved by [[User:Rwikibot|RWikiBot]]", movetalk = true, noredirect = false)
    
    # it's an extra call, but I'd rather catch an error early. besides, bandwidth isn't cheap.
    if page_exists?(from) == false
      return "Move failed. Article \"#{from}\" doesn't exist."
    end
    
    if reason == nil
      reason = "Moved by RWikiBot"
    end
    
    post_me = {
	    'from'    => "#{from}" , 
	    'to'      => "#{to}" ,
	    'token'   => get_token(from, 'move') , 
	    'reason'  => "#{reason}" , 
	  }
	  
	  # These ifs are necessary because they should only be part of post_me if the passed vars are true (which they are by default)
	  if movetalk
	    post_me['movetalk'] = ''
	  end
	  if noredirect
	    post_me['noredirect'] = ''
	  end
	  
	  move_result = make_request('move', post_me)
	  if move_result.success?
      return move_result.get_result
    else
      return move_result.get_message
    end
  end
  
  # Rollback does what it says - rolls back an article one version in the wiki. This is a function that requires not only a token, but a previous user. 
  # Please note that you can only rollback one version. This is the same functionality as available through the web interface and was intentionally implemented this way in the API.
  # http://www.mediawiki.org/wiki/API:Edit_-_Rollback
  #
  # INPUT:: title, summary, markbot (T/F) (token and last user handled by method)
  # OUTPUT:: Hash of MW result
  def rollback_page (title, summary="Rolled back by RWikiBot}", markbot=false)
    
    if page_exists?(title) == false
      return "Rollback failed. Article \"#{title}\" doesn't exist."
    end
    
    temp_token = get_token(title,"rollback")
    
    post_me = {
      'title'     => title,
      'token'     => temp_token['token'],
      'user'      => temp_token['user'],
      'summary'   => summary
    }
    
    if markbot
      post_me['markbot'] = ''
    end
    
    rollback_result = make_request('rollback', post_me)
    
    if rollback_result.success?
      return rollback_result.get_result
    else
      return rollback_result.get_message
    end
    
  end
  
  # If you have to ask what this method does, don't use it. Seriously, use with caution - this method does not have a confirmation step, and deleted (while restorable) are immediate.
  #
  # INPUT:: title, reason
  # OUTPUT:: title and reason or error message
  def delete_page(title, reason="Deleted by RWikiBot")
    
    if page_exists?(title) == FALSE
      return "Article \"#{title}\" does not exist. Delete failed. "
    end
    
    post_me = {
      'title'     => title ,
      'token'     => get_token(title,'delete') ,
      'reason'    => reason
    }
    
    delete_result = make_request('delete',post_me)
    
    if delete_result.success?
      return delete_result.get_result
    else
      return delete_result.get_message
    end
    
  end
  
  # The following methods are private and should only be called internally. 
  # So don't screw around in here. Its like a house of cards, people.
  private 
  
  # Require
  #
  # This allows us to ensure that the version of the API supports the method we're about ot run. Good call, buddy. 
  #
  # INPUT:: major, minor
  # OUTPUT:: Well, none, but it raises an error if not. 
  def require(method, major, minor)
    maj, min = @config['api_version'].to_s.gsub(/[^0-9\.|\s]/,'').split(".")
    if (major.to_i > maj.to_i) || (minor.to_i > min.to_i)
      raise VersionTooLowError, "The version of the API you are using doesn't support #{method}"
    end
    true
  end
  
  # This method should universally return tokens, just give title and type. You will receive a token string (suitable for use in other methods), so plan accordingly.
  #
  # Use an edit token for both editing and creating articles (edit_article, create_article). For rollback, more than just a token is required. So, for token=rollback, you get a hash of token|user. Just the way it goes.
  #
  # INPUT:: title, (edit|move|rollback)
  # OUTPUT:: A stringified token (for rollback - a hash of token,user)
  def get_token(title, intoken)
    if intoken.downcase == 'rollback'
      #specific to rollback
      post_me = {
        'prop'    => 'revisions' ,
        'rvtoken' => intoken ,
        'titles'  => title
      }
    else
  	  post_me = {
  	    'prop'    => 'info', 
  	    'intoken' => intoken, 
  	    'titles'  => title
  	  }
	  end
	  raw_token = make_request('query', post_me)
	  if intoken.downcase == 'rollback'
      # Damn this decision to make rollback special!. Wasn't mine, I just haev to live by it.
      if raw_token.success?
        token2 = raw_token.get_result.fetch('pages').fetch('page').fetch('revisions').fetch('rev')
        return {'token' => token2.fetch('rollbacktoken') , 'user' => token2.fetch('user')}
      else
        return raw_token.get_message
      end
  	else
  	  if raw_token.success?
  	    return raw_token.get_result.fetch('pages').fetch('page').fetch("#{intoken}token")
  	  else
  	    return raw_token.get_message
  	  end
  	end
  end
  
  # Check Version is a private method that will be run at the start of every method to make sure the version of the API we're using is compliant with the method. It'll take a little work on my part, but it'll make developing against two different wikis easier. 
  def check_version (min)
  	if min > @config['api_version']
  		
  		puts "The version of the API you are using does not support this method. Please upgrade your version of MediaWiki."
  		return false
  	else
  		return true
  	end
  end
  
  # Make Request is a method that actually handles making the request to the API. Since the API is somewhat standardized, this method is able to accept the action and a hash of variables, and it handles all the fun things MediaWiki likes to be weird over, like cookies and limits and actions. Its very solid, but I didn't want it public because it also does some post processing, and that's not very OO. 
  def make_request (action, post_this)
    
      #Housekeeping. We need to add format and action to the request hash
      post_this['format'] = 'xml'
      post_this['action'] = action

      if (@config['logged_in'])
        cookies = "#{@config['cookieprefix']}UserName=#{@config['lgusername']}; #{@config['cookieprefix']}UserID=#{@config['lguserid']}; #{@config['cookieprefix']}Token=#{@config['lgtoken']}; #{@config['cookieprefix']}_session=#{@config['_session']}"
      else
        cookies = ""
      end

      headers =  {
        'User-agent'=>'bot-RWikiBot/1.1', 
        'Cookie' => cookies
      }
      

      request = Net::HTTP::Post.new(@config.fetch('uri').path, headers)
      request.set_form_data(post_this)
      response = Net::HTTP.new(@config.fetch('uri').host, @config.fetch('uri').port).start {
        |http| http.request(request)
      }

      return_result = XmlSimple.xml_in(response.body, { 'ForceArray' => false })	
      puts return_result
      
      # Extra cookie handling. Because editing will be based on session IDs and it generates a new one each time until you start responding. I doubt this will change.
      if (response.header['set-cookie'] != nil)
        @config['_session'] = response.header['set-cookie'].split("=")[1]
      end
      
      # Finish up
        return_result.fetch(action) 
  end
  
end

# Class Result
#
# @code       = FALSE     # TRUE/FALSE
# @message    = ""        # Message about result (errors, other statements)
# @result     = Hash.new  # MediaWiki's return result
#
# I'm going to try to standardize results to make programming these methods easier. That way, we can always have a success/failure indicator and a message, and the object of return.
class Result  

  def initialize (code, message = nil, result = nil)
    @code     = code
    @message  = message
    @result   = result
  end
  
  def success? 
    return @code
  end
  
  def get_result
    @result
  end
  
  def get_message
    @message
  end
  
  def to_s
    "CODE: #{@code}\nMESSAGE: #{@message}\nRESULT: #{@result}"
  end
  
end

class Hash
  def to_s
    out = "{"
    self.each do |key, value|
      out += "#{key} => #{value},"
    end
    out = out.chop
    out += "}"
  end
end
