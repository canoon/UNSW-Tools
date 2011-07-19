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
    if path =~ /\?/
      sep = '&'
    else
      sep = '?'
    end
    path + sep + params.collect{|k,v| "#{CGI.escape(k.to_s)}=#{CGI.escape(v.to_s)}"}.join('&')
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

    ticket = response.get_fields('location').first.sub(/^.*ticket=/, '')
  end
end

class SSOService
  def initialize(url, sso=nil)
    @url = url
    if sso
      @sso = sso
    else
      @sso = SSO.new
    end
  end
  def auth
    # don't ask me about this bit
    ticket = @sso.get_ticket(@url)

    response = HTTPUtil.get(HTTPUtil.tourl(@url, {:ticket => ticket}))
    if !response.is_a? Net::HTTPRedirection
      raise "WTF #{url} Auth failed got a #{response}"
    end
    p response.to_hash
    @cookies = HTTPUtil.cookiestohash(response.get_fields('set-cookie'))
    if URI.parse(@url).host == 'lms-blackboard.telt.unsw.edu.au'
      response = HTTPUtil.get(response.get_fields('location').first)
      if !response.is_a? Net::HTTPSuccess
        p response.body
        raise "WTF #{url} Auth failed got a #{response}"
      end
      @cookies = HTTPUtil.cookiestohash(response.get_fields('set-cookie'))
      @cookies.delete('JSESSIONID')
    end
    p @cookies
  end
  def get(uri)
    if @cookie.nil?
      self.auth
    end
    
    response = HTTPUtil.get(uri, {'Cookie' => @cookies})
  end
end


class UNSW
  SERVICES = ["https://my.unsw.edu.au/amserver/UI/Login?module=ISISWSSO&IDToken1=", "https://lms-blackboard.telt.unsw.edu.au/webapps/login"]
  def initialize()
    @connections = {}
  end
  def sso
    @sso ||= SSO.new
  end
  def get(uri)
    if uri.is_a? String
      uri = URI.parse(uri)
    end
    
    if !@connections[uri.host]
      selected = nil
      SERVICES.each {|x|
        if URI.parse(x).host == uri.host
          selected = x
        end
      }
      @connections[uri.host] = SSOService.new(selected, sso)
    end
    
    @connections[uri.host].get(uri)
  end
  def self.get(uri)
    @default ||= UNSW.new
    p @default.get(uri)
  end
end

puts UNSW.get("https://my.unsw.edu.au/active/studentTimetable/timetable.xml").body
puts UNSW.get("https://lms-blackboard.telt.unsw.edu.au/webapps/portal/frameset.jsp").body
