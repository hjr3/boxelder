class Hal

    include HTTParty
    #debug_output $stdout
    format :json
    parser(
        Proc.new do |body, format| 
            JSON.parse(body) 
        end
    )
    headers ({
        'Host' => "www.hautelook.com",
        'Accept-Language' => 'en-US,en;q0.8',
        'Accept' => 'application/json',
        'Content-Type' => 'application/json'
    })

    def initialize(email, password)
        @email = email
        @password = password

    end

    def crawl(uri)
        response = self.class.get(uri)

        hrefs = Array.new

        if response.unauthorized?
            puts "Unauthorized request for #{uri}, trying to login"
            response = login
            raise Exception.new unless response.code == 200

            puts "Requesting #{uri} again after successful login"
            response = self.class.get(uri)
        end

        if not Halidator.new(response, :json_schema).valid?
            puts "Invalid response from #{uri}"
            return hrefs
        end

        response["_links"].each do |link|
            rel = link[0]
            next if rel == "self"
            next if rel == "profile"
            next if link[1].has_key?("templated")

            # temporarily ignore these
            next if rel == "http://hautelook.com/rels/members"
            next if rel == "http://hautelook.com/rels/events"

            hrefs << link[1]["href"]
        end

        hrefs
    end

    def login
        body = {
            :username => @email,
            :password => @password
        }.to_json

        uri = link_from_rel 'login'
        response = self.class.post(uri, :body => body)
        cookies =  parse_cookies(response.headers['set-cookie'])
        self.class.headers 'Cookie' => "PHPSESSID=#{cookies[:PHPSESSID]}"

        response
    end

    def link_from_rel(rel)
        'https://www.hautelook.com/api/login'
    end

    def parse_cookies(cookies)
        cookie_hash = {}
        cookies.split(', ').each do |cookie|
            parts = cookie.split(';', 2)
            array = parts[0].split('=', 2)
            cookie_hash[array[0].to_sym] = array[1]
        end

        cookie_hash
    end
end
