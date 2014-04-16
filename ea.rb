require 'twitter'

# Assume client is run once every ten minutes but we only want ~6 tweets per day
CHANCE_OF_TWEETING = 0.042

@client = Twitter::REST::Client.new do |config|
  config.consumer_key        = ENV["CONSUMER_KEY"]
  config.consumer_secret     = ENV["CONSUMER_SECRET"]
  config.access_token        = ENV["OAUTH_TOKEN"]
  config.access_token_secret = ENV["OAUTH_TOKEN_SECRET"]
end

@tweets_sent = 0

# Picturable words from http://en.wiktionary.org/wiki/Appendix:Basic_English_word_list
@nouns = %w{angle ant apple arch arm army baby bag ball band basin basket bath bed bee bell berry bird blade board boat bone book boot bottle box boy brain brake branch brick bridge brush bucket bulb button cake camera card cart carriage cat chain cheese chest chin church circle clock cloud coat collar comb cord cow cup curtain cushion dog door drain drawer dress drop ear egg engine eye face farm feather finger fish flag floor fly foot fork fowl frame garden girl glove goat gun hair hammer hand hat head heart hook horn horse hospital house island jewel kettle key knee knife knot leaf leg library line lip lock map match monkey moon mouth muscle nail neck needle nerve net nose nut office orange oven parcel pen pencil picture pig pin pipe plane plate plough pocket pot potato prison pump rail rat receipt ring rod roof root sail school scissors screw seed sheep shelf ship shirt shoe skin skirt snake sock spade sponge spoon spring square stamp star station stem stick stocking stomach store street sun table tail thread throat thumb ticket toe tongue tooth town train tray tree trousers umbrella wall watch wheel whip whistle window wing wire worm}
# More fun
@nouns += %w{eagle mouse tentacle albatross puppet sofa racket Pope tonsil spork notion planet tadpole}

@prepositions = %w{on in at under beside astride below above within near aboard beyond behind following underneath within upon unlike past}

# Common adverbs from http://www.gtchild.co.uk/content/index.php?option=com_content&task=view&id=280&Itemid=70
@adverbs = %w{accidentally afterwards almost always angrily annually anxiously awkwardly badly blindly boastfully boldly bravely briefly brightly busily calmly carefully carelessly cautiously cheerfully clearly correctly courageously crossly cruelly daily defiantly deliberately doubtfully easily elegantly enormously enthusiastically equally even eventually exactly faithfully far fast fatally fiercely fondly foolishly fortunately frantically gently  gladly gracefully greedily happily hastily honestly hourly hungrily innocently inquisitively irritably joyously justly kindly lazily less loosely loudly madly merrily monthly mortally mysteriously nearly neatly nervously never noisily obediently obnoxiously often only painfully perfectly politely poorly powerfully promptly punctually quickly quietly rapidly rarely really recklessly regularly reluctantly repeatedly rightfully roughly rudely sadly safely seldom selfishly seriously shakily sharply shrilly shyly silently sleepily slowly smoothly softly solemnly sometimes soon speedily stealthily sternly successfully suddenly suspiciously swiftly tenderly tensely thoughtfully tightly tomorrow truthfully unexpectedly victoriously violently vivaciously warmly weakly wearily well wildly yearly}
@adverbs += ['at midnight', 'willfully', 'indignantly', 'forever', 'weekly', 'at dawn', 'at once', 'tonight']

@transitive_verbs = %w{brings gives lends offers passes plays reads sends sings teaches writes buys gets leaves makes owes pays promises refuses shows takes tells}

@transitive_verbs_past_participle = %w{brought given leant offered passed played read sent sung taught written bought gotten left made owed paid promised refused shown taken told}

@intransitive_verbs = %w{agrees appears arrives becomes belongs collapses collides consists costs depends dies disappears emerges exists falls goes happens knocks laughs lies lives looks lasts occurs remains responds rises sits sleeps stands stays swims vanishes waits}

