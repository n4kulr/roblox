--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local WorldNames = require(ReplicatedStorage.Config.WorldNames)

local Channels = WorldNames.Channels

local ChatNotice = {}

function ChatNotice.Escape(text: string): string
	local escaped = string.gsub(text, "&", "&amp;")
	escaped = string.gsub(escaped, "<", "&lt;")
	escaped = string.gsub(escaped, ">", "&gt;")
	return escaped
end

function ChatNotice.Post(text: string)
	local channels = TextChatService:FindFirstChild(Channels.TextChannels)
	local general = if channels then channels:FindFirstChild(Channels.RBXGeneral) else nil
	if general and general:IsA("TextChannel") then
		general:DisplaySystemMessage(`[{GameConfig.Name}] {text}`)
	end
end

return ChatNotice
