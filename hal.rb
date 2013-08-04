require 'httparty'
require 'json'
require 'optparse'
require 'pp'
require 'thread'

options = {}

opt_parser = OptionParser.new do |opt|
    opt.on('-h', '--host HOST', 'API host') do |host|
        options[:host] = host
    end

    opt.on('-r', '--root PATH', 'API root') do |root|
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

$host = options[:host]
$root = options[:root]
$email = options[:email]
$password = options[:password]

class Hal

    include HTTParty
    base_uri "https://#{$host}"
    #debug_output $stdout
    format :json
    parser(
        Proc.new do |body, format| 
            parse_hal(body) 
        end
    )
    headers ({
        'Host' => "www.hautelook.com",
        'Accept-Language' => 'en-US,en;q0.8',
        'Accept' => 'application/json',
        'Content-Type' => 'application/json'
    })

    def self.parse_hal(data)
        JSON.parse(data) 
    end

    def self.login
        body = {
            :username => $email,
            :password => $password
        }.to_json

        uri = link_from_rel 'login'
        response = Hal.post(uri, :body => body)
        cookies =  parse_cookies(response.headers['set-cookie'])
        headers 'Cookie' => "PHPSESSID=#{cookies[:PHPSESSID]}"

        response.code == 200
    end

    def self.link_from_rel(rel)
        'https://www.hautelook.com/api/login'
    end

    def self.parse_cookies(cookies)
        cookie_hash = {}
        cookies.split('; ').each do |cookie|
            array = cookie.split('=', 2)
            cookie_hash[array[0].to_sym] = array[1]
        end

        cookie_hash
    end

end

visited = Hash.new
queue = Queue.new
threads = []

queue << $root
#queue << '/api/login'

1.times do 
    threads << Thread.new do
        until queue.empty?
            uri = queue.pop

            begin
                response = Hal.get(uri)

                if response.unauthorized?
                    raise Exception.new unless Hal.login
                    queue << uri
                    next
                end

                response["_links"].each do |link|
                    rel = link[0]
                    next if rel == "self"
                    next if rel == "profile"

                    # temporarily ignore these
                    next if rel == "http://hautelook.com/rels/members"
                    next if rel == "http://hautelook.com/rels/events"

                    if not link[1].has_key?("templated")
                        href = link[1]["href"]
                        queue << href unless visited.has_key?(href)
                        visited[href] = 1
                    end
                end

            rescue
                puts "URI #{uri} failed"
            end
        end
    end
end

threads.each {|t| t.join}
