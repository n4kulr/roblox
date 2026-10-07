local H = require("../harness/Harness")
local roblox = require("@lune/roblox")

local describe, it, expect, beforeEach = H.describe, H.it, H.expect, H.beforeEach

local controller = "StarterPlayer.StarterPlayerScripts.Controllers.UIController"

describe("Kit theme tokens", function()
	local world, Kit

	beforeEach(function()
		world = H.newWorld({ PrintErrors = false })
		Kit = world:require(`{controller}.Kit`)
	end)

	it("exposes named motion presets", function()
		for _, name in { "Press", "Fast", "Base", "Slow", "Fade", "Exit", "Spring", "Pop", "Badge", "Bounce", "Spin" } do
			expect(Kit.Motion[name] ~= nil):toBe(true)
		end
	end)

	it("retimes a preset without losing its easing", function()
		local retimed = Kit.Retime(Kit.Motion.Pop, 0.4, 0.1)
		expect(retimed.Time):toBe(0.4)
		expect(retimed.DelayTime):toBe(0.1)
		expect(retimed.EasingStyle):toBe(Kit.Motion.Pop.EasingStyle)
		expect(retimed.EasingDirection):toBe(Kit.Motion.Pop.EasingDirection)
	end)

	it("keeps the text scale ascending", function()
		local sizes = {}
		for _, size in Kit.Text do
			table.insert(sizes, size)
		end
		table.sort(sizes)
		for index = 2, #sizes do
			expect(sizes[index] > sizes[index - 1]):toBe(true)
		end
	end)

	it("derives the rainbow sequence from the shared palette", function()
		local sequence = Kit.RainbowSequence()
		expect(#sequence.Keypoints):toBe(#Kit.Rainbow + 1)
		expect(sequence.Keypoints[1].Value):toBe(sequence.Keypoints[#sequence.Keypoints].Value)
	end)

	it("freezes the token tables", function()
		expect(table.isfrozen(Kit.Motion)):toBe(true)
		expect(table.isfrozen(Kit.Text)):toBe(true)
		expect(table.isfrozen(Kit.Layer)):toBe(true)
		expect(table.isfrozen(Kit.ZIndex)):toBe(true)
		expect(table.isfrozen(Kit.Theme)):toBe(true)
	end)
end)

describe("Kit helpers", function()
	local world, Kit, Trove, trove, heartbeat

	local function frame(parent: any)
		local instance = world:newInstance("Frame")
		instance.Parent = parent
		return instance
	end

	beforeEach(function()
		world = H.newWorld({ PrintErrors = false })
		Kit = world:require(`{controller}.Kit`)
		Trove = world:require("ReplicatedStorage.Packages.Trove")
		trove = Trove.new()
		heartbeat = world.fakeServices.RunService.Heartbeat
	end)

	describe("Poll", function()
		it("steps on the interval while active", function()
			local calls = 0
			Kit.Poll(trove, 0.25, nil, function()
				calls += 1
			end)
			heartbeat:Fire(0.1)
			heartbeat:Fire(0.1)
			expect(calls):toBe(0)
			heartbeat:Fire(0.1)
			expect(calls):toBe(1)
		end)

		it("skips and does not accumulate while inactive", function()
			local calls = 0
			local isActive = false
			Kit.Poll(trove, 0.2, function()
				return isActive
			end, function()
				calls += 1
			end)
			heartbeat:Fire(1)
			expect(calls):toBe(0)
			isActive = true
			heartbeat:Fire(0.1)
			expect(calls):toBe(0)
			heartbeat:Fire(0.1)
			expect(calls):toBe(1)
		end)

		it("disconnects when the trove is cleaned", function()
			local calls = 0
			Kit.Poll(trove, 0, nil, function()
				calls += 1
			end)
			heartbeat:Fire(0.1)
			trove:Clean()
			heartbeat:Fire(0.1)
			expect(calls):toBe(1)
		end)
	end)

	describe("Request", function()
		it("blocks reentry while a call is pending", function()
			local guard = Kit.Request(trove)
			local started = 0
			guard.Run(function()
				started += 1
				coroutine.yield()
			end)
			expect(guard.IsBusy()):toBe(true)
			expect(guard.Run(function()
				started += 1
			end)):toBe(false)
			expect(started):toBe(1)
		end)

		it("resets busy and reports failure when the call errors", function()
			local guard = Kit.Request(trove)
			local result
			guard.Run(function()
				error("boom")
			end, function(isOk)
				result = isOk
			end)
			expect(guard.IsBusy()):toBe(false)
			expect(result):toBe(false)
			expect(guard.Run(function()
				return 1
			end)):toBe(true)
		end)

		it("passes the result to the callback", function()
			local guard = Kit.Request(trove)
			local got
			guard.Run(function()
				return "done"
			end, function(isOk, value)
				got = isOk and value
			end)
			expect(got):toBe("done")
		end)

		it("skips the callback after the trove is destroyed", function()
			local guard = Kit.Request(trove)
			local called = false
			local held
			guard.Run(function()
				held = coroutine.running()
				coroutine.yield()
			end, function()
				called = true
			end)
			trove:Clean()
			world.task.spawn(held)
			expect(called):toBe(false)
			expect(guard.IsBusy()):toBe(false)
		end)
	end)

	describe("Spawn", function()
		it("reports errors to the callback without throwing", function()
			local result
			Kit.Spawn(trove, function()
				error("boom")
			end, function(isOk)
				result = isOk
			end)
			expect(result):toBe(false)
		end)

		it("does not leak trove entries after finishing", function()
			local before = #trove._objects
			Kit.Spawn(trove, function() end)
			expect(#trove._objects):toBe(before)
		end)
	end)

	describe("Later", function()
		it("runs once after the delay", function()
			local calls = 0
			Kit.Later(trove, 0.5, function()
				calls += 1
			end)
			world:advance(0.4)
			expect(calls):toBe(0)
			world:advance(0.2)
			expect(calls):toBe(1)
		end)

		it("is cancelled with the trove", function()
			local calls = 0
			Kit.Later(trove, 0.5, function()
				calls += 1
			end)
			trove:Clean()
			world:advance(1)
			expect(calls):toBe(0)
		end)
	end)

	describe("Confirm", function()
		it("arms on the first press and acts on the second", function()
			local states = {}
			local acted = 0
			local confirm = Kit.Confirm(trove, 3, function(isArmed)
				table.insert(states, isArmed)
			end)
			expect(confirm.Press(true, function()
				acted += 1
			end)):toBe(false)
			expect(confirm.IsArmed()):toBe(true)
			expect(acted):toBe(0)
			expect(confirm.Press(true, function()
				acted += 1
			end)):toBe(true)
			expect(acted):toBe(1)
			expect(confirm.IsArmed()):toBe(false)
			expect(states):toEqual({ true })
		end)

		it("disarms after the timeout", function()
			local states = {}
			local confirm = Kit.Confirm(trove, 3, function(isArmed)
				table.insert(states, isArmed)
			end)
			confirm.Press(true, function() end)
			world:advance(3.5)
			expect(confirm.IsArmed()):toBe(false)
			expect(states):toEqual({ true, false })
		end)

		it("acts immediately when no confirmation is needed", function()
			local acted = 0
			local confirm = Kit.Confirm(trove, 3, function() end)
			confirm.Press(false, function()
				acted += 1
			end)
			expect(acted):toBe(1)
			expect(confirm.IsArmed()):toBe(false)
		end)
	end)

	describe("CountUp", function()
		it("shows a placeholder until a target is set", function()
			local label = world:newInstance("TextLabel")
			local count = Kit.CountUp({ Label = label, Format = tostring })
			count.Step(0.1)
			expect(label.Text):toBe("...")
		end)

		it("snaps to the first target and eases later ones", function()
			local label = world:newInstance("TextLabel")
			local count = Kit.CountUp({ Label = label, Format = function(value)
				return tostring(math.floor(value))
			end })
			count.SetTarget(100)
			count.Step(0.1)
			expect(label.Text):toBe("100")
			count.SetTarget(1000)
			count.Step(0.05)
			local mid = tonumber(label.Text)
			expect(mid > 100 and mid < 1000):toBe(true)
			for _ = 1, 100 do
				count.Step(0.1)
			end
			expect(label.Text):toBe("1000")
		end)
	end)

	describe("Flash", function()
		it("starts invisible and fires at the requested peak", function()
			local parent = frame(nil)
			local flash = Kit.Flash({ Parent = parent, Radius = 8, ZIndex = 4 })
			expect(flash.Instance.BackgroundTransparency):toBe(1)
			expect(flash.Instance.Name):toBe("Flash")
			expect(flash.Instance.ZIndex):toBe(4)
			expect(flash.Instance.Parent):toBe(parent)
		end)
	end)

	describe("Button sound", function()
		local function press(button: any)
			button.Instance.Activated:Fire({ UserInputType = roblox.Enum.UserInputType.MouseButton1 })
		end

		it("plays the default sound on activation", function()
			local played = {}
			Kit.SetSound(function(name)
				table.insert(played, name)
			end)
			local button = Kit.Button(trove, { Parent = frame(nil), Text = "Go" })
			press(button)
			Kit.SetSound(nil)
			expect(played):toEqual({ "Click" })
		end)

		it("honours an explicit sound and the Silent opt-out", function()
			local fallback, explicit = 0, 0
			Kit.SetSound(function()
				fallback += 1
			end)
			press(Kit.Button(trove, {
				Parent = frame(nil),
				Text = "A",
				Sound = function()
					explicit += 1
				end,
			}))
			press(Kit.Button(trove, { Parent = frame(nil), Text = "B", Silent = true }))
			Kit.SetSound(nil)
			expect(explicit):toBe(1)
			expect(fallback):toBe(0)
		end)
	end)

	describe("PriceButton", function()
		it("refuses and toasts when unaffordable", function()
			local toasts, calls = {}, 0
			local button = Kit.PriceButton(trove, {
				Parent = frame(nil),
				Text = "Buy",
				Callback = function()
					calls += 1
				end,
			}, {
				CanAfford = function()
					return false
				end,
				DeniedText = "Too poor",
				Toast = function(text, kind)
					table.insert(toasts, `{text}:{kind}`)
				end,
			})
			button.Instance.Activated:Fire({ UserInputType = roblox.Enum.UserInputType.MouseButton1 })
			expect(calls):toBe(0)
			expect(toasts):toEqual({ "Too poor:Bad" })
		end)

		it("runs the callback when affordable", function()
			local calls = 0
			local button = Kit.PriceButton(trove, {
				Parent = frame(nil),
				Text = "Buy",
				Callback = function()
					calls += 1
				end,
			}, {})
			button.Instance.Activated:Fire({ UserInputType = roblox.Enum.UserInputType.MouseButton1 })
			expect(calls):toBe(1)
		end)
	end)
end)
