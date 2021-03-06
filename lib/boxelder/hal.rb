class Hal

    include HTTParty
    format :json
    parser(
        Proc.new do |body, format| 
            JSON.parse(body) if body && body.length >= 2
        end
    )

    def initialize(email, password, verbose)
        @email = email
        @password = password
        self.class.debug_output $stdout if verbose
        @cookie_jar = HTTP::CookieJar.new
        @rels = Hash.new

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

        # some responses may not have any json
        return hrefs if response.body.length == 0

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

            href = link[1]["href"]

            @rels[rel] = href
            hrefs << href
        end

        hrefs
    end

    def login
        body = {
            :username => @email,
            :password => @password
        }.to_json

        uri = link_from_rel 'http://hautelook.com/rels/login'
        response = self.class.post(uri, :body => body)
        response.headers.get_fields('set-cookie').each do |value|
            uri = response.request.uri

            @cookie_jar.parse(value, uri)
        end

        response
    end

    def link_from_rel(rel)
        raise "No relation found: #{rel}" if not @rels.has_key?(rel)

        @rels[rel]
    end

end
