require 'csv'
require 'geocoder'
require 'pry'

class CSVGeocoder
  class AddressNotFoundError < ArgumentError; end
  class NoCSVToWriteError < StandardError; end
  ADDRESS_NOT_FOUND_MESSAGE =
    'The address column was not found in the CSV using the address label given.'
  NO_CSV_TO_WRITE =
    'No CSV file to write, please call add_geocode before writing'
  EMPTY_GEOCODE = { 'lat' => nil, 'lng' => nil }
  TITLE_GEOCODE = { 'lat' => 'Latitude', 'lng' => 'Longitude' }
  ERROR_GEOCODE = { 'lat' => 'API Error', 'lng' => 'API Error' }
  attr_accessor :csv, :address_label, :delay
  attr_reader :new_csv

  def initialize(file, address = 'Address')
    @address_label = address
    @delay = 0.21
    @new_csv = nil
    read(file)
  end

  def read(file)
    @csv = CSV.read(file)
    self
  end

  def add_geocode
    @new_csv = merge_csv_with lat_lngs
    self
  end

  def write(file)
    fail NoCSVToWriteError if @new_csv.nil?
    CSV.open(file, 'wb') do |csv|
      @new_csv.each do |row|
        csv << row
      end
    end
  end

  protected

  def lat_lngs
    addresses.map do |address|
      lat_lng address
    end
  end

  def addresses
    fail AddressNotFoundError, ADDRESS_NOT_FOUND_MESSAGE if address_index.nil?
    @csv.map do |row|
      row[address_index]
    end
  end

  def lat_lng(address)
    return TITLE_GEOCODE if matches_address_label? address
    return EMPTY_GEOCODE if no_address? address
    sleep @delay
    gc = Geocoder.search(address)
    if gc.first.respond_to? :geometry
      gc.first.geometry['location']
    else
      # this gem doesn't raise or return an error message,
      # just prints to stdout. Let's pass this error along to the CSV output
      ERROR_GEOCODE
    end
  end

  def address_index
    @csv[0].index { |label| matches_address_label? label }
  end

  def matches_address_label?(addr)
    address_regex.match(addr)
  end

  def address_regex
    Regexp.new(@address_label, Regexp::IGNORECASE)
  end

  def no_address?(addr)
    addr.nil? || addr.empty?
  end

  def merge_csv_with(lat_lng)
    @csv.each do |row|
      this_lat_lng = lat_lng.shift
      row << this_lat_lng['lat'] << this_lat_lng['lng']
    end
  end
end
