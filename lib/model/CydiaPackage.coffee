{useTimestamps} = require "mongoose-types"
{Schema} = mongoose = require "../mongoose"

PersonType = 
	name:
		type: String
	email:
		type: String

VersionSchema = new Schema
	number:
		type: String
		required: true
	repositories: [
		type: Schema.ObjectId
		ref: "CydiaRepository"
	]
	conflicts:
		type: [String]
	replaces:
		type: [String]
	section:
		type: String
	maintainer: PersonType
	author: PersonType
	sponsor:
		name:
			type: String
		url:
			type: String

CydiaPackageSchema = new Schema
	bundleId:
		type: String
		unique: true
		index: true
		required: true
	versions: [VersionSchema]

VersionSchema.plugin useTimestamps
CydiaPackageSchema.plugin useTimestamps

module.exports = mongoose.model "CydiaPackage", CydiaPackage
