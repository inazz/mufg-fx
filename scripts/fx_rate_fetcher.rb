#!/usr/bin/ruby
# coding: utf-8

require 'mechanize'
require 'optparse'
require 'optparse/date'

class FxRateFetcherOption
  attr_accessor :date, :price_type, :currency

  def initialize()
    @date = Date.today
    @price_type = 'TTM'
    @currency = 'USD'
  end

  def fromArgs(argv)
    opt = OptionParser.new
    opt.on('-d', '--date DATE', Date) {|d|
      @date = d
    }

    opt.on('-t', '--type TYPE', /^TT[SBM]$/, 'type of value. TTS, TTB, or TTM') {|t|
      @price_type = t
    }

    opt.on('-c', '--currency CODE', /^[A-Z]{3}$/, 'Currency code. USD, EUR, CAD, etc..') {|c|
      @currency = c
    }
    opt.parse!(argv)
    return self
  end
end

class FxRateFetcher
  def main(argv)
    opt = FxRateFetcherOption.new.fromArgs(argv)
    data = getMufgRate(opt.date)
    if (data != nil)
      matched_data = data.select{|x| x[0] == opt.currency && x[1] == opt.price_type}
      throw "data is not available for #{opt.curreny} #{opt.price_type}." if matched_data.size != 1
      puts matched_data[0][2]
    end
  end
    
  # Fetch the Fx rate of the date.
  # Returns
  # Array of [CURRENCY_CODE, VALUE_TYPE, VALUE] if success. VALUE_TYPE can be 'TTS', 'TTB' or 'TTM'
  # nil if the data is not available on the day. 
  def getMufgRate(date)
    agent = Mechanize.new
    agent.redirect_ok = false
    url = "https://www.murc-kawasesouba.jp/fx/past_3month_result.php?y=#{date.year}&m=#{date.month}&d=#{date.day}&c="
    page = agent.get(url)
    if page.code == "302"
      # no data on the day.
      return nil
    elsif page.code != "200"
      throw Exception.new("unexpected http code: " + page.code.to_s)
    end
    
    tbl = page.root.search("table").select{|x| x.attribute('class').value == 'data-table5'}
    throw Exception.new("unexpected page format.") unless tbl.size == 1

    ths = []
    tds = []
    tbl[0].children.select {|e1| e1.element? }.each {|e1|
      if e1.name == 'tr'
        e1.children.select {|e2| e2.element? }.each {|e2|
          if e2.name == 'th'
            ths.push(e2.text)
          elsif e2.name == 'td'
            tds.push(e2.text)
          end
        }
      elsif e1.name == 'td'
        tds.push(e1.text)
      end
    }
    if (ths.size != 6 ||
        !ths[2].include?("Code") ||
        ths[3] != 'TTS' ||
        ths[4] != 'TTB' ||
        ths[5] != 'TTM' ||
        tds.size % 6 != 0)
      throw Exception.new("unexpected page format.")
    end
    res = []
    (0 ... tds.size/6).each{ |n|
      code = tds[n*6+2]
      tts = tds[n*6+3]
      ttb = tds[n*6+4]
      ttm = tds[n*6+5]
      res.push([code, 'TTS', tts])
      res.push([code, 'TTB', ttb])
      res.push([code, 'TTM', ttm])
    }
    return res
  end
end

FxRateFetcher.new.main(ARGV)
