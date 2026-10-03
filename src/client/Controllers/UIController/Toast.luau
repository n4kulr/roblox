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

local toastTop = Kit.TabBarTop + Kit.TabBarHeight + Kit.ClicksGap + Kit.ClicksHeight + Kit.ToastGap
local maxStacked = 3
local lifetime = 1.6
local kinds: { [string]: Color3 } = {
	Good = Kit.Theme.Green,
	Bad = Kit.Theme.Red,
	Info = Kit.Theme.Blue,
	Gold = Kit.Theme.Gold,
}
local kindGlyphs: { [string]: string } = {
	Good = "check",
	Bad = "warn",
	Info = "clock",
	Gold = "globe",
}
local toastHeight = 40
local accentWidth = 6

function Toast.new(playerGui: Instance, trove: TroveInstance): (text: string, kind: string?) -> ()
	local _gui, root = Kit.ScreenGui("ThockToasts", 20, playerGui, trove)
	local holder = Instance.new("Frame")
	holder.Name = "Holder"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0)
	holder.Position = UDim2.new(0.5, 0, 0, toastTop)
	holder.Size = UDim2.new(1, -48, 1, -(toastTop + 24))
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
		local kindName = if kind and kinds[kind] then kind else "Info"
		local accent = kinds[kindName]
		local pill = Instance.new("Frame")
		pill.Name = "Toast"
		pill.BackgroundColor3 = accent
		pill.BorderSizePixel = 0
		pill.AutomaticSize = Enum.AutomaticSize.X
		pill.Size = UDim2.fromOffset(0, toastHeight)
		pill.LayoutOrder = order
		Kit.Corner(pill, toastHeight / 2)
		Kit.Stroke(pill, Kit.Theme.Line, 2)
		local body = Instance.new("Frame")
		body.Name = "Body"
		body.BackgroundColor3 = Kit.Theme.Surface2
		body.BorderSizePixel = 0
		body.AutomaticSize = Enum.AutomaticSize.X
		body.Position = UDim2.fromOffset(accentWidth, 0)
		body.Size = UDim2.fromOffset(0, toastHeight)
		Kit.Corner(body, toastHeight / 2)
		local list = Instance.new("UIListLayout")
		list.FillDirection = Enum.FillDirection.Horizontal
		list.VerticalAlignment = Enum.VerticalAlignment.Center
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.Padding = UDim.new(0, 12)
		list.Parent = body
		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0, 12)
		padding.PaddingRight = UDim.new(0, 16)
		padding.Parent = body
		body.Parent = pill
		local glyph = Kit.Glyph(body, kindGlyphs[kindName], 20, accent)
		glyph.LayoutOrder = 1
		local label = Kit.Label({
			Parent = body,
			Name = "Text",
			Text = text,
			Size = UDim2.fromOffset(0, toastHeight),
			TextSize = 16,
			LayoutOrder = 2,
			Body = true,
		})
		label.AutomaticSize = Enum.AutomaticSize.X
		label.TextTruncate = Enum.TextTruncate.None
		pill.Parent = holder
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
