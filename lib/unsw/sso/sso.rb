#!/usr/bin/ruby1.9.1

require 'net/http'
require 'net/https'
require 'uri'
require 'cgi'

module Net
  class HTTP
    def get_params(path, hash)
      if hash == {} || hash == nil 
        params = ""
      else
        params = params.collect{|k,v| "#{URI.escape(k)}=#{URI.escape(v)}"}.join('&')
      end
    end
  end
end


#sso = "https://ssologin.unsw.edu.au/cas/login"

#service= "https://my.unsw.edu.au/amserver/UI/Login?module=ISISWSSO&IDToken1="

conn = Net::HTTP.new("ssologin.unsw.edu.au", 443);

conn.

p conn.get("/cas/login")

p conn.test

#conn.get

