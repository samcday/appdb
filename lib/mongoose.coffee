mongoose = require "mongoose"

mongoose.connect "mongodb://localhost/appdb"

module.exports = mongoose