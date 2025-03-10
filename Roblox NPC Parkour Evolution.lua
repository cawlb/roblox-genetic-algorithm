local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

local NUM_RAYS = 5
local MAX_RAY_ANGLE = math.pi / 3 -- Radians, this is 60 degrees  
local RAY_DEPTH = 4
local NUM_DUMMIES = 32 -- because of later code, this number must have 4 as a factor 
local NUM_GENS = 25 
local GEN_TIME = 5 
local MUTATION_RATE = 0.05
local PLATFORMS = workspace.Platforms
local DUMMY = ServerStorage.Dummy
local START = workspace.Start
local GOAL = workspace.Goal

local CAST_PARAMS = RaycastParams.new()
CAST_PARAMS.FilterType = Enum.RaycastFilterType.Whitelist
CAST_PARAMS.FilterDescendantsInstances = {PLATFORMS} -- we only want dummies to see platforms 

local rand = Random.new()

--[[
	Draws rays starting at the dummies feet and rotating up to the max angle,
	calculating a weight based off distance and genes to allow the dummy to act
]]
local function getWeights(pos: Vector3, genes: {number}): {number}
	local weights = {}
	
	-- Create a new cf pointing downwards
	local refCF = CFrame.fromMatrix(pos, Vector3.xAxis, -Vector3.zAxis)
	for i = 1, NUM_RAYS * 2, 2 do
		local result = workspace:Raycast(pos, refCF.LookVector * RAY_DEPTH, CAST_PARAMS)
		local dist = RAY_DEPTH -- default to farthest away dist 
		if result and result.Instance then
			dist = (result.Position - pos).Magnitude -- if we have a hit, we update dist accordingly 
		end
		-- For each cast, we have to update the jump and move weights
		table.insert(weights, genes[i] * (dist/RAY_DEPTH))
		table.insert(weights, genes[i + 1] * (dist/RAY_DEPTH))
		
		-- Rotate ray generator cf up to next angle 
		refCF *= CFrame.Angles(MAX_RAY_ANGLE/NUM_RAYS, 0, 0)
	end
	return weights
end

--[[
	Determines whether or not the dummy should move or jump based on cumulative values of the ray weights
]]
local function getActions(weights: Weights): {ShouldMove: boolean, ShouldJump: boolean}
	local moveSum = 0
	local jumpSum = 0 
	for i, w in weights do
		-- Since each ray has one move and one jump weight
		-- we add the weight to jump every other iteration, and vice versa for move 
		if i % 2 == 0 then
			jumpSum += w
		else
			moveSum += w 			
		end
	end
	-- if our sums are positive, that means we do the action
	return moveSum > 0, jumpSum > 0
end 

--[[
	Create a completely random gene with random weights.
	
	Gives the intial population variation and the chance to evolve based on random
	traits. 
]]
local function makeRandomGenome(): Weights
	local genes = {}
	-- Each ray has two values: one for jump, one for move, so our genome is 2 times rays  
	for i = 1, NUM_RAYS * 2 do
		table.insert(genes, rand:NextNumber(-1, 1))
	end
	return genes
end

