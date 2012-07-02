{useTimestamps} = require "mongoose-types"
{Schema} = mongoose = require "../mongoose"
Countries = require "../countries"

ItunesVersionMetadataSchema = new Schema
	country:
		type: String
		enum: Countries.itunesCountries
		required: true
	name:
		type: String
		required: true
	description:
		type: String
	whatsNew:
		type: String

ItunesVersionSchema = new Schema
	number:
		type: String
		required: true
	fileSize:
		type: Number
	metadata: [ItunesVersionMetadataSchema]

ItunesAppSchema = new Schema
	appId:
		type: Number
	versions: [ItunesVersionSchema]

ItunesAppSchema.plugin useTimestamps

module.exports = mongoose.model "ItunesApp", ItunesAppSchema
