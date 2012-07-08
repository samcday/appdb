kue = require "kue"
module.exports = Jobs = kue.createQueue()
Jobs.app = kue.app
Jobs.promote()

Jobs.queueCydia = (delay = 0, cb) ->
	job = Jobs.create "cydia",
		title: "Cydia Crawl"
	job.delay delay if delay
	job.save ->
		cb job if cb
