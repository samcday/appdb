bunyan = require "bunyan"

# Configure a root logger.
logger = bunyan.createLogger
	name: "appdb"
	serializers:
		job: (job) ->
			return {
				id: job.id
				type: job.type
			}

module.exports = logger

# Jacked from bunyan CLI script.
TRACE = 10
DEBUG = 20
INFO = 30
WARN = 40
ERROR = 50
FATAL = 60
levelFromName =
	trace: TRACE
	debug: DEBUG
	info: INFO
	warn: WARN
	error: ERROR
	fatal: FATAL
nameFromLevel = {}
upperNameFromLevel = {}
upperPaddedNameFromLevel = {}
for name of levelFromName
	lvl = levelFromName[name]
	nameFromLevel[lvl] = name
	upperNameFromLevel[lvl] = name.toUpperCase()
	upperPaddedNameFromLevel[lvl] = (if name.length is 4 then " " else "") + name.toUpperCase()

# Appends log messages to an active Kue Job.
class JobLogStream
	constructor: (@job) ->
	write: (record) =>
		@job.log "[#{record.time.toISOString()}] #{upperNameFromLevel[record.level]}: #{record.msg}"

logger.jobLogger = (job) ->
	jobLogger = logger.child job: job, streams: [type: "raw", stream: new JobLogStream job]
	return jobLogger