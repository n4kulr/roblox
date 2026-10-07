--!strict

local Async = require(script.Async)
local Buttons = require(script.Buttons)
local Cards = require(script.Cards)
local Effects = require(script.Effects)
local Feedback = require(script.Feedback)
local Icons = require(script.Icons)
local Inputs = require(script.Inputs)
local Labels = require(script.Labels)
local Modal = require(script.Modal)
local Poll = require(script.Poll)
local Primitives = require(script.Primitives)
local PriceButton = require(script.PriceButton)
local Scrolls = require(script.Scrolls)
local Sound = require(script.Sound)
local Surfaces = require(script.Surfaces)
local TabBars = require(script.TabBars)
local Theme = require(script.Theme)
local Tooltips = require(script.Tooltips)
local Tweens = require(script.Tweens)
local Widgets = require(script.Widgets)

export type PanelProps = Surfaces.PanelProps
export type LabelProps = Labels.LabelProps
export type IconProps = Icons.IconProps
export type ChipProps = Labels.ChipProps
export type KeycapProps = Widgets.KeycapProps
export type Keycap = Widgets.Keycap
export type BurstProps = Widgets.BurstProps
export type BarProps = Widgets.BarProps
export type Bar = Widgets.Bar
export type IconPlateProps = Cards.PlateProps
export type RowProps = Cards.RowProps
export type Row = Cards.Row
export type PillProps = Widgets.PillProps
export type Pill = Widgets.Pill
export type SectionProps = Widgets.SectionProps
export type ButtonProps = Buttons.ButtonProps
export type Button = Buttons.Button
export type ScrollProps = Scrolls.ScrollProps
export type GridScrollProps = Scrolls.GridScrollProps
export type SliderProps = Inputs.SliderProps
export type Slider = Inputs.Slider
export type ToggleProps = Inputs.ToggleProps
export type Toggle = Inputs.Toggle
export type Tab = TabBars.Tab
export type TabBarProps = TabBars.TabBarProps
export type TabBar = TabBars.TabBar
export type PriceGate = PriceButton.PriceGate
export type Guard = Async.Guard
export type Confirm = Async.Confirm
export type Flash = Feedback.Flash
export type CountUp = Feedback.CountUp
export type ModalProps = Modal.ModalProps
export type Modal = Modal.Modal

type SoundPlayer = (name: string) -> ()

local Kit = {
	ScreenMargin = Theme.ScreenMargin,
	Theme = Theme.Colors,
	Space = Theme.Space,
	Radius = Theme.Radius,
	StrokeSize = Theme.Stroke,
	Font = Theme.Fonts.Body,
	Text = Theme.Text,
	Motion = Theme.Motion,
	Layer = Theme.Layer,
	ZIndex = Theme.ZIndex,
	Rainbow = Theme.Rainbow,
	RainbowSequence = Theme.RainbowSequence,
	TouchSize = Buttons.TouchSize,
	Shade = Theme.Shade,
	Retime = Theme.Retime,
	Tween = Tweens.Tween,
	Corner = Primitives.Corner,
	Round = Primitives.Round,
	Stroke = Primitives.Stroke,
	StrokeOf = Primitives.StrokeOf,
	Paint = Primitives.Paint,
	Gloss = Primitives.Gloss,
	Panel = Surfaces.Panel,
	Card = Cards.Card,
	IconPlate = Cards.Plate,
	Row = Cards.Row,
	RarityPaint = Cards.RarityPaint,
	Shimmer = Effects.Shimmer,
	Breathe = Effects.Breathe,
	Label = Labels.Label,
	Icon = Icons.Icon,
	Chip = Labels.Chip,
	Badge = Labels.Badge,
	Keycap = Widgets.Keycap,
	Burst = Widgets.Burst,
	Bar = Widgets.Bar,
	Pill = Widgets.Pill,
	Section = Widgets.Section,
	Button = Buttons.Button,
	CloseButton = Buttons.CloseButton,
	Scroll = Scrolls.Scroll,
	GridScroll = Scrolls.GridScroll,
	Slider = Inputs.Slider,
	Toggle = Inputs.Toggle,
	TabBar = TabBars.TabBar,
	Pulse = Feedback.Pulse,
	Tooltip = Tooltips.Tooltip,
	Shake = Feedback.Shake,
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
	Modal = Modal.new,
}

function Kit.UiSound(controllers: { [string]: any }): SoundPlayer
	return function(name: string)
		local sounds = controllers.SoundController
		if sounds then
			sounds:PlayUi(name)
		end
	end
end

return Kit
