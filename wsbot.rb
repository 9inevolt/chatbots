Encoding.default_external = "utf-8"
require 'rubygems'
require 'faye/websocket'
require 'json'
require 'eventmachine'
require 'dotenv'
require 'similar_text'
Dotenv.load

# require_relative 'roulette'
# chatbot = Roulette.new

# require_relative 'dcss_player'
# chatbot = DcssPlayer.new

CLASSES = %w{overrustle_fetcher jester csgo_stats moobie}

CLASSES.each do |c|
  require_relative c
end

# todo make the chatbot classes mutable
CHATBOTS = CLASSES.map{|c| Object.const_get(c.camelize).new}

WS_ENDPOINT = 'ws://www.destiny.gg:9998/ws'
PROTOCOLS = nil
DESTINYGG_API_KEY = ENV['DESTINYGG_API_KEY']

RATE_LIMIT = ENV.fetch('RATE_LIMIT', 14) # seconds
ENV['last_time'] = '0'

def ready(command)
  now = Time.now.to_i
  if (command != GLOBALS['last_command']) or (now - ENV['last_time'].to_i > RATE_LIMIT)
    ENV['last_time'] = now.to_s
    GLOBALS['last_command'] = command
    return true
  end
  return false
end

OPTIONS = {headers:{
  "Cookie" => "authtoken=#{DESTINYGG_API_KEY};",
  "Origin" => "*"
  }
}

GLOBALS = {
  'reconnects' => 0,
  'baddies' => [], # todo: persist this
  'last_command' => '',
  'last_message' => ''
}

EM.run {
  def make_ws
    ws = Faye::WebSocket::Client.new(WS_ENDPOINT, PROTOCOLS, OPTIONS)

    ws.on :open do |event|
      p [:open]
      GLOBALS['reconnects'] = 0
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
          if event.data.match /duplicate/i
            # suffix = " OverRustle x #{(Random.rand*100000).to_s}"
          elsif event.data.match /needlogin/i
            baderror = true
            puts "---> need login!"
          elsif event.data.match /muted/i
            baderror = true
            puts '---> Muted'
            if GLOBALS.has_key?('last_caller')
              GLOBALS['baddies'] << GLOBALS['last_caller']
            end
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
        if !baderror and !GLOBALS['baddies'].include?(chatter_name) and !p_message.nil? and p_message.is_a?(String)
          CHATBOTS.each do |chatbot|
            if p_message.match(chatbot.regex)
              if chatbot.respond_to?(:set_chatter) 
                chatbot.set_chatter(chatter_name)
                puts "set chatter name to #{chatter_name}"
              end
              cmd = p_message.split(' ').first

              result = ready(cmd) ? chatbot.check(p_message) : nil

              if !result.nil? and result.length > 0
                result << suffix
                jsn = {data: result}
                ws.send("MSG "+jsn.to_json)
                p "<--- SENDING DATA !!! #{result}"
                GLOBALS['last_caller'] = chatter_name
                GLOBALS['last_message'] = result
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
      puts 'Disconnected!'
      if (event.code == 1006 or event.code == 1000) and GLOBALS['reconnects'] < 4
        puts 'due to network connection to chat server'
        sleep 2
        GLOBALS['reconnects'] += 1
        make_ws
      end
    end

    ws.on :event do |event|
      p event
    end
  end
  make_ws
}
