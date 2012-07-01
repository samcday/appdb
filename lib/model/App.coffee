{Schema} = mongoose = require "../mongoose"

VersionLocaleMetadataSchema = new Schema
	name:
		type: String
		required: true
	description:
		type: String
	whatsNew:
		type: String

VersionSchema = new Schema
	number:
		type: String
		required: true

AppSchema = new Schema
	bundleId:
		type: String
		unique: true
		index: true
		required: true
	type:
		type: String
		default: "undiscovered"
		enum: ["cydia", "itunes", "system", "undiscovered"]
		required: true
	discovery:
		lastAttempt:
			type: Date
		attempts:
			default: 0
			type: Number
	versions:
		type: [VersionSchema]
	itunes:
		appId:
			type: Number

module.exports = mongoose.model "App", AppSchema
