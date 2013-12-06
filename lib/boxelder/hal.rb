class Hal

    include HTTParty
    #debug_output $stdout
    format :json
    parser(
        Proc.new do |body, format| 
            JSON.parse(body) if body && body.length >= 2
        end
    )

    def initialize(email, password)
        @email = email
        @password = password
        @cookie_jar = HTTP::CookieJar.new

    end

    def crawl(uri)
        cookie_header = HTTP::Cookie.cookie_value(@cookie_jar.cookies(uri))

        response = self.class.get(uri, :headers => {'Cookie' => cookie_header})

        hrefs = Array.new

        if response.unauthorized?
            puts "Unauthorized request for #{uri}, trying to login"
            response = login
            raise Exception.new unless response.code == 200

            puts "Requesting #{uri} again after successful login"
            cookie_header = HTTP::Cookie.cookie_value(@cookie_jar.cookies(uri))
            response = self.class.get(uri, :headers => {'Cookie' => cookie_header})
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
        response.headers.get_fields('set-cookie').each do |value|
            uri = response.request.uri

            @cookie_jar.parse(value, uri)
        end

        response
    end

    def link_from_rel(rel)
        'https://www.hautelook.com/api/login'
    end

end
