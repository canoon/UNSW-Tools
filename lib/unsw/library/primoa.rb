class Library::Primoa
	attr_reader :pdshandle
	
	DOMAIN = "https://primoa.library.unsw.edu.au/"
  
  def initialize(login)
  	login_params = {:func => 'login',
  	    :bor_id => login[:username], 
  	    :bor_verification => login[:password], 
  	    :institute => 'UNSW'}
    doc = Nokogiri::HTML(pdscall(login_params))
  	@pdshandle = doc.xpath('//a').first['href'].split("&")[1].split('=')[1]
  	$log.debug "Auth Key: #{@pdshandle}"
  	@pdshandle
  end
  
	def pdscall(hash)
		return Library::loadurl(DOMAIN + 'pds/' + '?' + Library::parameterize(hash))
	end

end
