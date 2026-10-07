--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Trove = require(ReplicatedStorage.Packages.Trove)
local Buttons = require(script.Parent.Buttons)
local Theme = require(script.Parent.Theme)

type TroveInstance = typeof(Trove.new())
type SoundPlayer = (name: string) -> ()

local colors = Theme.Colors

export type Tab = {
	Id: string,
	Text: string,
	Glyph: string?,
	Color: Color3,
}

export type TabBarProps = {
	Parent: Instance,
	Name: string?,
	Tabs: { Tab },
	Selected: string?,
	Size: UDim2?,
	Position: UDim2?,
	LayoutOrder: number?,
	TextSize: number?,
	OnSelect: (id: string) -> (),
	Sound: SoundPlayer?,
	Silent: boolean?,
}

export type TabBar = {
	Instance: Frame,
	Buttons: { [string]: Buttons.Button },
	Select: (id: string) -> (),
}

local TabBars = {}

function TabBars.TabBar(trove: TroveInstance, props: TabBarProps): TabBar
	local holder = Instance.new("Frame")
	holder.Name = props.Name or "Tabs"
	holder.BackgroundTransparency = 1
	holder.BorderSizePixel = 0
	holder.Size = props.Size or UDim2.new(1, 0, 0, 52)
	holder.Position = props.Position or UDim2.new()
	holder.LayoutOrder = props.LayoutOrder or 0
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, Theme.Space.S)
	list.Parent = holder
	holder.Parent = props.Parent
	local buttons: { [string]: Buttons.Button } = {}
	local count = #props.Tabs
	local function select(id: string)
		for _, tab in props.Tabs do
			local button = buttons[tab.Id]
			local isSelected = tab.Id == id
			button.SetSelected(isSelected)
			button.SetColor(if isSelected then tab.Color else colors.Grey)
		end
	end
	for index, tab in props.Tabs do
		buttons[tab.Id] = Buttons.Button(trove, {
			Parent = holder,
			Name = tab.Id,
			Text = tab.Text,
			Glyph = tab.Glyph,
			IconLeft = tab.Glyph ~= nil,
			Size = UDim2.new(1 / count, -Theme.Space.S, 1, 0),
			LayoutOrder = index,
			Color = tab.Color,
			TextSize = props.TextSize or 22,
			Callback = function()
				select(tab.Id)
				props.OnSelect(tab.Id)
			end,
			Sound = props.Sound,
			Silent = props.Silent,
		})
	end
	if props.Selected then
		select(props.Selected)
	end
	return { Instance = holder, Buttons = buttons, Select = select }
end

return TabBars
