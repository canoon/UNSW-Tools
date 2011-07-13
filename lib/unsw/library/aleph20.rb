class Library::Aleph
	DOMAIN = "http://aleph20.library.unsw.edu.au/"
	
	def initialize(primoa)
		response = Library::loadurl(DOMAIN + 'F/')
		response.each_line do |line|
			if (line =~ /var url = '.*\/F\/([A-Z0-9]+)-[0-9]+\?';/)
				@session_id = $~[1] 
			end
		end
		$log.debug "Session Id: #{@session_id}"
  	fcall({'pds_handle' => primoa.pdshandle})
	end

	def fcall(hash)
		return Library::loadurl(DOMAIN + 'F/' + @session_id + '-' + 31337.to_s + '?' + Library::parameterize(hash))
	end


end



