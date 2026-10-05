--!strict

local Controls = require(script.Controls)
local Core = require(script.Core)
local Modal = require(script.Modal)
local Theme = require(script.Theme)

export type PanelProps = Core.PanelProps
export type LabelProps = Core.LabelProps
export type IconProps = Core.IconProps
export type ChipProps = Core.ChipProps
export type KeycapProps = Core.KeycapProps
export type Keycap = Core.Keycap
export type BurstProps = Core.BurstProps
export type BarProps = Core.BarProps
export type Bar = Core.Bar
export type PlateProps = Core.PlateProps
export type PillProps = Core.PillProps
export type Pill = Core.Pill
export type SectionProps = Core.SectionProps
export type ButtonProps = Controls.ButtonProps
export type Button = Controls.Button
export type ScrollProps = Controls.ScrollProps
export type GridScrollProps = Controls.GridScrollProps
export type SliderProps = Controls.SliderProps
export type Slider = Controls.Slider
export type ToggleProps = Controls.ToggleProps
export type Toggle = Controls.Toggle
export type Tab = Controls.Tab
export type TabBarProps = Controls.TabBarProps
export type TabBar = Controls.TabBar
export type ModalProps = Modal.ModalProps
export type Modal = Modal.Modal

type SoundPlayer = (name: string) -> ()

local popInfo = TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local Kit = {
	TabBarTop = 8,
	TabBarHeight = 56,
	ClicksGap = 8,
	ClicksHeight = 44,
	ToastGap = 12,
	Theme = Theme.Colors,
	Space = Theme.Space,
	Radius = Theme.Radius,
	StrokeSize = Theme.Stroke,
	Fonts = Theme.Fonts,
	Font = Theme.Fonts.Body,
	HeaderHeight = Modal.HeaderHeight,
	ButtonHeight = Controls.ButtonHeight,
	TouchSize = Controls.TouchSize,
	Shade = Theme.Shade,
	Tween = Controls.Tween,
	Corner = Core.Corner,
	Stroke = Core.Stroke,
	StrokeOf = Core.StrokeOf,
	TextStroke = Core.TextStroke,
	Paint = Core.Paint,
	Shards = Core.Shards,
	Gloss = Core.Gloss,
	Panel = Core.Panel,
	Card = Core.Panel,
	Plate = Core.Plate,
	Label = Core.Label,
	Icon = Core.Icon,
	Chip = Core.Chip,
	Badge = Core.Badge,
	Keycap = Core.Keycap,
	Burst = Core.Burst,
	Bar = Core.Bar,
	Pill = Core.Pill,
	Section = Core.Section,
	Button = Controls.Button,
	CloseButton = Controls.CloseButton,
	Scroll = Controls.Scroll,
	ScrollList = Controls.Scroll,
	GridScroll = Controls.GridScroll,
	Slider = Controls.Slider,
	Toggle = Controls.Toggle,
	TabBar = Controls.TabBar,
	Pulse = Controls.Pulse,
	Shake = Controls.Shake,
	ScreenGui = Modal.ScreenGui,
	Modal = Modal.new,
}

function Kit.PopInfo(): TweenInfo
	return popInfo
end

function Kit.UiSound(controllers: { [string]: any }): SoundPlayer
	return function(name: string)
		local sounds = controllers.SoundController
		if sounds then
			sounds:PlayUi(name)
		end
	end
end

return Kit
