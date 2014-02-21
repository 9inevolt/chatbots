require 'faye/websocket'
require 'json'
require 'eventmachine'
require_relative 'doge_fetcher'

WS_ENDPOINT = 'ws://www.destiny.gg:9998/ws'
PROTOCOLS = nil
OPTIONS = {headers:{
  "Cookie" => "sid=2f96b1ed32a6aabad92a0c42c1819c35; rememberme=%7B%22expire%22%3A1395532139%2C%22created%22%3A1392940139%2C%22token%22%3A%224f3f976a25ac6da24e940d9e9a238f5e%22%7D; __utma=101017095.589024420.1392939653.1392939653.1392939653.1; __utmb=101017095.8.10.1392939653; __utmc=101017095; __utmz=101017095.1392939653.1.1.utmcsr=(direct)|utmccn=(direct)|utmcmd=(none)",
  "Origin" => "*"
  }}

CMD_REGEX = /^!(doge|dgc)/i

fetcher = DogeFetcher.new

# puts fetcher.trycheck("")

EM.run {
  ws = Faye::WebSocket::Client.new(WS_ENDPOINT, PROTOCOLS, OPTIONS)

  ws.on :open do |event|
    p [:open]
    # ws.send('Hello, world!')
  end

  ws.on :message do |event|
    p [:message, event.data]
    # used to 
    if event.data.match /^PING/
      ws.send("PONG "+event.data[5..event.data.length])
    elsif event.data.match /^(MSG)/
      proper_message = event.data.split(" ")
      proper_message.shift
      proper_message = proper_message.join(" ")
      parsed_message = JSON.parse(proper_message)
      p_message = parsed_message["data"]
      if !p_message.nil? and p_message.is_a?(String) and p_message.match(CMD_REGEX)
        if fetcher.ready
          price = fetcher.check(p_message)
          price << " also #{Random.rand.to_s} is a cool number"
          jsn = {data: price}
          ws.send("MSG "+jsn.to_json)
          p "!!! SENDING DATA !!!"
        else
        end
      end
    end
  end

  ws.on :close do |event|
    p [:close, event.code, event.reason]
    ws = nil
  end

  ws.on :event do |event|
    p event
  end
}