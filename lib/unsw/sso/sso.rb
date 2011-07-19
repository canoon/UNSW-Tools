#!/usr/bin/ruby1.9.1

require 'net/http'
require 'net/https'
require 'uri'
require 'cgi'
require 'nokogiri'
require 'highline/import'

module Net
  class HTTP
    def fix_cookies(headers)
      if headers['Cookie']
        headers['Cookie'] = headers['Cookie'].collect{|k, v| "#{k}=#{v}"}.join("; ")
      end
      headers
    end
    def get_params(path, headers={})
      headers = fix_cookies(headers)
      p path
      self.get(path, headers)

    end
    def post_params(path, hash, headers = {})
      headers = fix_cookies(headers)
      if hash != {} && hash != nil 
        data = hash.collect{|k,v| "#{CGI.escape(k.to_s)}=#{CGI.escape(v.to_s)}"}.join('&')
      end
      p data
      self.post(path, data, headers)

    end
  end
end

def cookiestohash(array)
  # Why reverse? because the unsw server sends out multiple cookies with the same name and we need to ignore some.
  Hash[array.collect{ |x| x.split(';').first.split('=') }.reverse]
end

def tourl(path, params)
  path + "?" + params.collect{|k,v| "#{CGI.escape(k.to_s)}=#{CGI.escape(v.to_s)}"}.join('&')
end

#sso = "https://ssologin.unsw.edu.au/cas/login"

service= "https://my.unsw.edu.au/amserver/UI/Login?module=ISISWSSO&IDToken1="

conn = Net::HTTP.new("ssologin.unsw.edu.au", 443);

conn.use_ssl = true



p result = conn.get_params(tourl("/cas/login", {:service => service}))

puts result.body

doc = Nokogiri::HTML(result.body)

lt = doc.css('#muLoginForm input[name="lt"]').first['value']

username = ""
password = ""

if ENV['UNSW_USERNAME'] then
  username = ENV['UNSW_USERNAME']
  password = ENV['UNSW_PASSWORD']
else
  puts "Please enter your UNSW credentials"
  username = ask("Username: ") { |q| q.echo = true }
  password = ask("Password: ") { |q| q.echo = "*" }
end


p login_result = conn.post_params(tourl("/cas/login", {:service => service}), {:lt => lt, :username => username, :password => password, :'_eventId' => 'submit'})

puts login_result.class

puts authurl = login_result.get_fields('location').first

p cookies = cookiestohash(login_result.get_fields('set-cookie'))

p cookies['CASTGC']

p login_result.body

p ticket = authurl.sub(/^.*&ticket=/, '')



myunsw = Net::HTTP.new("my.unsw.edu.au", 443)

myunsw.use_ssl = true

p unswresult = myunsw.get_params(tourl('/amserver/UI/Login', {:module => 'ISISWSSO', :IDToken1 => '', :ticket => ticket})) #, {"Cookie" => "amlbcookie=02"})

puts unswresult.body

p cookies2 = cookiestohash(unswresult.get_fields('set-cookie'))

p token = cookies2['AMAuthCookie']

p test = myunsw.get_params('/active/studentTimetable/timetable.xml', {"Cookie" => {"AMAuthCookie" => token, "iPlanetDirectoryPro" => token}})

p test.body

File.open("timetable", 'w') {|f| f.write(test.body) }




#conn.get

