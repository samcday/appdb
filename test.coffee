{CydiaCrawler} = Cydia = require "./lib/cydia"

crawler = new CydiaCrawler {}, "4fe6fbbf31581a35c53a2289"

crawler.on "error", (err) ->
	console.error "err!", err
crawler.on "start", ->
	console.log "Crawling..."
crawler.on "download", (done, total) ->
	console.log "Downloading... #{done}/#{total}"
crawler.on "package", (pkg) ->
	console.log "Package.", pkg.bundleId
crawler.on "complete", ->
	console.log "all done!"
