_ = require "underscore"
timestamps = require "mongoose-timestamps-plugin"
{wrap} = util = require "../util"
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
	name:
		type: String
	description:
		type: String
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
	priority:
		type: String
		enum: ["required", "important", "standard", "optional", "extra"]
	size:
		type: Number

VersionSchema.method "addRepo", (repo) ->
	return if this.repositories and this.repositories.indexOf repo._id
	this.repositories ?= []
	this.repositories.push repo

VersionSchema.plugin timestamps

CydiaPackageSchema = new Schema
	bundleId:
		type: String
		index: unique: true
		required: true
	versions: [VersionSchema]

CydiaPackageSchema.plugin timestamps

CydiaPackageSchema.statics.findOrCreate = (bundleId, cb) ->
	CydiaPackage = this.model "CydiaPackage"
	pkg = new CydiaPackage bundleId: bundleId
	pkg.save (err, pkg) ->
		return cb err if err and err.code isnt 11000
		CydiaPackage.findOne {bundleId: bundleId}, cb

CydiaPackageSchema.methods.version = (version) ->
	return _.detect this.versions, (ver) -> ver.number is version

module.exports = mongoose.model "CydiaPackage", CydiaPackageSchema
