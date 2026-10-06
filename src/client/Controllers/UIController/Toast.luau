--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Trove = require(ReplicatedStorage.Packages.Trove)
local Kit = require(script.Parent.Kit)

type TroveInstance = typeof(Trove.new())
type FadeTarget = {
	Target: Instance,
	Property: string,
	Original: number,
}
type Entry = {
	Wrapper: Frame,
	Pill: Frame,
	Fades: { FadeTarget },
	Thread: thread?,
}

local Toast = {}

local toastTop = Kit.TabBarTop + Kit.TabBarHeight + Kit.ClicksGap + Kit.ClicksHeight + Kit.ToastGap
local toastHeight = 54
local slideDistance = 28
local maxStacked = 3
local lifetime = 2.2
local glyphs: { [string]: string } = {
	Good = "Check",
	Bad = "Warning",
	Info = "Info",
	Gold = "Star",
}
local kinds: { [string]: Color3 } = {
	Good = Kit.Theme.Green,
	Bad = Kit.Theme.Red,
	Info = Kit.Theme.Blue,
	Gold = Kit.Theme.Gold,
}
local showInfo = Kit.Motion.PopLarge
local fadeInfo = Kit.Motion.Base
local hideInfo = Kit.Motion.Leave

local function collectFades(root: Instance): { FadeTarget }
	local list: { FadeTarget } = {}
	local function add(target: Instance, property: string)
		local ok, value = pcall(function()
			return (target :: any)[property]
		end)
		if ok and type(value) == "number" and value < 1 then
			table.insert(list, { Target = target, Property = property, Original = value })
		end
	end
	local function visit(item: Instance)
		if item:IsA("TextLabel") then
			add(item, "TextTransparency")
			add(item, "BackgroundTransparency")
		elseif item:IsA("ImageLabel") then
			add(item, "ImageTransparency")
			add(item, "BackgroundTransparency")
		elseif item:IsA("Frame") then
			add(item, "BackgroundTransparency")
		elseif item:IsA("UIStroke") then
			add(item, "Transparency")
		end
	end
	visit(root)
	for _, item in root:GetDescendants() do
		visit(item)
	end
	return list
end

function Toast.new(playerGui: Instance, trove: TroveInstance): (text: string, kind: string?) -> ()
	local _gui, root = Kit.ScreenGui("ThockToasts", Kit.Layer.Toast, playerGui, trove)
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
	list.Padding = UDim.new(0, Kit.Space.S)
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
		for _, fade in entry.Fades do
			Kit.Tween(fade.Target, hideInfo, { [fade.Property] = 1 })
		end
		local closing = Kit.Tween(entry.Pill, hideInfo, { Position = UDim2.fromOffset(0, -slideDistance) })
		closing.Completed:Once(function()
			entry.Wrapper:Destroy()
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
		local wrapper = Instance.new("Frame")
		wrapper.Name = "ToastSlot"
		wrapper.BackgroundTransparency = 1
		wrapper.BorderSizePixel = 0
		wrapper.AutomaticSize = Enum.AutomaticSize.X
		wrapper.Size = UDim2.fromOffset(0, toastHeight)
		wrapper.LayoutOrder = order
		wrapper.Parent = holder
		local pill = Kit.Panel({
			Parent = wrapper,
			Name = "Toast",
			Size = UDim2.fromOffset(0, toastHeight - 4),
			Color = kinds[kind or "Info"] or kinds.Info,
			Shards = true,
			Gloss = true,
			Pill = true,
		})
		pill.AutomaticSize = Enum.AutomaticSize.X
		pill.Position = UDim2.fromOffset(0, -slideDistance)
		local content = Instance.new("Frame")
		content.Name = "Content"
		content.BackgroundTransparency = 1
		content.BorderSizePixel = 0
		content.AutomaticSize = Enum.AutomaticSize.X
		content.Size = UDim2.fromOffset(0, toastHeight - 4)
		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0, 14)
		padding.PaddingRight = UDim.new(0, 24)
		padding.Parent = content
		local row = Instance.new("UIListLayout")
		row.FillDirection = Enum.FillDirection.Horizontal
		row.VerticalAlignment = Enum.VerticalAlignment.Center
		row.SortOrder = Enum.SortOrder.LayoutOrder
		row.Padding = UDim.new(0, Kit.Space.S)
		row.Parent = content
		Kit.Icon({
			Parent = content,
			Name = "Icon",
			Glyph = glyphs[kind or "Info"] or glyphs.Info,
			Size = UDim2.fromOffset(32, 32),
			LayoutOrder = 1,
		})
		content.Parent = pill
		local label = Kit.Label({
			Parent = content,
			Name = "Text",
			Text = text,
			Size = UDim2.fromOffset(0, toastHeight - 4),
			TextSize = Kit.Text.Title,
			Align = Enum.TextXAlignment.Center,
			LayoutOrder = 2,
		})
		label.AutomaticSize = Enum.AutomaticSize.X
		label.TextTruncate = Enum.TextTruncate.None
		local fades = collectFades(pill)
		for _, fade in fades do
			(fade.Target :: any)[fade.Property] = 1
		end
		for _, fade in fades do
			Kit.Tween(fade.Target, fadeInfo, { [fade.Property] = fade.Original })
		end
		Kit.Tween(pill, showInfo, { Position = UDim2.new() })
		local entry: Entry = { Wrapper = wrapper, Pill = pill, Fades = fades, Thread = nil }
		table.insert(entries, entry)
		entry.Thread = task.delay(lifetime, function()
			entry.Thread = nil
			remove(entry)
		end)
	end
end

return Toast
