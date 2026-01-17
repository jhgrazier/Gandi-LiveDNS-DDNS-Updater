#!/usr/bin/env ruby
require "json"
require "net/http"
require "uri"

CONFIG_FILE = ARGV[0] || "/home/pi/ddns/config.txt"

def parse_config(path)
  raise "Config file not found: #{path}" unless File.exist?(path)

  cfg = {}
  current = nil

  File.readlines(path).each do |line|
    line = line.strip
    next if line.empty? || line.start_with?("#", ";")

    if line =~ /^\[(.+)\]$/
      current = Regexp.last_match(1)
      cfg[current] ||= {}
    elsif line.include?("=")
      k, v = line.split("=", 2).map(&:strip)
      cfg[current][k] = v
    end
  end

  cfg
end

def external_ipv4
  ip = `curl -fsS https://api.ipify.org`.strip
  unless ip.match?(/\A(?:\d{1,3}\.){3}\d{1,3}\z/)
    raise "Invalid IPv4 from ipify: #{ip.inspect}"
  end
  octets = ip.split(".").map(&:to_i)
  raise "Invalid IPv4 from ipify: #{ip.inspect}" if octets.any? { |o| o > 255 }
  ip
end

def http_request(method, url, token, body = nil)
  uri = URI(url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true

  req =
    case method
    when :get then Net::HTTP::Get.new(uri)
    when :put then Net::HTTP::Put.new(uri)
    else raise "Unsupported HTTP method"
    end

  req["Authorization"] = "Bearer #{token}"
  req["Accept"] = "application/json"
  req["Content-Type"] = "application/json"
  req.body = JSON.generate(body) if body

  http.request(req)
end

config = parse_config(CONFIG_FILE)
general = config["general"] || raise("Missing [general] section")

api_base = general["api"].sub(%r{/$}, "")
token    = general["api_key"] or raise("Missing api_key")

ip = external_ipv4

config.each do |section, r|
  next if section == "general"

  domain = r["domain"]
  name   = r["name"]
  type   = r["type"]
  ttl    = r["ttl"].to_i

  endpoint = "#{api_base}/livedns/domains/#{domain}/records/#{name}/#{type}"

  get = http_request(:get, endpoint, token)

  if get.code.to_i == 200
    current = JSON.parse(get.body)
    current_ip = current["rrset_values"]&.first
    if current_ip == ip
      puts "#{section}: no change (#{ip})"
      next
    end
  elsif get.code.to_i != 404
    puts "#{section}: GET failed (HTTP #{get.code})"
    puts get.body
    next
  end

  payload = {
    "rrset_ttl" => ttl,
    "rrset_values" => [ip]
  }

  put = http_request(:put, endpoint, token, payload)

  if [200, 201].include?(put.code.to_i)
    puts "#{section}: updated to #{ip}"
  else
    puts "#{section}: UPDATE FAILED (HTTP #{put.code})"
    puts put.body
  end
end
