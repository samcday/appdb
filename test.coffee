{CydiaCrawler} = require "./lib/cydia"

crawler = new CydiaCrawler {}, "4fe6fbbf31581a35c53a2287"

crawler.on "error", (err) ->
	console.error "err!", err