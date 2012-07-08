_ = require "underscore"
BufferStream = require "bufferstream"
domain = require "domain"
request = require "request"
async = require "async"
humanize = require "humanize"
url = require "url"
zlib = require "zlib"
ControlParser = require "debian-control-parser"
{WritableStreamBuffer} = require "stream-buffers"
{wrap} = util = require "./util"
redis = require "./redis"

CydiaRepository = require "./model/CydiaRepository"
CydiaPackage = require "./model/CydiaPackage"

regex =
	person: /^(.*?)\s*<(.*?)>$/

module.exports = Cydia = {}

get = (url, allow404 = false) ->
	stream = request.get url
	stream.on "response", (response) ->
		return if response.statusCode is 200
		return if response.statusCode is 404 and allow404
		stream.emit "error", new Error "Response returned status #{response.statusCode}"
	return stream

parsePerson = (str) ->
	return null unless matches = regex.person.exec str
	return name: matches[1].trim(), email: matches[2].trim()

parseSponsor = (str) ->
	return null unless matches = regex.person.exec str
	return name: matches[1].trim(), url: matches[2].trim()

buildRepoBaseUrl = (repo) ->
	baseUrl = repo.url
	baseUrl = url.resolve baseUrl, "dists/#{repo.distribution}/" unless repo.distribution is "./"
	return baseUrl

buildPackagesUrl = (repo) ->
	packagesUrl = buildRepoBaseUrl(repo)
	packagesUrl = url.resolve packagesUrl, "#{repo.components[0]}/binary-iphoneos-arm/" unless repo.distribution is "./"
	return packagesUrl

findPackageFile = (packagesUrl, cb) ->
	packagesUrls = [
		"#{packagesUrl}.bz2"
		"#{packagesUrl}.gz"
		packagesUrl
	]
	headPackage = (url, cb) ->
		request.head url, (err, resp, body) ->
			cb if err then false else resp.statusCode is 200
	async.detectSeries packagesUrls, headPackage, (url) ->
		return cb new Error "Couldn't find Packages!" unless url
		cb null, url

Cydia.processPackage = (packageData, repo, cb) ->
	CydiaPackage.findOrCreate packageData.Package, wrap cb, (pkg) ->
		ver = pkg.version packageData.Version
		if not ver
			ver = pkg.newVersion packageData.Version
			ver.number = packageData.Version
			ver.repositories = [repo]
			ver.name = packageData.Name
			ver.description = packageData.description
			ver.section = packageData.Section
			ver.maintainer = parsePerson packageData.Maintainer
			ver.author = parsePerson packageData.Author
			ver.sponsor = parseSponsor packageData.Sponsor
			ver.priority = packageData.Priority if packageData.Priority
			ver.size = packageData.Size
			ver.tags.push tag.trim() for tag in packageData.Tag.split "," if packageData.Tag
			# TODO: conflicts/replaces/etc
		else
			# Make sure this repository is listed for this version.
			ver.addRepo repo
		pkg.save wrap cb, ->
			cb null, pkg

Cydia.getPackages = (logger, repo, cb) ->
	packagesUrl = url.resolve buildPackagesUrl(repo), "Packages"
	logger.debug "Looking for Packages using base #{packagesUrl}"
	findPackageFile packagesUrl, wrap cb, (url) ->
		logger.info "Found Packages @ #{url}. Downloading."
		stream = get url
		out = if /bz2$/.test url then stream.pipe new util.bunzip2 else
			if /gz$/.test url then stream.pipe zlib.createGzip()
			else stream
		out.setEncoding "utf8"
		stream.on "response", (response) ->
			streamSize = response.headers["content-length"]
			return unless streamSize
			out.emit "download", 0, streamSize
			downloaded = 0
			stream.on "data", (data) -> out.emit "download", downloaded += data.length, streamSize
		cb null, out

module.exports.CydiaCrawler = class CydiaCrawler extends process.EventEmitter
	constructor: (@logger, repoId) ->
		@dom = domain.create()
		@dom.on "error", (err) =>
			@emit "error", err
		CydiaRepository.findById repoId, @dom.intercept (repo) =>
			@repo = repo

			async.parallel [
				@_getRelease
				@_getPackages
			], @dom.intercept =>
				repo.lastSuccessfulCrawl = new Date()
				repo.save @dom.intercept =>
					@emit "complete"
		return @
	_getRelease: (cb) =>
		releaseUrl = url.resolve buildRepoBaseUrl(@repo), "Release"
		@logger.info "Attempting to download Release from #{releaseUrl}"
		control = ControlParser get releaseUrl, true
		release = null
		control.once "stanza", (stanza) -> release = stanza
		control.on "done", =>
			return cb() unless release
			@logger.info "Found a Release file."
			@logger.trace {release: release}, "Release stanza."
			@repo.label = release.label
			@repo.description = release.description
			@repo.save cb
	_getPackages: (cb) =>
		repo = @repo
		Cydia.getPackages @logger, repo, wrap cb, (stream) =>
			@emit "start"

			q = null
			control = null
			totalStanzas = 0
			processed = 0
			foundAllStanzas = false
			stanzaHandler = null

			packagesDom = domain.create()
			packagesDom.add stream
			packagesDom.on "error", (err) =>
				@logger.error warn, "Failed to process packages."
				q.tasks = []
				q.concurrency = 0
				control.removeListener "stanza", stanzaHandler
				packagesDom.dispose()
				@emit "error", err

			packagesDom.run =>
				stanzaHandler = (stanza) =>
					totalStanzas++
					q.push { data: stanza }, (err, pkg) =>
						if err
							err.pkg = pkg
							throw err
						return if err?
						@emit "package", pkg, ++processed, if foundAllStanzas then totalStanzas else 0
				q = async.queue (job, cb) =>
					@logger.trace {stanza: job.data}, "Processing package."
					Cydia.processPackage job.data, repo, (err) =>
						@logger.warn {err: err, stanza: job.data}, "Failed to process package." if err
						cb()
				, 10
				control = ControlParser stream
				control.on "stanza", stanzaHandler
				control.on "done", =>
					foundAllStanzas = true
					# Wait for the queue to finish if necessary.
					if q.running() then q.drain = cb else cb()
				stream.on "download", (done, total) =>
					@emit "download", done, total

###

Cydia.queueCrawl = ->
	log.info "[cydia] Queuing crawl."
	job = jobs.create "cydia", title: "Cydia crawl"
	job.save()

Cydia.queueRepository = (repo) ->
	log.info "[cydia] Queuing crawl of repository #{repo.url}."
	job = jobs.create "cydia:repository", title: "Cydia repository crawl (#{repo.url})", repo: repo._id
	job.save()
	return job

Cydia.processCrawl = (job, cb) ->
	CydiaRepository.find {}, wrap cb, (repos) ->
		completedRepos = 0
		onComplete = ->
			job.progress ++completedRepos, repos.length
			if completedRepos is repos.length
				cb()
		for repo in repos
			do (repo) ->
				repoJob = Cydia.queueRepository repo
				repoJob.on "complete", onComplete

Cydia.isCydiaApp = (bundleId, cb) ->
	redis.hget "cydia:packages", bundleId, wrap cb, (repoId) ->
		return cb() unless repoId
		CydiaRepository.findById repoId, cb
###
