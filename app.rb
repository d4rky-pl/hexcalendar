require 'rubygems'
require 'sinatra'
require 'haml'
require 'json'
require 'net/http'
require 'base64'
require 'date'

class TableRepository
  TABLE_COUNT = 14
  attr_reader :tables

  def initialize
    @tables = (0..(TABLE_COUNT-1)).to_a.map { |i| Table.new(self, i) }
    @reservations = {}
  end

  def reservations(date)
    date = date.to_date if date.is_a?(DateTime)
    @reservations[date.to_s] ||= json_for_date(date).inject({}) do |tables, t|
      tables[t['table_type_id'].to_i] ||= []
      tables[t['table_type_id'].to_i] << (t['hour_start_id'].to_i..t['hour_end_id'].to_i)
      tables
    end
  end

  def busy?(table_id, date, time)
    reservations(date).any? { |table, ranges| table == table_id && ranges.any? { |range| range.include?(hour_id(time)) } }
  end

  def free?(table_id, date, time)
    !busy?(table_id, date, time)
  end

  protected
  def json_for_date(date)
    date = date.to_date if date.is_a?(DateTime)
    post_data = {
      year:  Base64.encode64((date.year % 1000).to_s),
      month: Base64.encode64(date.month.to_s),
      day:   Base64.encode64(date.day.to_s)
    }
    request = Net::HTTP.post_form URI('https://serwer1472121.home.pl/fb_app/checkRes.php'), post_data
    JSON.parse(request.body)
  end

  def hour_id(time)
    (time.hour - 12)*2 + (time.min > 30 ? 2 : 1)
  end
end

class Table
  attr_reader :id
  attr_accessor :repository

  def initialize(repository, id)
    @repository = repository
    @id = id.to_i
  end

  def busy?(date)
    repository.busy?(table_id, date, time)
  end

  def free?(date)
    repository.free?(table_id, date, time)
  end
end

class HexApp < Sinatra::Base
  WEEKDAYS = %w(Niedziela Poniedziałek Wtorek Środa Czwartek Piątek Sobota)
  MONTHS = %w(. stycznia lutego marca kwietnia maja czerwca lipca sierpnia września października listopada grudnia)

  helpers do
    def id_to_hour(i)
      "#{12 + (i/2).ceil}:#{i%2==0 ? '00' : '30'}"
    end

    def id_to_time(i)
      Time.at(((12 + (i/2).ceil) * 3600) + ((i%2==0 ? 0 : 30) * 60)).utc
    end

    def table_class(table_id, i)
      (@repository.free?(table_id, @date, id_to_time(i)) ? 'success' : 'danger') + " table-link-#{table_id}"
    end

    def previous_date_url
      url('/' + (@date - 1).to_s)
    end

    def next_date_url
      url('/' + (@date + 1).to_s)
    end

    def current_date_text
      "#{WEEKDAYS[@date.wday]}, #{@date.day} #{MONTHS[@date.month]}" 
    end
  end

  before do
    @repository = TableRepository.new
  end 

  get '/' do
    @date = Date.today
    haml :index
  end

  get %r{/(\d{4}-\d{2}-\d{2})} do
    @date = Date.parse(params[:captures].first) 
    haml :index
  end
end
