local Fakes = require("./Fakes")
local Test = require("./Test")
local World = require("./World")

return {
	newWorld = World.new,
	deepCopy = World.deepCopy,
	press = Fakes.press,
	installTweens = Fakes.installTweens,
	fakeDataController = Fakes.fakeDataController,
	fakeSound = Fakes.fakeSound,
	describe = Test.describe,
	it = Test.it,
	expect = Test.expect,
	beforeEach = Test.beforeEach,
	afterEach = Test.afterEach,
}
