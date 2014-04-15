require 'twitter'

# Assume client is run once per hour, but we only want ~6 tweets per day
CHANCE_OF_TWEETING = 0.25

@client = Twitter::REST::Client.new do |config|
  config.consumer_key        = ENV["CONSUMER_KEY"]
  config.consumer_secret     = ENV["CONSUMER_SECRET"]
  config.access_token        = ENV["OAUTH_TOKEN"]
  config.access_token_secret = ENV["OAUTH_TOKEN_SECRET"]
end

def codephrase
	# Picturable words from http://en.wiktionary.org/wiki/Appendix:Basic_English_word_list
	nouns = %w{angle ant apple arch arm army baby bag ball band basin basket bath bed bee bell berry bird blade board boat bone book boot bottle box boy brain brake branch brick bridge brush bucket bulb button cake camera card cart carriage cat chain cheese chest chin church circle clock cloud coat collar comb cord cow cup curtain cushion dog door drain drawer dress drop ear egg engine eye face farm feather finger fish flag floor fly foot fork fowl frame garden girl glove goat gun hair hammer hand hat head heart hook horn horse hospital house island jewel kettle key knee knife knot leaf leg library line lip lock map match monkey moon mouth muscle nail neck needle nerve net nose nut office orange oven parcel pen pencil picture pig pin pipe plane plate plough pocket pot potato prison pump rail rat receipt ring rod roof root sail school scissors screw seed sheep shelf ship shirt shoe skin skirt snake sock spade sponge spoon spring square stamp star station stem stick stocking stomach store street sun table tail thread throat thumb ticket toe tongue tooth town train tray tree trousers umbrella wall watch wheel whip whistle window wing wire worm}

	# More fun
	nouns += %w{eagle mouse tentacle albatross puppet sofa racket Pope tonsil spork notion planet}

	prepositions = %w{on in at under beside astride below above within near}

	codephrase = "The #{nouns.sample} is #{prepositions.sample} the #{nouns.sample}."

	return codephrase
end

def location
	location = {}
	lat = rand(-90.000000000...90.000000000)
	long = rand(-180.000000000...180.000000000)
	begin
		geo_results = @client.reverse_geocode(
			              :lat => lat,
			              :long => long,
			              :granularity => 'city',
			              :max_results => 1
			             )
		location = {:place_id => geo_results.first.attrs[:id]}
	rescue Twitter::Error::NotFound => e
		# No matching Place found
		location = {:lat => lat, :long => long}
	rescue Twitter::Error::TooManyRequests => e
		# API Rate limit on reverse_geocode is 15 requests per 15 minutes
		# Cite: https://dev.twitter.com/docs/rate-limiting/1.1/limits
		puts "Rate limit exception on #reverse_geocode"
		location = {:lat => lat, :long => long}
	rescue Twitter::Error::RequestTimeout => e
		# Timeout
		puts "Timeout on #reverse_geocode"
		location = {:lat => lat, :long => long}
	rescue Exception => e
		require 'pp'
		puts "An unexpected exception occured on #reverse_geocode: #{e}"
		location = {:lat => lat, :long => long}
	end

	location
end

if ARGV.size > 0
  puts codephrase
else
	if rand < CHANCE_OF_TWEETING
		begin
		  @client.update codephrase, location
		rescue Exception => e
		  puts "An exception occured: #{e}"
		end
	end
end