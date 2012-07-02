{useTimestamps} = require "mongoose-types"
{Schema} = mongoose = require "../mongoose"

VersionSchema = new Schema
	plistJson:
		type: String
		select: false

VersionSchema.virtual("plist")
	.get -> return if this.plistJson then JSON.parse this.plistJson else null

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
		type: Schema.ObjectId
		ref: "ItunesApp"
	cydia:
		type: Schema.ObjectId
		ref: "CydiaPackage"

AppSchema.plugin useTimestamps

module.exports = mongoose.model "App", AppSchema
