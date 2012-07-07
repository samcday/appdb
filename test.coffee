###
request = require "request"
util = require "./lib/util"
fs = require "fs"
StreamSplitter = require "stream-splitter"
ControlParser = require "debian-control-parser"

#stream = request.get "http://apt.modmyi.com/dists/stable/main/binary-iphoneos-arm/Packages.bz2"
stream = fs.createReadStream "/tmp/Packages.huge"
#stream = fs.createReadStream "downloaded"
# stream = fs.createReadStream "/home/sam/Downloads/Packages\ (1).bz2"
#stream = fs.createReadStream "/tmp/wtfux"
# stream = stream.pipe new util.bunzip2
# stream.setEncoding "utf8"

splitter = stream.pipe StreamSplitter("\n")
control = ControlParser stream

# process.stdout.setEncoding "utf8"
# stream.pipe process.stdout
# splitter.on "token", (line) -> console.log line.toString()
control.on "stanza", (stanza) -> console.log stanza

return
###

{CydiaCrawler} = Cydia = require "./lib/cydia"

# crawler = new CydiaCrawler {}, "4fe6fbbf31581a35c53a2289"
# crawler = new CydiaCrawler {}, "4fe6fbbf31581a35c53a2288"
# crawler = new CydiaCrawler {}, "4fe6fbc031581a35c53a228b"
# crawler = new CydiaCrawler {}, "4fe6fbbf31581a35c53a228a"
# crawler = new CydiaCrawler {}, "4fe6fbbf31581a35c53a2287"
crawler = new CydiaCrawler {}, "4fe6faf8b261df4356000001"


downloading = false
done = 0
total = 0
donePackages = 0
totalPackages = 0
blank = "                                                      "
printStatusLine = ->
	statusLine = ""
	if downloading
		statusLine += "Downloading #{done}/#{total}"
	if donePackages > 0
		statusLine += ". " if statusLine
		statusLine += "Packages: #{donePackages} / #{totalPackages}"
	process.stdout.write "#{blank}\r#{statusLine}\r"

crawler.on "error", (err) ->
	console.error "err!", err
crawler.on "start", ->
	printStatusLine()
crawler.on "download", (_done, _total) ->
	done = _done
	total = _total	
	downloading = done < total
	printStatusLine()
crawler.on "package", (pkg, _done, _total) ->
	donePackages = _done
	totalPackages = _total
	printStatusLine()
crawler.on "complete", ->
	console.log "\n\n... all done!"
