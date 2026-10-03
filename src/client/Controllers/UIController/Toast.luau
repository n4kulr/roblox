--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Trove = require(ReplicatedStorage.Packages.Trove)
local Kit = require(script.Parent.Kit)

type TroveInstance = typeof(Trove.new())
type Entry = {
	Frame: Frame,
	Scale: UIScale,
	Thread: thread?,
}

local Toast = {}

local maxStacked = 3
local lifetime = 1.6
local kinds: { [string]: Color3 } = {
	Good = Kit.Theme.Green,
	Bad = Kit.Theme.Red,
	Info = Kit.Theme.Blue,
	Gold = Kit.Theme.Gold,
}

function Toast.new(playerGui: Instance, trove: TroveInstance): (text: string, kind: string?) -> ()
	local _gui, root = Kit.ScreenGui("ThockToasts", 20, playerGui, trove)
	local holder = Instance.new("Frame")
	holder.Name = "Holder"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0)
	holder.Position = UDim2.new(0.5, 0, 0, 12)
	holder.Size = UDim2.new(1, -24, 1, -24)
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Top
	list.Padding = UDim.new(0, 8)
	list.Parent = holder
	holder.Parent = root

	local entries: { Entry } = {}
	local order = 0

	local function remove(entry: Entry)
		local index = table.find(entries, entry)
		if not index then
			return
		end
		table.remove(entries, index)
		local thread = entry.Thread
		if thread then
			task.cancel(thread)
			entry.Thread = nil
		end
		local closing = Kit.Tween(
			entry.Scale,
			TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Scale = 0.6 }
		)
		closing.Completed:Once(function()
			entry.Frame:Destroy()
		end)
	end

	trove:Add(function()
		for _, entry in entries do
			local thread = entry.Thread
			if thread then
				task.cancel(thread)
			end
		end
		table.clear(entries)
	end)

	return function(text: string, kind: string?)
		while #entries >= maxStacked do
			remove(entries[1])
		end
		order += 1
		local pill = Kit.Panel({
			Parent = holder,
			Name = "Toast",
			Size = UDim2.fromOffset(0, 46),
			Color = kinds[kind or "Info"] or kinds.Info,
			LayoutOrder = order,
			Shards = true,
		})
		pill.AutomaticSize = Enum.AutomaticSize.X
		local content = Instance.new("Frame")
		content.Name = "Content"
		content.BackgroundTransparency = 1
		content.BorderSizePixel = 0
		content.AutomaticSize = Enum.AutomaticSize.X
		content.Size = UDim2.fromOffset(0, 46)
		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0, 20)
		padding.PaddingRight = UDim.new(0, 20)
		padding.Parent = content
		content.Parent = pill
		local label = Kit.Label({
			Parent = content,
			Name = "Text",
			Text = text,
			Size = UDim2.fromOffset(0, 46),
			TextSize = 24,
			Align = Enum.TextXAlignment.Center,
		})
		label.AutomaticSize = Enum.AutomaticSize.X
		label.TextTruncate = Enum.TextTruncate.None
		local scale = Instance.new("UIScale")
		scale.Scale = 0.6
		scale.Parent = pill
		Kit.Tween(scale, Kit.PopInfo(), { Scale = 1 })
		local entry: Entry = { Frame = pill, Scale = scale, Thread = nil }
		table.insert(entries, entry)
		entry.Thread = task.delay(lifetime, function()
			entry.Thread = nil
			remove(entry)
		end)
	end
end

return Toast
