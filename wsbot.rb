require 'rubygems'
require 'faye/websocket'
require 'json'
require 'eventmachine'
require 'dotenv'
Dotenv.load

# require_relative 'roulette'
# chatbot = Roulette.new

# require_relative 'dcss_player'
# chatbot = DcssPlayer.new

require_relative 'jester'
require_relative 'overrustle_fetcher'

chatbots = [
  OverrustleFetcher.new,
  Jester.new
]

WS_ENDPOINT = 'ws://www.destiny.gg:9998/ws'
PROTOCOLS = nil
DESTINYGG_API_KEY = ENV['DESTINYGG_API_KEY']

RATE_LIMIT = 32 # seconds
last_time = 0
def ready
  now = Time.now.to_i
  if now - last_time > RATE_LIMIT
    last_time = now
    return true
  end
  return false
end

OPTIONS = {headers:{
  "Cookie" => "authtoken=#{DESTINYGG_API_KEY};",
  "Origin" => "*"
  }}

reconnects = 0

EM.run {
  ws = Faye::WebSocket::Client.new(WS_ENDPOINT, PROTOCOLS, OPTIONS)

  ws.on :open do |event|
    p [:open]
    reconnects = 0
    # ws.send('Hello, world!')
  end

  ws.on :message do |event|
    p [:message, event.data]
    # used to 
    if event.data.nil?
      p [:error, event.to_s]
    elsif event.data.match /^PING/
      ws.send("PONG "+event.data[5..event.data.length])
    elsif event.data.match /^(ERR|MSG)/
      suffix = ""
      p_message = ""
      baderror = false
      if event.data.match /^ERR/
        if event.data.match /duplicate/
          # suffix = " OverRustle x #{(Random.rand*100000).to_s}"
        end
        if event.data.match /needlogin/
          baderror = true
          puts "need login!"
        end
      else
        # removes their name from the message, i think?
        proper_message = event.data.split(" ")
        proper_message.shift
        proper_message = proper_message.join(" ")
        parsed_message = JSON.parse(proper_message)
        p_message = parsed_message["data"]
        chatter_name = parsed_message["nick"]
      end
      if !baderror and !p_message.nil? and p_message.is_a?(String)
        return unless ready
        chatbots.each do |chatbot|
          if p_message.match(chatbot.regex)
            if chatbot.respond_to?(:set_chatter) 
              chatbot.set_chatter(chatter_name)
              puts "set chatter name to #{chatter_name}"
            end
            result = chatbot.check(p_message)
            if !result.nil? and result.length > 0
              result << suffix
              jsn = {data: result}
              ws.send("MSG "+jsn.to_json)
              p "!!! SENDING DATA !!! #{result}"
            else
              # p "nothing to send for #{p_message}"
            end
            # if we found a matching bot, stop the loop
            break 
          end
        end
      end
    end
  end

  ws.on :close do |event|
    p [:close, event.code, event.reason]
    ws = nil
    if event.code == 1006 and reconnects < 4
      sleep 1
      reconnects += 1
      ws = Faye::WebSocket::Client.new(WS_ENDPOINT, PROTOCOLS, OPTIONS)
    end
  end

  ws.on :event do |event|
    p event
  end
}