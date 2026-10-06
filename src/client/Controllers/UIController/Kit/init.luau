--!strict

local Async = require(script.Async)
local Cards = require(script.Cards)
local Controls = require(script.Controls)
local Core = require(script.Core)
local Effects = require(script.Effects)
local Feedback = require(script.Feedback)
local Modal = require(script.Modal)
local Poll = require(script.Poll)
local PriceButton = require(script.PriceButton)
local Sound = require(script.Sound)
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
export type IconPlateProps = Cards.PlateProps
export type RowProps = Cards.RowProps
export type Row = Cards.Row
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
export type PriceGate = PriceButton.PriceGate
export type Guard = Async.Guard
export type Confirm = Async.Confirm
export type Flash = Feedback.Flash
export type CountUp = Feedback.CountUp
export type ModalProps = Modal.ModalProps
export type Modal = Modal.Modal

type SoundPlayer = (name: string) -> ()

local Kit = {
	TabBarTop = 16,
	TabBarHeight = 58,
	ClicksGap = 14,
	ClicksHeight = 58,
	ToastGap = 14,
	ScreenMargin = Theme.ScreenMargin,
	Theme = Theme.Colors,
	Space = Theme.Space,
	Radius = Theme.Radius,
	StrokeSize = Theme.Stroke,
	Fonts = Theme.Fonts,
	Text = Theme.Text,
	Motion = Theme.Motion,
	Layer = Theme.Layer,
	ZIndex = Theme.ZIndex,
	Transparency = Theme.Transparency,
	Rainbow = Theme.Rainbow,
	RainbowSequence = Theme.RainbowSequence,
	Font = Theme.Fonts.Body,
	HeaderHeight = Modal.HeaderHeight,
	ButtonHeight = Controls.ButtonHeight,
	TouchSize = Controls.TouchSize,
	Shade = Theme.Shade,
	Retime = Theme.Retime,
	Tween = Controls.Tween,
	Corner = Core.Corner,
	Round = Core.Round,
	Stroke = Core.Stroke,
	StrokeOf = Core.StrokeOf,
	TextStroke = Core.TextStroke,
	Paint = Core.Paint,
	Shards = Core.Shards,
	Gloss = Core.Gloss,
	Panel = Core.Panel,
	Card = Cards.Card,
	Plate = Core.Plate,
	IconPlate = Cards.Plate,
	Row = Cards.Row,
	RarityPaint = Cards.RarityPaint,
	Shimmer = Effects.Shimmer,
	RainbowFill = Effects.Rainbow,
	Breathe = Effects.Breathe,
	Wobble = Effects.Wobble,
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
	Tooltip = Controls.Tooltip,
	Shake = Controls.Shake,
	ScreenGui = Modal.ScreenGui,
	Poll = Poll.Start,
	PollSeconds = Poll.Seconds,
	Request = Async.Request,
	Later = Async.Later,
	Spawn = Async.Spawn,
	Confirm = Async.Confirm,
	Flash = Feedback.Flash,
	CountUp = Feedback.CountUp,
	PriceButton = PriceButton.new,
	SetSound = Sound.Set,
	Play = Sound.Play,
	SoundName = table.freeze({ Click = Sound.Click, Confirm = Sound.Confirm, Error = Sound.Error }),
	Modal = Modal.new,
}

function Kit.PopInfo(): TweenInfo
	return Theme.Motion.Spring
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
