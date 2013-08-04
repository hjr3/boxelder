require 'httparty'
require 'halidator'
require 'json'
require 'optparse'
require 'pp'
require 'thread'
require_relative 'boxelder/hal'

options = {}

opt_parser = OptionParser.new do |opt|
    opt.on('-r', '--root PATH', 'URI of API root') do |root|
        options[:root] = root
    end

    opt.on('-e', '--email EMAIL', 'API login email') do |email|
        options[:email] = email
    end

    opt.on('-p', '--password PASSWORD', 'API login password') do |password|
        options[:password] = password
    end
end

opt_parser.parse!

root = options[:root]
email = options[:email]
password = options[:password]

visited = Hash.new
queue = Array.new

queue.push root

hal = Hal.new email, password

until queue.empty?
    uri = queue.shift

    begin
        next if visited.has_key?(uri) 
        
        hrefs = hal.crawl(uri)
        puts "Crawled #{uri}"
        hrefs.each do |href|
            queue.push href
        end
    rescue Exception => e
        puts "URI #{uri} failed"
        puts e.message
    end

    visited[uri] = 1
end
