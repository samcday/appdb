fs = require "fs"
path = require "path"
jsdom = require "jsdom"
{Stream} = require "stream"
{EventEmitter} = require "events"
{spawn} = child_process = require "child_process"
{WritableStreamBuffer} = require "stream-buffers"

module.exports = util = require "util"

# Convenience method, attempts to parse JSON and calls cb with error if it fails
# otherwise it *returns* the parsed JSON object.
util.safeJSONParse = (str, cb) ->
	try
		return JSON.parse str
	catch err
		cb new Error "JSON parse error"

dummy = () ->
util.wrap = util.wrapCallback = wrapCallback = (cb, next) ->
	return (err) ->
		if err?
			return cb.emit "error", err if cb instanceof EventEmitter
			return (cb || dummy) err if err?
		next.apply null, Array.prototype.slice.call arguments, 1

qwery = fs.readFileSync path.join __dirname, "..", "util", "qwery.min.js"
util.qweryify = (html, cb) ->
	jsdom.env
		html: html
		src: [qwery]
		done: cb
		features:
			FetchExternalResources: false

class util.bunzip2 extends Stream
	constructor: ->
		return new util.bunzip2 unless @constructor is util.bunzip2
		Stream.call @
		@readable = true
		@writable = true
		@paused = false
		@_proc = spawn "bunzip2"

		onError = (err) =>
			@destroy()
			@emit "error", err
		@_proc.stdout.on "error", onError
		@_proc.stdin.on "error", onError
		@_proc.stdout.on "data", (data) => @emit "data", data
		@_proc.stdout.on "end", => @emit "end"
		@_proc.stdout.on "close", => 
			@readable = false
			@emit "close"
		@_proc.stdin.on "drain", => @emit "drain"
		@_proc.stdin.on "close", =>
			@writable = false

		errBuffer = new WritableStreamBuffer
		@_proc.stderr.pipe errBuffer
		@_proc.on "exit", (retval) ->
			unless retval is 0
				err = new Error errBuffer.getContentsAsString()
				err.code = retval
				onError err

	setEncoding: (encoding) ->
		@_proc.stdout.setEncoding encoding
	pause: ->
		@paused = true
		@_proc.stdout.pause()
	resume: ->
		@paused = false
		@_proc.stdout.resume()
	destroy: ->
		@readable = false
		@writable = false
		@_proc.stdin.destroy()
		@_proc.stdout.destroy()
	destroySoon: ->
		@readable = false
		@_proc.stdin.destroy()
		@_proc.stdout.destroySoon()
	write: ->
		@_proc.stdin.write.apply @_proc.stdin, arguments
	end: ->
		@_proc.stdin.end.apply @_proc.stdin, arguments
