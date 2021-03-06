require 'rubygems'
require 'net/http'
require 'open-uri'
require 'json'
require 'cgi'
require 'digest'
require 'action_view'
require 'similar_text'
include ActionView::Helpers::DateHelper

class OverrustleFetcher
  ENDPOINT = "http://overrustle.com:6081/api"
  VALID_WORDS = %w{strim strims overrustle OverRustle blacklist_nospace}
  MODS = %w{iliedaboutcake hephaestus 13hephaestus bot destiny ceneza sztanpet}.map{|m| m.downcase}
  FILTERED_STRIMS = %w{clickerheroes s=advanced strawpoii}
  RATE_LIMIT = 32 # seconds
  CACHE_DURATION = 60 #seconds
  APP_ROOT = File.expand_path(File.dirname(__FILE__))
  CACHE_FILE = APP_ROOT+"/cache/"

  attr_accessor :regex
  def initialize
    @regex = /^!(#{VALID_WORDS.join('|')})/i
    @last_message = ""
  end
  def set_chatter(name)
    @chatter = name
  end
  def check(query)
    m = trycheck(query)
    @last_message = m
    return m
  rescue Exception => e
    puts e.message
    puts e.backtrace.join("\n")
    m = e.message
    " OverRustle Tell hephaestus or iliedaboutcake something broke. Exception: #{m.to_s}"
  end
  def trycheck(query)
    saved_filter = getcached("chat_filter") || []
    if query =~ /^(!blacklist_nospace)/i and MODS.include?(@chatter.downcase)
      parts = query.split(' ')
      if parts.length < 3
        return "#{@chatter} didn\'t format the blacklist command correctly"
      end
      thing_to_blacklist = parts[1] + parts[2]
      saved_filter.push(thing_to_blacklist)
      setcached("chat_filter", saved_filter)
      return "#{parts[1]} #{parts[2]} (no space) added to blacklist by #{@chatter}"
    end
    # TODO: don't return anything if destiny is live
    output = "Top 3 OverRustle.com strims: "
    # cached = getcached(ENDPOINT)
    # expire cache if...
    jsn = getjson(ENDPOINT)
    # if cached.nil? or cached["date"] < Time.now.to_i - CACHE_DURATION
    #   jsn = getjson(ENDPOINT)
    #   if jsn.nil?
    #     raise "Bad JSON from API"
    #   else
    #     setcached(ENDPOINT, jsn)
    #   end
    # else
    #   jsn = cached
    # end
    filtered_strims = FILTERED_STRIMS + saved_filter
    strims = jsn["streams"]
    list_of_lists = strims.sort_by{|k,v| -(v).to_i}
    # filter:
    to_remove = []
    list_of_lists.each_with_index do |sl, i|
      if sl[0] =~ /(#{filtered_strims.join('|')})/i
        to_remove << i
      end
    end
    # go from back to front so the index doesn't mess up
    to_remove.reverse.each{|tr| list_of_lists.delete_at(tr)}

    list_of_lists.take(3).each do |sl|
      output << "\noverrustle.com#{sl[0]} has #{sl[1]} | "
    end
    if list_of_lists.length > 3
      wildcard = list_of_lists.drop(3).sample
      output << "\n Wild Card - overrustle.com#{wildcard[0]}"
    end

    # it's too similar. so it will get the bot banned
    # get the next 3
    if @last_message.similar(output) >= 90
      output = "Full Strim List - overrustle.com/strims"
      output << "\n #4 to #6  :"
      list_of_lists.drop(3).take(3).each do |sl|
        output << "\noverrustle.com#{sl[0]} has #{sl[1]} | "
      end
    end

    if @last_message.similar(output) >= 80
      output = "Check out Overrustle.com/strims for more strims. RustleBot by hephaestus."
    end

    return output
  end

  def getjson(url)
    content = open(url).read
    return JSON.parse(content)
  end

  # safe cache! won't die if the bot dies
  def getcached(url)
    return @cached_json if !@cached_json.nil?
    path = CACHE_FILE + url + ".json"
    if File.exists?(path)
      f = File.open(path)
      return JSON.parse(f.read)
    end
    return nil
  end
  def setcached(url, jsn)
    @cached_json = jsn
    path = CACHE_FILE + url + ".json"
    File.open(path, 'w') do |f2|
      f2.puts JSON.unparse(jsn)
    end
  end

  def hashed(url)
    return Digest::MD5.hexdigest(url).to_s
  end
end
