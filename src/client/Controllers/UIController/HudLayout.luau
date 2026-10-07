--!strict

local Theme = require(script.Parent.Kit.Theme)

local margin = Theme.ScreenMargin
local cell = 86
local cellGap = 10
local statHeight = 46
local statGap = 16
local rollWidth = 240
local barGap = 14
local tabBarTop = 16
local tabBarHeight = 58
local clicksGap = 14
local clicksHeight = 58
local toastGap = 14

return table.freeze({
	Margin = margin,
	Cell = cell,
	CellGap = cellGap,
	MenuWidth = cell * 2 + cellGap,
	MenuHeight = cell * 3 + cellGap * 2,
	SettingsSize = 58,
	DevGap = 10,
	TopButtonWidth = 176,
	TopGap = 10,
	StatWidth = 150,
	StatHeight = statHeight,
	StatGap = statGap,
	StatsHeight = 3 * statHeight + 2 * statGap,
	StatClearance = 14,
	RollWidth = rollWidth,
	RollHeight = 104,
	BarGap = barGap,
	BarHalfWidth = rollWidth / 2 + barGap + cell,
	SideReserve = 260,
	TabBarTop = tabBarTop,
	TabBarHeight = tabBarHeight,
	ClicksGap = clicksGap,
	ClicksHeight = clicksHeight,
	ToastGap = toastGap,
	ToastTop = tabBarTop + tabBarHeight + clicksGap + clicksHeight + toastGap,
})
