{timestamp} = require "mongoose-troop"
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

CydiaRepositorySchema.plugin timestamp

module.exports = mongoose.model "CydiaRepository", CydiaRepositorySchema
