#!/usr/bin/ruby1.9.1

require 'net/http'
require 'net/https'
require 'uri'
require 'cgi'
require 'nokogiri'
require 'highline/import'

class HTTPUtil
  def self.fix_cookies(headers)
    if headers['Cookie']
      headers['Cookie'] = headers['Cookie'].collect{|k, v| "#{k}=#{v}"}.join("; ")
    end
    headers
  end
  def self.get_path(uri)
    if uri.query
      return uri.path + '?' + uri.query
    else
      return uri.path
    end
  end
  def self.get(uri, headers={})
    if uri.is_a? String
      uri = URI.parse(uri)
    end
    conn = Net::HTTP.new(uri.host, uri.port)
    if uri.scheme == 'https'
      conn.use_ssl = true
    end
    headers = fix_cookies(headers)
    p uri
    
    conn.get(get_path(uri), headers)
  end
  def self.post(uri, hash, headers = {})
    if uri.is_a? String
      uri = URI.parse(uri)
    end
    conn = Net::HTTP.new(uri.host, uri.port)
    if uri.scheme == 'https'
      conn.use_ssl = true
    end
    headers = fix_cookies(headers)
    
    if hash != {} && hash != nil 
      data = hash.collect{|k,v| "#{CGI.escape(k.to_s)}=#{CGI.escape(v.to_s)}"}.join('&')
    end
    display = data
    if !$password.empty?
      display = display.gsub(CGI.escape($password), '*' * CGI.escape($password).length)
    end
    p display
    p uri
    conn.post(get_path(uri), data, headers)

  end
  def self.cookiestohash(array)
    # Why reverse? because the unsw server sends out multiple cookies with the same name and we need to ignore some.
    if array
      Hash[array.collect{ |x| x.split(';').first.split('=') }.reverse]
    else
      {}
    end
  end
  def self.tourl(path, params)
    path + "?" + params.collect{|k,v| "#{CGI.escape(k.to_s)}=#{CGI.escape(v.to_s)}"}.join('&')
  end
end


class SSO
  URL = "https://ssologin.unsw.edu.au/cas/login"
  COOKIE = "CASTGC"
  def initialize
  end

  def get_ticket(service)
    login_url = HTTPUtil.tourl(URL, {:service => service})
    response = HTTPUtil.get(login_url, {'Cookie' => {COOKIE => @tgt}})
    cookies = HTTPUtil.cookiestohash(response.get_fields('set-cookie'))
    if !response.is_a? Net::HTTPRedirection
      if !response.is_a? Net::HTTPSuccess
        raise "WTF got a #{response}"
      end
      doc = Nokogiri::HTML(response.body)
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
      $password = password  
      response = HTTPUtil.post(login_url, {'lt' => lt, 'username' => username, 'password' => password, '_eventId' => 'submit'})
      if !response.is_a? Net::HTTPRedirection
        raise "WTF2 got a #{response}"
      end
    
      cookies = HTTPUtil.cookiestohash(response.get_fields('set-cookie'))
    else
      puts "Already logged in"
    end
    @tgt = cookies[COOKIE]

    ticket = response.get_fields('location').first.sub(/^.*&ticket=/, '')
  end
end

class MyUNSW
  URL = "https://my.unsw.edu.au/amserver/UI/Login"
  PARAMS = {:module => 'ISISWSSO', :IDToken1 => ''} 
  COOKIES = ['iPlanetDirectoryPro', 'AMAuthCookie']
  def initialize(sso=nil)
    if sso
      @sso = sso
    else
      @sso = SSO.new
    end
  end
  def auth
    ticket = @sso.get_ticket(HTTPUtil.tourl(URL, PARAMS))

    response = HTTPUtil.get(HTTPUtil.tourl(URL, PARAMS.merge({:ticket => ticket})))
    if !response.is_a? Net::HTTPRedirection
      raise "WTF MyUNSW Auth failed got a #{response}"
    end
    cookies = HTTPUtil.cookiestohash(response.get_fields('set-cookie'))
    @cookie = cookies[COOKIES.first]
  end
  def get(uri)
    if @cookie.nil?
      self.auth
    end
    
    cookies = Hash[COOKIES.collect{|x| [x, @cookie]}]
    response = HTTPUtil.get(uri, {'Cookie' => cookies})
  end
end


#sso = SSO.new

#service= "https://my.unsw.edu.au/amserver/UI/Login?module=ISISWSSO&IDToken1="

#puts sso.get_ticket(service)

#puts sso.get_ticket(service)
puts MyUNSW.new.get("https://my.unsw.edu.au/active/studentTimetable/timetable.xml").body
exit 0








#conn.get

