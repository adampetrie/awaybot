#!/usr/bin/ruby

require 'rubygems'
require 'bundler/setup'
require 'slack-notifier'
require 'open-uri'
require 'icalendar'
require 'yaml'
require 'date'
require 'pp'

cfg = YAML.load_file("awaybot.yaml")
type = ARGV[0]
if(!cfg.has_key? "#{type}_announce") then
  puts "#{type} is not a known type of announcement."
  Kernel.exit 1
end

ics_raw = URI.parse(cfg['feed_url']).read
ics = Icalendar.parse(ics_raw).first
msg = ""
ics.events.each do |event|
  name = (/[^\-]+/.match event.summary)[0].strip
  next if !cfg['names'].has_value? name
  first_name = cfg['names'].rassoc(name)[0]
  away_start = event.dtstart - 0
  away_end = event.dtend - 1
  return_day = away_end + 1
  # people don't return on the weekend, bump the return day to monday
  return_day += 1 while return_day.saturday? or return_day.sunday?
  away_range = away_start .. away_end
  away_duration = (away_end - away_start).to_i + 1
  # subtract any weekends from the duration
  away_range.each do |date|
    away_duration -= 1 if date.saturday? or date.sunday?
  end
  look_range = Date.today..(Date.today + cfg["#{type}_announce"]['look_forward_days'])
  next if (away_range.to_a & look_range.to_a).empty?
  if(away_start > Date.today) then
    if(away_duration == 1) then
      msg += "#{first_name} is off for the day on #{away_start.strftime("%A")}.\n"
    else
      msg += "#{first_name} is off for #{away_duration} days starting #{away_start.strftime("%A")}.\n"
    end
  else
    if(away_end-Date.today > 0) then
      msg += "#{first_name} is off today and for #{(away_end-Date.today).to_i} more days, returning #{return_day.strftime("%A")}.\n"
    else
      msg += "#{first_name} is off today, returning #{return_day.strftime("%A")}.\n"
    end
  end
end
Kernel.exit(0) if !msg
msg = "Good morning! Here's who's off for the next #{cfg["#{type}_announce"]['look_forward_days']} days.\n#{msg}"
slack = Slack::Notifier.new cfg['slack_hook_url']
slack.ping msg