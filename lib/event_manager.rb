# frozen_string_literal: true

require 'csv'
require 'date'
require 'erb'
require 'google/apis/civicinfo_v2'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def clean_phone_numbers(number)
  default = '0000000000'

  digits = number.count('0123456789')

  if digits == 10
    number
  elsif digits == 11 && number[0] == '1'
    number.slice(1, 10)
  else
    default
  end
end

def list_of_peak_hours(data)
  arr = Array.new(24, 0)

  data.each do |row|
    date = DateTime.strptime(row[:regdate], '%m/%d/%y %H:%M')
    hour = date.hour
    arr[hour] += 1
  end

  data.rewind

  arr
end

def list_of_peak_days(data)
  hash = {}
  7.times { |i| hash[Date::DAYNAMES[i]] = 0 }

  data.each do |row|
    date = DateTime.strptime(row[:regdate], '%m/%d/%y %H:%M')
    weekday = date.wday
    hash[Date::DAYNAMES[weekday]] += 1
  end

  data.rewind

  hash
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: %w[legislatorUpperBody legislatorLowerBody]
    ).officials
  rescue StandardError
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

puts 'EventManager initialized.'

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter

# Array of hours with number of registrations, from 0 h to 23 h
hours = list_of_peak_hours(contents)
# Hash of weekdays with number of registrations, starting from Sunday
weekdays = list_of_peak_days(contents)

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  zipcode = clean_zipcode(row[:zipcode])
  legislators = legislators_by_zipcode(zipcode)

  form_letter = erb_template.result(binding)

  save_thank_you_letter(id, form_letter)

  puts "#{row[:homephone]} -> #{clean_phone_numbers(row[:homephone])}"
end

p hours
p weekdays
