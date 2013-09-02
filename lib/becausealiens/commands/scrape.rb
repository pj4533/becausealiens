require 'anemone'
require 'odyssey'

command :'scrape' do |c|
  c.syntax = 'scrape'
  c.summary = 'Scrape UFO Data'
  c.action do |args, options|

	trap("INT") { exit }

	Anemone.crawl("http://www.nuforc.org/webreports/ndxp130830.html") do |anemone|
  		anemone.on_pages_like %r{^http://www.nuforc.org/webreports/[^.]+/[^.]+.html$} do |page|
      		say_ok page.url.to_s
  			doc = page.doc
  			outputData = Hash.new
			doc.search("tbody tr").each do |v|
				cells = v.search 'td font'
				textToProcess = cells[0].inner_html

				if /^Occurred/.match textToProcess
					textToProcess.split('<br>').each do |textLine|
						splitTextLine = textLine.split(':',2)
						outputData[splitTextLine[0].strip] = splitTextLine[1].strip
					end
				else
					outputData['Report'] = textToProcess.gsub("<br>", " ")
					outputData['FleschKincaidGrade'] = Odyssey.flesch_kincaid_grade_level(outputData['Report'])
					outputData['FleschKincaidEase'] = Odyssey.flesch_kincaid_reading_ease(outputData['Report'])
					outputData['GunningFog'] = Odyssey.gunning_fog(outputData['Report'])
					outputData['ColemanLiau'] = Odyssey.coleman_liau(outputData['Report'])
					outputData['Smog'] = Odyssey.smog(outputData['Report'])
					outputData['Ari'] = Odyssey.ari(outputData['Report'])
				end
			end

			# save data to a datasource here
			puts outputData
  		end
	end


  end
end
