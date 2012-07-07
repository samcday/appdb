timestamps = require "mongoose-timestamps-plugin"
{Schema} = mongoose = require "../mongoose"

CydiaRepositorySchema = new Schema
	url:
		type: String
	distribution:
		type: String
	components:
		type: [String]
	label:
		type: String
	description:
		type: String
	lastSuccessfulCrawl:
		type: Date

CydiaRepositorySchema.plugin timestamps

module.exports = mongoose.model "CydiaRepository", CydiaRepositorySchema
