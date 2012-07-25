#!/usr/bin/ruby1.9.1

require 'net/http'
require 'net/https'
require 'uri'
require 'cgi'
require 'nokogiri'
require 'highline/import'
require 'icalendar'
require 'date'

include Icalendar

class UNSWDate
  def self.dateParse(day, weeks, time)
    t = timeParse(time)
    d = Date::ABBR_DAYNAMES.index(day)
    ws = weeksParse(weeks)
    ws.collect{|w|
      t.collect{|x| buildDate(w, d, x)}
    }
  end

  def self.buildDate(w, d, t)
    # Fucked
    i = Time.local(2012, 7, 15)
    i += (w - 1) * 7 * 86400
    i += d * 86400
    dt = DateTime.new(i.year, i.month, i.day, t[0], t[1], 0, Rational(i.gmt_offset, 86400)) 
    dt = dt.new_offset 0
    dt
  end
    

  def self.weeksParse(weeks)
    weeks.split(",").collect{|x| 
      if x =~ /-/
	Range.new(*(x.split("-").collect{|x| x.to_i})).to_a
      else
        [x.to_i]
      end
    }.flatten
  end
  def self.timeParse(str)
    str.split(" - ").collect{|x| timeParseInd(x)}
  end
  def self.timeParseInd(str)
    result = [0, 0]
    str.match(/([0-9]+):([0-9]+)([AP]M)/){|x|
      result = [(x[1].to_i % 12) + (x[3] == "PM" ? 12 : 0), x[2].to_i]
    }
    result
  end
end

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
    uri
    
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
        h = HighLine.new($stdin, $stderr)
        h.say "Please enter your UNSW credentials"
        username = h.ask("Username: ") { |q| q.echo = true }
        password = h.ask("Password: ") { |q| q.echo = "*" }
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
    @cookies = HTTPUtil.cookiestohash(response.get_fields('set-cookie'))
    if URI.parse(@url).host == 'lms-blackboard.telt.unsw.edu.au'
      response = HTTPUtil.get(response.get_fields('location').first)
      if !response.is_a? Net::HTTPSuccess
        raise "WTF #{url} Auth failed got a #{response}"
      end
      @cookies = HTTPUtil.cookiestohash(response.get_fields('set-cookie'))
      @cookies.delete('JSESSIONID')
    end
  end
  def get(uri)
    if @cookie.nil?
      self.auth
    end
    
    response = HTTPUtil.get(uri, {'Cookie' => @cookies})
  end
end


class UNSW
  SERVICES = ["https://my.unsw.edu.au/amserver/UI/Login?module=ISISWSSO&IDToken1=", "https://lms-blackboard.telt.unsw.edu.au/webapps/login", "https://moodle.telt.unsw.edu.au/login/index.php?authCAS=CAS"]
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
    @default.get(uri)
  end

  def self.timetable()
    @default ||= UNSW.new
    @default.timetable
  end

  def self.d
    @default ||= UNSW.new
  end

  def timetable()
    
    doc = get("https://my.unsw.edu.au/active/studentTimetable/timetable.xml").body
    
    nok = Nokogiri::HTML.parse(doc);
    
    tables = nok.css("table").select{|x| x.css("td").first.content == "Activity"}
    
    previous = {}
    
    times = tables.collect{|x| x.css("tr.data").collect{|r|
      tds = r.css("td").select{|x| x["class"] && x["class"].strip == "data"} .collect{|x| x.content.strip}
      result = previous.clone
      if (r.css("td").first["colspan"].nil?)
        # They've actually specified the Activity / Section and it hasn't just been carried over
        result[:activity] = tds.shift
        result[:section] = tds.shift
      end
      result[:day] = tds.shift
      result[:time] = tds.shift
      result[:weeks] = tds.shift
      result[:location] = tds.shift
      result[:instructor] = tds
      previous = result
    }}
    
    courses = nok.css(".sectionHeading").collect{|x| x.content }
    result = Hash[courses.zip(times)]
    
    result
  end

  def ical_timetable
    tt = timetable
    cal = Calendar.new

    tt.each{|course, classes|
      classes.each{|a|
        UNSWDate.dateParse(a[:day], a[:weeks], a[:time]).each{|x|
          cal.event do 
            dtstart x[0]
            dtend x[1]
            summary(course + " - " + a[:activity])
            description(a[:section] + ", instructor(s): " + a[:instructor].join(", "))
            location(a[:location])
          end
        }
      }
    }
    cal.to_ical
  end    
    
end

Calendar.new
puts UNSW.d.ical_timetable

#puts UNSW.get("https://lms-blackboard.telt.unsw.edu.au/webapps/portal/frameset.jsp").body
#puts UNSW.get("http://moodle.telt.unsw.edu.au/my/").body
