require 'open-uri'
require 'uri'
require 'yaml'
require 'nokogiri'
require 'logger'

module Library
  def self.loadurl(url)
  	res = nil
  	while res.nil?
  		begin
  			#$log.debug "Loading: #{url.gsub(CONFIG[:password], '*' * CONFIG[:password].length )}"
  			res = open(url).read
  		rescue Timeout::Error => e
  			$log.warn "Timeout :("
  		end
  	end
  	return res
  end
  
  def self.parameterize(params)
	  URI.escape(params.collect{|k,v| "#{k}=#{v}"}.join('&'))
	end
	
	def self.unparameterize(url)
		Hash[url.split('?')[1].split('&').collect{|x| x.split('=')}]
	end

end



require 'library/aleph20'
require 'library/primoa'
require 'library/room'
require 'library/room_list'

