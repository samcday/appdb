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
{wrapCallback} = util = require "./util"
redis = require "./redis"

CydiaRepository = require "./model/CydiaRepository"

module.exports = Cydia = {}

get = (url, allow404 = false) ->
	stream = request.get url
	stream.on "response", (response) ->
		return if response.statusCode is 200
		return if response.statusCode is 404 and allow404
		stream.emit "error", new Error "Response returned status #{response.statusCode}"
	return stream

buildRepoBaseUrl = (repo) ->
	baseUrl = repo.url
	url = url.resolve url, "dists/#{repo.distribution}/" unless repo.distribution is "./"
	return baseUrl

Cydia.getRelease = (repo, cb) ->
	releaseUrl = url.resolve buildRepoBaseUrl, "Release"
	control = ControlParser get releaseUrl, true
	releaseStanza = null
	control.once "stanza", (stanza) -> releaseStanza = stanza
	control.on "done", -> cb null, releaseStanza

buildPackagesUrl = (repo) ->
	packagesUrl = buildRepoBaseUrl()
	packagesUrl = url.resolve packagesUrl, "#{repo.components[0]}/binary-iphoneos-arm/" unless repo.distribution is "./"
	return packagesUrl

findPackageFile = (base, cb) ->
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

Cydia.getPackages = (job, repo, cb) ->
	packagesUrl = url.resolve buildPackagesUrl, "Packages"

	findPackageFile packagesUrl, wrapCallback cb, (url) ->
		stream = request.get url

		streamSize = 0
		stream.on "response", (response) ->
			streamSize = response.headers["content-length"]
			job.log "Downloading Packages from #{url}. Size: #{humanize.filesize(streamSize)}"
			if streamSize
				downloaded = 0
				stream.on "data", (data) ->
					downloaded += data.length
					job.progress downloaded, streamSize

		packageBuffer = new WritableStreamBuffer
		if /bz2$/.test url
			stream.pipe(new util.bunzip2).pipe packageBuffer
		else if /gz$/.test url
			stream.pipe(zlib.createGzip()).pipe packageBuffer
		else
			stream.pipe packageBuffer

		packageBuffer.on "close", ->
			cb null, parseControlFile packageBuffer.getContentsAsString()

Cydia.processRepository = (repo, cb) ->
	CydiaRepository.findById job.data.repo, wrapCallback cb, (repo) ->
		return cb new Error "Couldn't find Repository!" unless repo

module.exports.CydiaCrawler = class CydiaCrawler extends process.EventEmitter
	constructor: (@log, repoId) ->
		@dom = domain.create()
		@dom.on "error", (err) =>
			@emit "error", err
		CydiaRepository.findById repoId, @dom.intercept (repo) =>
			async.parallel [
				(cb) ->
					Cydia.getRelease repo, wrapCallback cb, (release) ->
						return cb() unless release
						console.log release
						return
						release = release[0]
						repo.label = release.label
						repo.description = release.description
						repo.save cb
					###
					(cb) ->
						getPackages job, repo, wrapCallback cb, (packages) ->
							@emit "start", packages.length
							savePackage = (cydiaPackage, cb) ->
								# redis.hset "cydia:packages", "#{cydiaPackage.package}", repo._id, cb
								@emit "package", cydiaPackage
							async.forEachSeries packages, savePackage, cb
					###
			], @dom.intercept ->
				return
				repo.lastSuccessfulCrawl = new Date()
				repo.save @dom.intercept ->
					@emit "complete"

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
	CydiaRepository.find {}, wrapCallback cb, (repos) ->
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
	redis.hget "cydia:packages", bundleId, wrapCallback cb, (repoId) ->
		return cb() unless repoId
		CydiaRepository.findById repoId, cb
###
