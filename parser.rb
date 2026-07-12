# parser.rb
require 'net/http'
require 'json'
require 'csv'
require 'time'

class RateParser
  API_URL = 'https://api.exchangerate.host/latest?base=USD'
  CACHE_TTL = 60

  def initialize
    @rates = {}
    @last_update = nil
    @history = []
    fetch_rates
  end

  def fetch_rates
    uri = URI(API_URL)
    begin
      response = Net::HTTP.get_response(uri)
      if response.is_a?(Net::HTTPSuccess)
        data = JSON.parse(response.body)
        if data['success']
          @rates = data['rates']
          @last_update = Time.now
          @history << { timestamp: @last_update.iso8601, rates: @rates.dup }
          @history.shift if @history.size > 10
          return true
        end
      end
      false
    rescue => e
      puts "Error fetching rates: #{e.message}"
      false
    end
  end

  def get_rates
    if @last_update && (Time.now - @last_update) > CACHE_TTL
      fetch_rates
    end
    @rates
  end

  def filter_rates(currencies)
    all_rates = get_rates
    all_rates.select { |k, _| currencies.include?(k) }
  end

  def search_currency(query)
    all_rates = get_rates
    q = query.downcase
    all_rates.select { |k, _| k.downcase.include?(q) }
  end

  def refresh
    fetch_rates
  end

  def export_json(filename = 'rates.json')
    data = {
      timestamp: @last_update&.iso8601,
      rates: get_rates
    }
    File.write(filename, JSON.pretty_generate(data))
    true
  rescue => e
    puts "Export failed: #{e.message}"
    false
  end

  def export_csv(filename = 'rates.csv')
    rates = get_rates
    CSV.open(filename, 'w') do |csv|
      csv << ['Currency', 'Rate']
      rates.keys.sort.each do |k|
        csv << [k, rates[k].round(4)]
      end
    end
    true
  rescue => e
    puts "Export failed: #{e.message}"
    false
  end

  def show_history
    if @history.empty?
      puts 'No history yet.'
      return
    end
    @history.each_with_index do |entry, i|
      puts "[#{i+1}] #{entry[:timestamp]} – #{entry[:rates].size} currencies"
    end
  end

  def display_rates(rates = nil)
    rates ||= get_rates
    if rates.empty?
      puts 'No rates available.'
      return
    end
    puts "\nRates (USD base) – updated: #{@last_update || 'unknown'}"
    puts '-' * 40
    rates.keys.sort.first(20).each do |k|
      puts "#{k.ljust(5)} : #{rates[k].round(4)}"
    end
    if rates.size > 20
      puts "... and #{rates.size - 20} more"
    end
  end
end

def main
  parser = RateParser.new
  puts "=== Exchange Rate Parser ==="
  loop do
    puts "\n1. Show all rates"
    puts "2. Filter by currency"
    puts "3. Search currency"
    puts "4. Export to JSON"
    puts "5. Export to CSV"
    puts "6. Refresh rates"
    puts "7. Show history"
    puts "8. Exit"
    print "Choose: "
    choice = gets.chomp.strip
    case choice
    when '1'
      parser.display_rates
    when '2'
      print "Enter currency codes (comma-separated): "
      input = gets.chomp.strip.upcase
      currencies = input.split(',').map(&:strip).reject(&:empty?)
      if currencies.any?
        filtered = parser.filter_rates(currencies)
        parser.display_rates(filtered)
      else
        puts "No currencies specified."
      end
    when '3'
      print "Enter currency code or name: "
      query = gets.chomp.strip
      if !query.empty?
        found = parser.search_currency(query)
        parser.display_rates(found)
      else
        puts "Query cannot be empty."
      end
    when '4'
      print "Filename (default: rates.json): "
      fname = gets.chomp.strip
      fname = 'rates.json' if fname.empty?
      if parser.export_json(fname)
        puts "Exported to #{fname}"
      end
    when '5'
      print "Filename (default: rates.csv): "
      fname = gets.chomp.strip
      fname = 'rates.csv' if fname.empty?
      if parser.export_csv(fname)
        puts "Exported to #{fname}"
      end
    when '6'
      if parser.refresh
        puts "Rates refreshed."
      else
        puts "Refresh failed."
      end
    when '7'
      parser.show_history
    when '8'
      puts "Goodbye!"
      break
    else
      puts "Invalid choice."
    end
  end
end

main if __FILE__ == $0
