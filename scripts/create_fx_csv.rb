#!/usr/bin/ruby
#
# Usage:
# ./create_fx_csv.rb -c USD -t TTM -b 2018-01-01 -e 2018-12-31 > data/2018-usd-ttm.csv
#

require 'date'
require 'optparse'
require 'optparse/date'

class CreateFxCsvOption
  attr_reader :currency, :type, :date_begin, :date_end, :max_backoff
  def initialize()
    @currency = 'USD'
    @type = 'TTM'
    @date_begin = Date.new(Date.today.year, 1, 1)
    @date_end = Date.today - 1
    @max_backoff = 14
  end

  def fromArgs(argv)
    opt = OptionParser.new

    opt.on('-c', '--currency CODE', /^[A-Z]{3}$/, 'Currency code. USD, EUR, CAD, etc..') {|c|
      @currency = c
    }
    opt.on('-t', '--type TYPE', /^TT[SBM]$/, 'type of value. TTS, TTB, or TTM') {|t|
      @type = t
    }
    opt.on('-b', '--date_begin DATE', Date) {|d|
      @date_begin = d
    }
    opt.on('-e', '--date_end DATE', Date) {|d|
      @date_end = d
    }
    opt.parse!(argv)
    return self
  end
end

class CreateFxCsv
  
  def main(args)
    opt = CreateFxCsvOption.new.fromArgs(args)

    date = opt.date_begin
    last_quote = ""
    while (date <= opt.date_end)
      quote = getQuote(date, opt.currency, opt.type)
      if (last_quote == "" && quote == "")
        backoff = 1
        while (last_quote == "" && backoff <= opt.max_backoff)
          last_quote = getQuote(date - backoff, opt.currency, opt.type)
          backoff += 1
        end
        throw Exception.new("Data is not available.") if last_quote == ""
      elsif (quote != "")
        last_quote = quote
      end
      puts [date.strftime('%F'), opt.currency, opt.type, last_quote].join(",")
      date += 1
    end
  end

  def getQuote(date, currency, type)
    date_str = date.strftime('%F')
    script = File.expand_path(File.dirname(__FILE__)) + '/fx_rate_fetcher.rb'
    cmd = "#{script} --date=#{date_str} --currency=#{currency} --type=#{type}"
    quote = `#{cmd}`.strip
    throw Exception.new("failed to run command: #{cmd}") unless $?.success?
    return quote
  end

end

CreateFxCsv.new.main(ARGV)
