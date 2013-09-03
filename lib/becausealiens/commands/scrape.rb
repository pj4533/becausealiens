require 'anemone'
require 'odyssey'
require 'mongo'
require 'fuzzystringmatch'

include Mongo

command :'similar' do |c|
  c.syntax = 'similar ID [...]'
  c.summary = 'Find similar reports'
  c.option '--limit_searched STRING', String, 'Limit number searched for similarity'
  c.action do |args, options|
    say_error "Missing arguments, expected ID" and abort if args.nil? or args.empty?

	trap("INT") { exit }

    reportId = args.first

	host = ENV['MONGO_RUBY_DRIVER_HOST'] || 'localhost'
	port = ENV['MONGO_RUBY_DRIVER_PORT'] || MongoClient::DEFAULT_PORT
	client  = MongoClient.new(host, port, :pool_size => 35, :pool_timeout => 5)
	local = client.db('local')
	aliens = local.collection('ufo_reports')

	initial_report = aliens.find("_id" => BSON::ObjectId(reportId)).to_a[0]   #).limit(100).to_a[15]

	jarow = FuzzyStringMatch::JaroWinkler.create( :native )
	distances = Hash.new

	if options.limit_searched
		aliens.find.limit(options.limit_searched.to_i).each do |report|
			if report['Report']
				jarowDistance = jarow.getDistance(initial_report['Report'], report['Report'])
				distances[report['_id']] = jarowDistance
			end
		end
	else
		aliens.find.each do |report|
			if report['Report']
				jarowDistance = jarow.getDistance(initial_report['Report'], report['Report'])
				distances[report['_id']] = jarowDistance
			end
		end
	end


	sortedDistances = distances.sort_by { |_id, distance| distance }.reverse

	puts initial_report

	indexToShow = 1
	say_ok sortedDistances[indexToShow][1].to_s
	puts aliens.find('_id' => sortedDistances[indexToShow][0]).to_a

  end
end

command :'scrape' do |c|
  c.syntax = 'scrape'
  c.summary = 'Scrape UFO Data'
  c.action do |args, options|

	trap("INT") { exit }

	host = ENV['MONGO_RUBY_DRIVER_HOST'] || 'localhost'
	port = ENV['MONGO_RUBY_DRIVER_PORT'] || MongoClient::DEFAULT_PORT
	client  = MongoClient.new(host, port, :pool_size => 35, :pool_timeout => 5)
	local = client.db('local')
	aliens = local.create_collection('ufo_reports')

	Anemone.crawl("http://www.nuforc.org/webreports/ndxpost.html") do |anemone|
		anemone.on_pages_like %r{^http://www.nuforc.org/webreports/[^.]+/S[^.]+.html$} do |page|
			say_ok page.url.to_s
			doc = page.doc
			outputData = Hash.new			
			if doc.search("tbody tr")[0]
				topText = doc.search("tbody tr")[0].search('td font')[0].inner_html
				topText.split('<br>').each do |textLine|
					splitTextLine = textLine.split(':',2)
					if splitTextLine.count == 2
						outputData[splitTextLine[0].strip] = splitTextLine[1].strip
					end
				end				
			end

			if doc.search("tbody tr")[1]
				bottomText = doc.search("tbody tr")[1].search('td font')[0].inner_html
				outputData['Report'] = bottomText.gsub("<br>", " ")
				outputData['FleschKincaidGrade'] = Odyssey.flesch_kincaid_grade_level(outputData['Report'])
				outputData['FleschKincaidEase'] = Odyssey.flesch_kincaid_reading_ease(outputData['Report'])
				outputData['GunningFog'] = Odyssey.gunning_fog(outputData['Report'])
				outputData['ColemanLiau'] = Odyssey.coleman_liau(outputData['Report'])
				outputData['Smog'] = Odyssey.smog(outputData['Report'])
				outputData['Ari'] = Odyssey.ari(outputData['Report'])				
			end

			# save data to a datasource here
			aliens.insert(outputData)
		end
	end


  end
end