@adjectives = %w{able acid angry automatic beautiful black boiling bright broken brown cheap chemical chief clean clear common complex conscious cut deep dependent early elastic electric equal fat fertile first fixed flat free frequent full general good great grey hanging happy hard healthy high hollow important kind like living long male married material medical military natural necessary new normal open parallel past physical political poor possible present private probable quick quiet ready red regular responsible right round same second separate serious sharp smooth sticky stiff straight strong sudden sweet tall thick tight tired true violent waiting warm wet wide wise yellow young}
@adjectives += %w{wax stone slippery pious honorable despicable}

@passive_modifiers = ['will be', 'has been', 'is', 'was', 'may have', 'could have', 'often']

def adverb
  @adverbs.sample
end

def adjective
  result = @adjectives.sample 
  if rand < 0.25
    result = adverb + ' ' + result    
  end
  result
end

def noun
  result = @nouns.sample
  if rand < 0.25
    result = adjective + ' ' + result
  end
  result
end

def intransitive_verb
  @intransitive_verbs.sample
end

def transitive_verb_past_participle
  result = @transitive_verbs_past_participle.sample
  if rand < 0.25
    result = adverb + ' ' + result
  end
  result
end

def codephrase
	codephrases = []
	# The NOUN is PREOPOSITION the NOUN.
	codephrases << "The #{noun} is #{@prepositions.sample} the #{noun}."
	# The NOUN has VERBED the NOUN.
  codephrases << "The #{noun} has #{transitive_verb_past_participle} the #{noun}."
	# The NOUN [has been|is|will be] VERBED.
  codephrases << "The #{noun} #{@passive_modifiers.sample} the #{transitive_verb_past_participle}."
	# The NOUN VERBS at TIME.
	# The NOUN VERBS ADVERB.
	codephrases << "The #{noun} #{intransitive_verb} #{adverb}."
	# In PLACE there is a NOUN that VERBS.
	# How is a NOUN like a NOUN? <— problem: article inflection (a/n)

	# CODEPHRASE I repeat CODEPHRASE
	#if rand < 0.01 ...

	return codephrases.sample
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

# Get the 20 newest followers
def followers
  @client.followers.take(20)
end

# Get the 20 most recent mentions
def mentions
	@client.mentions_timeline
end

def react_to_new_mentions
	mentions.reverse.each do |m|
		# Reply to mention unless this has already been done
		tweet_codephrase(m) unless replied_to?(m)
		# Try and follow mentioner
		@client.follow(m.user)
    sleep(rand(5...15))
	end
end

def replied_to?(tweet)
	tweets = @client.user_timeline(:since_id => tweet.id)
	tweets.each do |t|
		return true if t.in_reply_to_status_id == tweet.id
	end
	return false
end

def tweet_codephrase(in_reply_to = nil)
	options = location
	status  = codephrase

	if in_reply_to
		options = options.merge :in_reply_to_status_id => in_reply_to.id
		status = "@#{in_reply_to.user.username} " + status
	end

	begin
	  @client.update status, options
	  @tweets_sent += 1
    puts "Tweeted: #{status}"
	rescue Exception => e
	  puts "An exception occured: #{e}"
	end
end

def run
	react_to_new_mentions
	if @tweets_sent == 0 and rand < CHANCE_OF_TWEETING
	  tweet_codephrase
	end
end

def usage 
	puts "Usage:"
	puts "  ea.rb run        - normal execution      (may post to Twitter)"
	puts "  ea.rb react      - react to new mentions (may post to Twitter)"
	puts "  ea.rb codephrase - generate a random codephrase"
	puts "  ea.rb location   - generate a random location"
	puts "  ea.rb followers  - list 20 newest followers"
	puts "  ea.rb mentions   - list 20 newest mentions"
end

if ARGV.size != 1
	usage
elsif ARGV[0] == 'run'
	run
elsif ARGV[0] == 'react'
	react_to_new_mentions
elsif ARGV[0] == 'codephrase'
	puts codephrase
elsif ARGV[0] == 'location'
	puts location.to_s
elsif ARGV[0] == 'followers'
	followers.each {|f| puts "@#{f.username}"}
elsif ARGV[0] == 'mentions'
	mentions.each {|m| puts "@#{m.user.username}: #{m.full_text} (#{m.created_at}"}
else 
	usage
end	

#elsif ARGV[1] == 'run'
#  run
