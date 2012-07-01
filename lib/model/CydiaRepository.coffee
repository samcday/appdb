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
	lastCrawled:
		type: Date

module.exports = mongoose.model "CydiaRepository", CydiaRepositorySchema
