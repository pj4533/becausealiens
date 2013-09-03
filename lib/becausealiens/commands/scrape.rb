require 'anemone'
require 'odyssey'
require 'mongo'

include Mongo

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
			topText = doc.search("tbody tr")[0].search('td font')[0].inner_html
			topText.split('<br>').each do |textLine|
				splitTextLine = textLine.split(':',2)
				if splitTextLine.count == 2
					outputData[splitTextLine[0].strip] = splitTextLine[1].strip
				end
			end

			bottomText = doc.search("tbody tr")[1].search('td font')[0].inner_html
			outputData['Report'] = bottomText.gsub("<br>", " ")
			outputData['FleschKincaidGrade'] = Odyssey.flesch_kincaid_grade_level(outputData['Report'])
			outputData['FleschKincaidEase'] = Odyssey.flesch_kincaid_reading_ease(outputData['Report'])
			outputData['GunningFog'] = Odyssey.gunning_fog(outputData['Report'])
			outputData['ColemanLiau'] = Odyssey.coleman_liau(outputData['Report'])
			outputData['Smog'] = Odyssey.smog(outputData['Report'])
			outputData['Ari'] = Odyssey.ari(outputData['Report'])

			# save data to a datasource here
			aliens.insert(outputData)
		end
	end


  end
end
