local H = require("../harness/Harness")

local describe, it, expect, beforeEach = H.describe, H.it, H.expect, H.beforeEach

describe("ChatNotice", function()
	local world, ChatNotice, posted, GameConfig

	local function installChat(isTextChannel: boolean)
		local general = {
			IsA = function(_self: any, className: string)
				return isTextChannel and className == "TextChannel"
			end,
			DisplaySystemMessage = function(_self: any, text: string)
				table.insert(posted, text)
			end,
		}
		local channels = {
			FindFirstChild = function(_self: any, name: string)
				return if name == "RBXGeneral" then general else nil
			end,
		}
		world.fakeServices.TextChatService = {
			FindFirstChild = function(_self: any, name: string)
				return if name == "TextChannels" then channels else nil
			end,
		}
	end

	beforeEach(function()
		world = H.newWorld()
		posted = {}
		GameConfig = world:require("ReplicatedStorage.Config.GameConfig")
	end)

	local function load()
		ChatNotice = world:require("StarterPlayer.StarterPlayerScripts.Util.ChatNotice")
	end

	it("escapes rich text control characters", function()
		installChat(true)
		load()
		expect(ChatNotice.Escape("a<b>&c")):toBe("a&lt;b&gt;&amp;c")
	end)

	it("posts a prefixed system message in the general channel", function()
		installChat(true)
		load()
		ChatNotice.Post("hello")
		expect(posted):toEqual({ `[{GameConfig.Name}] hello` })
	end)

	it("does nothing when the general channel is not a text channel", function()
		installChat(false)
		load()
		ChatNotice.Post("hello")
		expect(#posted):toBe(0)
	end)

	it("does nothing when chat is not available", function()
		world.fakeServices.TextChatService = {
			FindFirstChild = function()
				return nil
			end,
		}
		load()
		ChatNotice.Post("hello")
		expect(#posted):toBe(0)
	end)
end)
