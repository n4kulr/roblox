--!strict

export type Offer = { [string]: number }

export type Session = {
	Players: { Player },
	Offers: { [Player]: Offer },
	Ready: { [Player]: boolean },
	Remaining: number,
	Token: number,
	IsClosed: boolean,
}

export type Request = {
	Sender: Player,
	Target: Player,
}

export type Context = {
	Services: { [string]: any },
}

return {}
