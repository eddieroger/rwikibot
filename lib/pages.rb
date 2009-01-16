## This class defines a MediaWiki page. Think of it like this: the bot handles
## site related stuff, but to take action on a page, you need a page object.
require 'rwikibot'
require 'errors'

module Pages
  include RWBErrors

  class Page
    attr_reader :title, :namespace, :new, :length, :counter, :lastrevid, :missing

    # Creates a new Page object.
    def initialize(bot, title='')
      @bot = bot
      #puts @bot.config
      
      info = info(title)
      @title      = info['title']
      @namespace  = info['ns']
      @new        = info.has_key?('new')
      @length     = info['length']
      @counter    = info ['counter']
      @lastrevid  = info['lastrevid']
      @missing    = info.has_key?('missing')
    end
    
    # I used to have an exists method (page_exists), but I got rid of it in 2.0, but I'm bringing it back. 
    def exists?
      if @missing
        return false
      else
        return true
      end
    end

    # This will get only the content of the article. It is a modification of
    # revisions to specifically pull the content. I thought it would be
    # useful.
    def content(options=nil)
      post_me = {'prop' => 'revisions', 'titles' => @title, 'rvprop' => 'content'}

      post_me.merge!(options) if options

      revisions_result = @bot.make_request('query', post_me )
      revisions_result.fetch('pages').fetch('page').fetch('revisions').fetch('rev')
    end

    # If you have to ask what this method does, don't use it. Seriously, use
    # with caution - this method does not have a confirmation step, and
    # deleted (while restorable) are immediate.
    def delete(reason="Deleted by RWikiBot")
      raise RWBErrors::VersionTooLowError unless @bot.meets_version_requirement(1,12)
      raise RWBErrors::NotLoggedInError unless @bot.logged_in?

      post_me = {
        'title'     => @title ,
        'token'     => get_token('delete') ,
        'reason'    => reason
      }

      @bot.make_request('delete', post_me)
    end

    # This method fetches any article that links to the article given in
    # 'title'. Returned in alphabetical order.
    def backlinks (titles, options = nil)
      raise VersionTooLowError unless meets_version_requirement(1,9)

      post_me = {'list' => 'backlinks', 'titles' => "#{title}" }

      post_me.merge!(options) if options

      backlinks_result = make_request('query', post_me)

      backlinks_result.success? ?
        backlinks_result.get_result.fetch('backlinks') :
        backlinks_result.get_message
    end

    # This method pulls any page that includes the template requested. Please
    # note - the template must be the full name, like "Template:Disputed" or
    # "Template:Awesome".
    def embedded_in(options=nil)
      raise VersionTooLowError unless @bot.meets_version_requirement(1,9)

      # This will get all pages. Limits vary based on user rights of the Bot. Set to bot.
      post_me = {'list' => 'embeddedin', 'eititle' => @title }

      post_me.merge!(options) if options

      embeddedin_result = @bot.make_request('query', post_me)
      embeddedin_result.fetch('embeddedin').fetch('ei')
    end

    # I decided to split this up since I wanted to normalize the bot framework as much as possible, or in other words, make it as easy to use as possible. I think the sacrifice of more methods is worth having more English looking code. Its the Ruby way.
    # Info will return information about the page, from namespace to normalized title, last touched, etc.
    def info(titles)
      raise RWBErrors::VersionTooLowError unless @bot.meets_version_requirement(1,9)
      
      post_me = {"prop" => "info", 'titles' => titles}
      info_result = @bot.make_request('query', post_me)
      info_result.fetch('pages').fetch('page')
    end

    # This method will let you move a page from one name to another. A move token is required for this to work. Keep that in mind. (get_token much?)
    def move(to, reason, movetalk= true, noredirect=false)
      raise RWBErrors::VersionTooLowError unless @bot.meets_version_requirement(1,12)
      raise RWBErrors::NotLoggedInError unless @bot.logged_in?

      post_me = {
        'from'    => @title ,
        'to'      => "#{to}" ,
        'token'   => get_token('move') ,
        'reason'  => "#{reason}" ,
      }

      # These ifs are necessary because they should only be part of post_me if
      # the passed vars are true (which they are by default)
      post_me['movetalk']   = '' if movetalk
      post_me['noredirect'] = '' if noredirect

      @bot.make_request('move', post_me)
    end # move
    
    # This method is used to protect (and unprotect!) pages. See the API for 
    # possible values. By default, it will lock a page to require sysop level 
    # privledge and never expire. 
    def protect(protections='edit=sysop', expiry='infinite', reason='', cascade=true)
      raise RWBErrors::VersionTooLowError unless @bot.meets_version_requirement(1,12)
      raise RWBErrors::NotLoggedInError unless @bot.logged_in?

      post_me = {
        'title'         => @title ,
        'token'         => get_token('protect') ,
        'protections'   => protections ,
        'expiry'        => expiry ,
        'reason'        => reason ,
      }
      
      post_me['cascade'] = '' if cascade
      @bot.make_request('protect', post_me)
    end # protect

    # Rollback does what it says - rolls back an article one version in the
    # wiki. This is a function that requires not only a token, but a previous
    # user.
    def rollback(summary="", markbot=true)
      raise RWBErrors::VersionTooLowError unless @bot.meets_version_requirement(1,12)
      raise RWBErrors::NotLoggedInError unless @bot.logged_in?

      temp_token = get_token("rollback") # special for rollback. Stupid rollback.
      post_me = {
        'title'     => @title,
        'token'     => temp_token['token'],
        'user'      => temp_token['user'],
        'summary'   => summary
      }

      post_me['markbot'] = '' if markbots
      @bot.make_request('rollback', post_me)
    end

    # This method is used to edit pages. Not much more to say about it. Be
    # sure you're logged in and got a token (get_token). Options is an array
    # (or hash) of extra values allowed by the API.
    def save(content, summary=nil, options=nil)
      raise RWBErrors::VersionTooLowError unless @bot.meets_version_requirement(1,13)
      raise RWBErrors::NotLoggedInError unless @bot.logged_in?

      post_me = {
        'text'     => "#{content}" ,
        'token'    => get_token("edit") ,
        'title'    => @title ,
        'summary'  => "#{summary}" ,
        'edittime' => Time.now.strftime("%Y%m%d%H%M%S") ,
      }

      post_me.merge!(options) if options

      @bot.make_request('edit', post_me).fetch('result')
    end

    private
    # This method should universally return tokens, just give title and type.
    # You will receive a token string (suitable for use in other methods), so
    # plan accordingly. Use an edit token for both editing and creating
    # articles (edit_article, create_article). For rollback, more than just a
    # token is required. So, for token=rollback, you get a hash of token|user.
    # Just the way it goes.
    def get_token(intoken)
      if intoken.downcase == 'rollback'
        #specific to rollback
        post_me = {
          'prop'    => 'revisions' ,
          'rvtoken' => intoken ,
          'titles'  => @title
        }
      else
        post_me = {
          'prop'    => 'info',
          'intoken' => intoken,
          'titles'  => @title
        }
      end
      raw_token = @bot.make_request('query', post_me)

      if intoken.downcase == 'rollback'
        # Damn this decision to make rollback special!. Wasn't mine, I just have to live by it.
        token2 = raw_token.fetch('pages').fetch('page').fetch('revisions').fetch('rev')
        {'token' => token2.fetch('rollbacktoken') , 'user' => token2.fetch('user')}
      else
        raw_token.fetch('pages').fetch('page').fetch("#{intoken}token")
      end
    end
  end
end
