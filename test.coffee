{CydiaCrawler} = Cydia = require "./lib/cydia"

crawler = new CydiaCrawler {}, "4fe6fbbf31581a35c53a2289"

crawler.on "error", (err) ->
	console.error "err!", err

crawler.on "start", (numPackages) ->
	console.log "Crawling #{numPackages}"

crawler.on "package", (pkg) ->
	console.log "Package.", pkg
