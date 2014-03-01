#!/usr/bin/ruby
require 'cinch'

require_relative 'dcss_player'

fetcher = DcssPlayer.new

class DcssPlayerPlugin
  include Cinch::Plugin
  match fetcher.regex

  def check(query)
    fetcher.check(query)
  end

  def execute(m, query)
    if fetcher.ready
      result = fetcher.check(p_message)
      if !result.nil? and result.length > 0
        result << suffix
        m.reply result
        p "!!! SENDING DATA !!!"
      end
    end
  end
end