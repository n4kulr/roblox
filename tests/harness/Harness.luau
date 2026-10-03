local Test = require("./Test")
local World = require("./World")

return {
	newWorld = World.new,
	deepCopy = World.deepCopy,
	describe = Test.describe,
	it = Test.it,
	expect = Test.expect,
	beforeEach = Test.beforeEach,
	afterEach = Test.afterEach,
}
