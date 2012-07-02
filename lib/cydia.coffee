_ = require "underscore"
request = require "request"
async = require "async"
humanize = require "humanize"
url = require "url"
zlib = require "zlib"
{WritableStreamBuffer} = require "stream-buffers"
{wrapCallback} = util = require "./util"
redis = require "./redis"

CydiaRepository = require "./model/CydiaRepository"

indexLineRegex = /(.+?)\:\s?(.*)/

parseControlFile = (raw) ->
	lines = raw.trim().split "\n"
	result = []
	currentObj = null
	prevKey = ""
	for line in lines
		unless line
			currentObj = null 
			continue
		result.push currentObj = {} unless currentObj
		if line[0] is " "
			currentObj[prevKey] += line
			continue
		matches = indexLineRegex.exec line
		continue unless matches
		[key, value] = matches.slice 1
		prevKey = key.toLowerCase()
		currentObj[key.toLowerCase()] = value
	return result

module.exports = Cydia = {}

Cydia.getRelease = (repo, cb) ->
	releaseUrl = repo.url
	unless repo.distribution is "./"
		releaseUrl = url.resolve releaseUrl, "dists/#{repo.distribution}/"
	releaseUrl = url.resolve releaseUrl, "Release"

	request.get releaseUrl, (err, resp, body) ->
		return cb() unless resp.statusCode is 200
		cb null, parseControlFile body

Cydia.getPackages = (job, repo, cb) ->
	packagesUrl = repo.url
	unless repo.distribution is "./"
		packagesUrl = url.resolve packagesUrl, "dists/#{repo.distribution}/#{repo.components[0]}/binary-iphoneos-arm/"
	packagesUrl = url.resolve packagesUrl, "Packages"

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

Cydia.processRepository = (job, cb) ->
	CydiaRepository.findById job.data.repo, wrapCallback cb, (repo) ->
		return cb new Error "Couldn't find Repository!" unless repo

		async.parallel [
			(cb) ->
				getRelease repo, wrapCallback cb, (release) ->
					return cb() unless release
					release = release[0]
					job.log "Found Release file. Updating DB."
					repo.label = release.label
					repo.description = release.description
					repo.save cb
			(cb) ->
				getPackages job, repo, wrapCallback cb, (packages) ->
					job.log "#{packages.length} packages in this repo."
					savePackage = (cydiaPackage, cb) ->
						redis.hset "cydia:packages", "#{cydiaPackage.package}", repo._id, cb
					async.forEachSeries packages, savePackage, cb
		], (err) ->
			job.log "Completed crawl of this Repository."
			repo.lastCrawled = new Date()
			repo.save cb

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
