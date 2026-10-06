--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Trove = require(ReplicatedStorage.Packages.Trove)

type TroveInstance = typeof(Trove.new())

export type OnAdded = (plot: Model, item: Model, trove: TroveInstance) -> ()

local Watch = {}

function Watch.Items(plots: Instance, folderName: string, onAdded: OnAdded): TroveInstance
	local root = Trove.new()
	local function sub(parent: TroveInstance): TroveInstance
		local created = Trove.new()
		parent:Add(created)
		return created
	end
	local plotTroves: { [Instance]: TroveInstance } = {}

	local function watchPlot(plot: Instance)
		if not plot:IsA("Model") or plotTroves[plot] then
			return
		end
		local plotTrove = sub(root)
		plotTroves[plot] = plotTrove
		local itemTroves: { [Instance]: TroveInstance } = {}
		local function watchFolder(folder: Instance)
			local function add(child: Instance)
				if child:IsA("Model") and not itemTroves[child] then
					local itemTrove = sub(plotTrove)
					itemTroves[child] = itemTrove
					onAdded(plot, child, itemTrove)
				end
			end
			for _, child in folder:GetChildren() do
				add(child)
			end
			plotTrove:Connect(folder.ChildAdded, add)
			plotTrove:Connect(folder.ChildRemoved, function(child: Instance)
				local itemTrove = itemTroves[child]
				if itemTrove then
					itemTroves[child] = nil
					itemTrove:Destroy()
				end
			end)
		end
		local existing = plot:FindFirstChild(folderName)
		if existing then
			watchFolder(existing)
		end
		plotTrove:Connect(plot.ChildAdded, function(child: Instance)
			if child.Name == folderName then
				watchFolder(child)
			end
		end)
	end

	for _, plot in plots:GetChildren() do
		watchPlot(plot)
	end
	root:Connect(plots.ChildAdded, watchPlot)
	root:Connect(plots.ChildRemoved, function(plot: Instance)
		local plotTrove = plotTroves[plot]
		if plotTrove then
			plotTroves[plot] = nil
			plotTrove:Destroy()
		end
	end)
	return root
end

return Watch
