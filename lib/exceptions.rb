# RWikiBot Exceptions

class MediaWikiException < Exception
  
  def initialize (error_hash)
    @code = error_hash.fetch('code')
    @info = error_hash.fetch('info')
  end
  
  def message()
    return 
  end
  
end

class RWBLoginException < Exception
  
  def initalize (error_hash)
    @error = error_hash.fetch('result')
    @details = error_hash.fetch('details')
  end
  
  def message
    return 
  end
end
