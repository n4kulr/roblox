local H = require("../harness/Harness")
local S = require("../support")

local describe, it, expect, beforeEach, afterEach = H.describe, H.it, H.expect, H.beforeEach, H.afterEach

describe("Board rules", function()
	local world, Board, GameConfig, Keys

	beforeEach(function()
		world = H.newWorld()
		Board = world:require("ReplicatedStorage.Rules.Board")
		GameConfig = world:require("ReplicatedStorage.Config.GameConfig")
		Keys = world:require("ReplicatedStorage.Config.Keys")
	end)

	afterEach(function()
		world:destroy()
	end)

	describe("Empty and IsEmptySlot", function()
		it("builds a board of empty strings", function()
			local board = Board.Empty()
			expect(#board):toBe(GameConfig.BoardSlots)
			expect(board[1]):toBe("")
		end)

		it("treats blanks, unknown ids and non-strings as empty", function()
			expect(Board.IsEmptySlot("")):toBe(true)
			expect(Board.IsEmptySlot("Nope")):toBe(true)
			expect(Board.IsEmptySlot(5)):toBe(true)
			expect(Board.IsEmptySlot("PlainClack")):toBe(false)
		end)
	end)

	describe("Normalize", function()
		it("leaves a valid board untouched", function()
			local board = Board.Empty()
			board[1], board[2] = "PlainClack", "GlassTink"
			local result = Board.Normalize(board, { "", "tag", "" }, GameConfig.BaseSlots)
			expect(result.BoardChanged):toBe(false)
			expect(result.Overflow):toEqual({})
			expect(result.Board[2]):toBe("GlassTink")
			expect(result.Tags[2]):toBe("tag")
		end)

		it("pads short boards and reports the change", function()
			local result = Board.Normalize(S.board("PlainClack"), nil, GameConfig.BaseSlots)
			expect(#result.Board):toBe(GameConfig.BoardSlots)
			expect(result.BoardChanged):toBe(true)
			expect(result.TagsChanged):toBe(true)
		end)

		it("drops unknown ids and relocates keys stored past the board", function()
			local board: any = S.board("Nope", "PlainClack")
			board[GameConfig.BoardSlots + 2] = "GlassTink"
			local result = Board.Normalize(board, nil, GameConfig.BoardSlots)
			expect(result.Board[1]):toBe("GlassTink")
			expect(result.Board[2]):toBe("PlainClack")
			expect(result.BoardChanged):toBe(true)
			expect(result.Overflow):toEqual({})
		end)

		it("keeps the highest income keys and overflows the rest", function()
			local board = S.board("PlainClack", "GlassTink", "CreamyThock", "PlainClack")
			local result = Board.Normalize(board, nil, GameConfig.BaseSlots)
			local kept = {}
			for _, keyId in result.Board do
				if keyId ~= "" then
					table.insert(kept, keyId)
				end
			end
			table.sort(kept)
			expect(kept):toEqual({ "CreamyThock", "GlassTink", "PlainClack" })
			expect(result.Overflow):toEqual({ "PlainClack" })
		end)

		it("relocates locked-slot keys into free unlocked slots and keeps tags in place", function()
			local board: any = {}
			board[5] = "GlassTink"
			board[2] = "PlainClack"
			local tags: any = {}
			tags[2] = "mine"
			local result = Board.Normalize(board, tags, GameConfig.BaseSlots)
			expect(result.Board[1]):toBe("GlassTink")
			expect(result.Board[2]):toBe("PlainClack")
			expect(result.Tags[2]):toBe("mine")
			expect(result.Board[5]):toBe("")
		end)

		it("copes with non-table input", function()
			local result = Board.Normalize(nil, "bad", GameConfig.BaseSlots)
			expect(#result.Board):toBe(GameConfig.BoardSlots)
			expect(result.TagsChanged):toBe(true)
		end)
	end)

	describe("EquipBest", function()
		it("fills unlocked slots with the best keys from board and inventory", function()
			local result = Board.EquipBest(
				S.board("PlainClack", "", ""),
				{ GlassTink = 1, CreamyThock = 1, PlainClack = 2 },
				GameConfig.BaseSlots
			)
			expect(result.Board[1]):toBe("GlassTink")
			expect(result.Board[2]):toBe("CreamyThock")
			expect(result.Board[3]):toBe("PlainClack")
			expect(result.Inventory):toEqual({ PlainClack = 2 })
		end)

		it("prefers perk keys when income ties and never invents keys", function()
			local result = Board.EquipBest(S.board(), { Unknown = 4 }, GameConfig.BaseSlots)
			expect(result.Board[1]):toBe("")
			expect(result.Inventory):toEqual({})
		end)

		it("conserves every key", function()
			local inventory = { PlainClack = 3, GlassTink = 2, GoldPlate = 1 }
			local result = Board.EquipBest(S.board("CreamyThock"), inventory, 4)
			local total = 0
			for _, keyId in result.Board do
				if keyId ~= "" then
					total += 1
				end
			end
			for _, count in result.Inventory do
				total += count
			end
			expect(total):toBe(7)
		end)
	end)

	describe("PickSlot", function()
		it("returns the first empty unlocked slot", function()
			local slot, displaces = Board.PickSlot(S.board("PlainClack", ""), GameConfig.BaseSlots, "GlassTink")
			expect(slot):toBe(2)
			expect(displaces):toBe(false)
		end)

		it("replaces the weakest plain key with a stronger one", function()
			local board = S.board("GlassTink", "PlainClack", "CreamyThock")
			local slot, displaces = Board.PickSlot(board, GameConfig.BaseSlots, "GlassTink")
			expect(slot):toBe(2)
			expect(displaces):toBe(true)
		end)

		it("does not replace when the new key is not stronger", function()
			local board = S.board("GlassTink", "GlassTink", "GlassTink")
			local slot = Board.PickSlot(board, GameConfig.BaseSlots, "PlainClack")
			expect(slot):toBeNil()
		end)

		it("never uses perk keys to displace and never displaces perk keys", function()
			local board = S.board("GoldPlate", "GoldPlate", "GoldPlate")
			expect((Board.PickSlot(board, GameConfig.BaseSlots, "GlassTink"))):toBeNil()
			local plain = S.board("PlainClack", "PlainClack", "PlainClack")
			expect((Board.PickSlot(plain, GameConfig.BaseSlots, "GoldPlate"))):toBeNil()
			expect(Keys.Resolve("GoldPlate").Perk ~= nil):toBe(true)
		end)

		it("rejects unknown ids", function()
			expect((Board.PickSlot(S.board(), GameConfig.BaseSlots, "Nope"))):toBeNil()
		end)
	end)
end)
