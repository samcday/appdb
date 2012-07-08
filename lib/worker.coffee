_ = require "underscore"
domain = require "domain"
async = require "async"
{wrap} = util = require "./util"
{CydiaCrawler} = Cydia = require "./cydia"
Jobs = require "./jobs"
log = require "./log"

CydiaRepository = require "./model/CydiaRepository"

class JobCoalescer
	constructor: (@masterJob, @jobDoneCb) ->
		@total = 0
		@complete = 0
		@progress = {}
	add: (job) ->
		@total++
		job.on "complete", @_completeHandler
		job.on "failed", @_completeHandler
		job.on "progress", @_progressHandler.bind null, job
	start: (cb) ->
		@doneCb = cb
		return @_done() if @total is @complete
		@started = true
	_done: =>
		@jobDoneCb()
		@doneCb() if @doneCb
	_completeHandler: =>
		@complete++
		return unless @started
		@_done() if @complete is @total
	_progressHandler: (job, progress) =>
		return unless job.id
		@progress[job.id] = progress / 100
		return unless @started
		progress = _.reduce _.values(@progress), (memo, num) =>
			return num + memo
		, 0
		@masterJob.progress progress, @total

jobExecutor = (jobFn) ->
	return (job, done) ->
		dom = domain.create()
		jobLogger = log.jobLogger job
		dom.on "error", (err) ->
			console.error "Uncaught exception in job:", err
			done err
		dom.run ->
			jobFn jobLogger, job, done

cydiaRepositoryJob = (logger, job, done) ->
	crawler = new CydiaCrawler logger, job.data.repoId
	download = total: 0, done: 0
	packages = total: 0, done: 0
	updateProgress = ->
		progress = 0
		if download.total and download.done
			progress = (download.done / download.total) * 0.4
		if packages.total and packages.done
			progress += (packages.done / packages.total) * 0.6
		job.progress progress, 1
	crawler.on "error", (err) -> done err
	crawler.on "complete", -> done()
	crawler.on "download", (done, total) ->
		download.done = done
		download.total = total
		updateProgress()
	crawler.on "package", (pkg, done, total) ->
		logger.debug {pkg: pkg}, "Processed a package." 
		packages.done = done
		packages.total = total
		updateProgress()

cydiaJob = (logger, job, done) ->
	logger.info "Beginning Cydia crawl."
	CydiaRepository.find {}, wrap done, (repositories) ->
		coalesce = new JobCoalescer job, done
		async.forEach repositories, (repository, cb) ->
			logger.info "Queuing crawl for #{repository.url}"
			job = Jobs.create "cydia:repository",
				title: "Cydia Repository - #{repository.url}"
				repoId: repository._id
			coalesce.add job
			job.on "complete", ->
				logger.info "Successfully crawled #{repository.url}"
			job.save wrap cb, ->
				cb()
		, ->
			coalesce.start ->
				logger.info "Cydia crawl complete."
				Jobs.queueCydia 60 * 60 * 1000

Jobs.process "cydia", jobExecutor cydiaJob
Jobs.process "cydia:repository", jobExecutor cydiaRepositoryJob