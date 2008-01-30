# RWikiBot Exceptions

class MediaWikiException < Exception
  
  def initialize (message)
    super message
  end
  
  def message()
    return
  end
  
end