--[[
	Makes the dummy a color based on their genes.
	Only leads to gray-blue-green colors because of the range
	of numbers we are dealing with but its good enough 
]]
local function colorDummy(dummy: Model, genes: {number})
	local avg = 0
	for _, num in genes do
		avg += num
	end
	avg = math.abs(avg / #genes * 1000)
	-- Convert to hex string, ensuring its 3 digits long 
	local color = Color3.fromHex(string.format("%.3x", avg))
	for _, part in dummy:GetDescendants() do
		if part:IsA("BasePart") then
			part.Color = color
		end
	end
end

--[[
	Creates one dummy and gives it senses through its rays and allows it to move and jump
	
	A number of dummies is simulated each generation, each isolated from each other 
]]
local function simulateDummy(genes)
	local dummy = DUMMY:Clone()
	dummy.Parent = workspace
	dummy:PivotTo(START.CFrame)
	colorDummy(dummy, genes)
	local connection
	connection = RunService.Stepped:Connect(function()
		if not dummy.Parent then 
			-- When it is destroyed, we just want to stop this loop
			-- It would be better to stop it externally but this works
			-- fine so whatever 
			connection:Disconnect()
			return 
		end
		
		local weights = getWeights(dummy:GetPivot().Position, genes)
		local shouldMove, shouldJump = getActions(weights)
		-- Humanoid can only move at a constant speed in our simulation 
		dummy.Humanoid:Move(-Vector3.zAxis * (if shouldMove then 1 else 0))
		-- Weirdly enough, in order to make a humanoid jump you just set Jump = True
		dummy.Humanoid.Jump = shouldJump
	end)
	return dummy
end

--[[
	Calculates the distance between dummy and goal, lower scores are better.
	
	This is used to find who survived the best, and give them reproduction priority. 
]]
local function calcFitness(dummy: Model)
	return (dummy:GetPivot().Position * Vector3.new(1, 0, 1) - GOAL.Position * Vector3.new(1, 0, 1)).Magnitude
end

--[[
	Takes two parent genes, picks a random point along them,
	and swaps the the first slice of the first gene with the first slice
	of the second.
	
	This is meant to find the 'best of both worlds' and make children that
	take the best traits from their parents 
]]
local function crossover(gene1: {number}, gene2: {number}): ({number}, {number})
	-- pick a random index
	local crossoverPt = rand:NextInteger(1, #gene1)
	-- We have to use two moves: one for the first slice, one for the second
	local child1 = table.move(gene1, 1, crossoverPt, 1, {})
	table.move(gene2, crossoverPt + 1, #gene2, crossoverPt + 1, child1)
	-- We repeat this process again for the other child, creating two unqiue genomes 
	local child2 = table.move(gene2, 1, crossoverPt, 1, {})
	table.move(gene1, crossoverPt + 1, #gene2, crossoverPt + 1, child2)
	return child1, child2
end

--[[
	Randomly choose one value in genome and change it.
	
	This is meant to help the population adapt if the gene pool
	runs stale on a bad solution or the environment changes. 
]]
local function pointMutate(gene)
	local idx = rand:NextInteger(1, NUM_RAYS)
	gene[idx] = rand:NextNumber(-1, 1)
end

local function simulateEvolution()
	-- Give the intial population a random gene pool 
	local genes = {}
	for i = 1, NUM_DUMMIES do
		table.insert(genes, makeRandomGenome())
	end
	
	-- Run through every generation 
	local bestScore = math.huge
	for gen = 1, NUM_GENS do
		print(string.format("Generation %i; Best Fitness Score: %f", gen, bestScore))
		-- Start by creating the population for this generation 
		local dummies = {}
		for i = 1, NUM_DUMMIES do
			dummies[i] = simulateDummy(genes[i])
		end
		task.wait(GEN_TIME)

		local scores = {}
		for i, d in dummies do
			scores[i] = {calcFitness(d), genes[i]}
			d:Destroy()
		end

		-- Sort scores in ascending order, since good scores are low 
		table.sort(scores, function(a, b)
			return a[1] < b[1]
		end)
		-- Update all time best score 
		if scores[1][1] < bestScore then
			bestScore = scores[1][1]
		end

		-- We wipe all genes, keep the top half of the good genes
		-- and add a bottom half of new children to hopefully make
		-- the population better able to survive
		-- (this is the reason we need num_dummies to be divisble by 4, it keeps gene count good)
		table.clear(genes)
		for i = 1, NUM_DUMMIES / 2 - 1, 2 do
			local g1 = scores[i][2]
			local g2 = scores[i + 1][2]
			local c1, c2 = crossover(g1, g2)
			table.insert(genes, c1)
			table.insert(genes, c2)
			table.insert(genes, g1)
			table.insert(genes, g2)
		end
		-- Small chance that a gene will mutate 
		for _, gene in genes do
			if rand:NextNumber() < MUTATION_RATE then
				pointMutate(gene)
			end
		end
	end
end

simulateEvolution()