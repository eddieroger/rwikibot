## These methods aren't part of the API, so I'm moving them out. 
## But they're still useful. Very. 

module RWBUtilities
  
  private
  
  # is_redirect?
  #
  # Tests to see if a given page title is redirected to another page. Very Ruby.
  def is_redirect? (title)
    
    post_me = {'titles' => title, 'redirects'=>'', 'prop' => 'info'}

    result = make_request('query', post_me)
    
    if (result['result'] == "Success") && (result.has_key?("redirects"))
      return true
    else
      return false
    end
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
  
  # The point of this method is to iterate through an array of hashes, which most of the other methods return, and remove multiple instances of the same wiki page. We're more than often only concerned with the most recent revision, so we'll delete old ones. 
  #
  # Hashes don't respond to the the Array.uniq method. So this is the same-ish
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
  
  # This method will return the version of the MediaWiki server. This is done by parsing the version number from the generator attribute of the the site_info method. Useful? Yes - maybe yout bot is only compatible with MediaWiki 1.9.0 depending on what methods you use. I like it, anwyay.
  def version
    # Almost TOO simple... 
    return site_info.fetch('generator').split(' ')[1]
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
      'User-agent'=>'bot-RWikiBot/2.0-rc1',
      'Cookie' => cookies
    }

    r = Hash.new
    until post_this.nil?
      return_result, post_this = raw_call(headers, post_this)
      r.deep_merge(return_result.fetch(action))
    end

    return r
  end #make_request

# Raw Call handles actually, physically talking to the wiki. It is broken out to handle query-continues where applicable. So, all the methods call make_request, and it calls raw_call until raw_call returns a nil post_this.
  def raw_call(headers, post_this)
    request = Net::HTTP::Post.new(@config.fetch('uri').path, headers)
    request.set_form_data(post_this)
    response = Net::HTTP.new(@config.fetch('uri').host, @config.fetch('uri').port).start {
      |http| http.request(request)
    }

    # Extra cookie handling. Because editing will be based on session IDs and it generates a new one each time until you start responding. I doubt this will change.
    if (response.header['set-cookie'] != nil)
      @config['_session'] = response.header['set-cookie'].split("=")[1]
    end

    return_result = XmlSimple.xml_in(response.body, { 'ForceArray' => false })
    # puts "==>>Result is: #{return_result}"

    if return_result.has_key?('error')
      raise RWikiBotError, "#{return_result.fetch('error').fetch('code').capitalize}: #{return_result.fetch('error').fetch('info')}"
    end

    if !post_this.keys.any?{|k| k.include?('limit')} && return_result.has_key?('query-continue')
      return_result.fetch('query-continue').each do |key, value|
        return_result.fetch('query-continue').fetch(key).each do |x,y|
          post_this[x] = y
        end
      end
    else
      post_this = nil
    end

    return return_result, post_this
  end #raw_call
end