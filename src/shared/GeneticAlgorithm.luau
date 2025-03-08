local GeneticAlgorithm = {}

print("Loading GeneticAlgorithm module...")

-- Constants that can be configured
GeneticAlgorithm.NUM_RAYS = 5
GeneticAlgorithm.MAX_RAY_ANGLE = math.pi / 3 -- Radians, this is 60 degrees  
GeneticAlgorithm.RAY_DEPTH = 4
GeneticAlgorithm.MUTATION_RATE = 0.05

local rand = Random.new()

--[[
	Draws rays starting at the dummies feet and rotating up to the max angle,
	calculating a weight based off distance and genes to allow the dummy to act
]]
function GeneticAlgorithm.getWeights(pos, genes, castParams)
	local weights = {}
	
	-- Validate inputs
	if not pos then
		warn("getWeights: position is nil")
		return weights
	end
	
	if not genes or #genes < GeneticAlgorithm.NUM_RAYS * 2 then
		warn("getWeights: genes are invalid, length: " .. (genes and #genes or "nil"))
		return weights
	end
	
	if not castParams then
		warn("getWeights: castParams is nil")
		return weights
	end
	
	-- Create a new cf pointing downwards
	local refCF = CFrame.fromMatrix(pos, Vector3.xAxis, -Vector3.zAxis)
	for i = 1, GeneticAlgorithm.NUM_RAYS * 2, 2 do
		local result = workspace:Raycast(pos, refCF.LookVector * GeneticAlgorithm.RAY_DEPTH, castParams)
		local dist = GeneticAlgorithm.RAY_DEPTH -- default to farthest away dist 
		if result and result.Instance then
			dist = (result.Position - pos).Magnitude -- if we have a hit, we update dist accordingly 
		end
		-- For each cast, we have to update the jump and move weights
		table.insert(weights, genes[i] * (dist/GeneticAlgorithm.RAY_DEPTH))
		table.insert(weights, genes[i + 1] * (dist/GeneticAlgorithm.RAY_DEPTH))
		
		-- Rotate ray generator cf up to next angle 
		refCF *= CFrame.Angles(GeneticAlgorithm.MAX_RAY_ANGLE/GeneticAlgorithm.NUM_RAYS, 0, 0)
	end
	return weights
end

--[[
	Determines whether or not the dummy should move or jump based on cumulative values of the ray weights
]]
function GeneticAlgorithm.getActions(weights)
	if not weights or #weights == 0 then
		warn("getActions: weights are invalid")
		return false, false
	end
	
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
function GeneticAlgorithm.makeRandomGenome()
	print("Creating random genome")
	local genes = {}
	-- Each ray has two values: one for jump, one for move, so our genome is 2 times rays  
	for i = 1, GeneticAlgorithm.NUM_RAYS * 2 do
		table.insert(genes, rand:NextNumber(-1, 1))
	end
	print("Created random genome with " .. #genes .. " genes")
	return genes
end

--[[
	Makes the dummy a color based on their genes.
	Only leads to gray-blue-green colors because of the range
	of numbers we are dealing with but its good enough 
]]
function GeneticAlgorithm.colorDummy(dummy, genes)
	if not dummy then
		warn("colorDummy: dummy is nil")
		return
	end
	
	if not genes or #genes == 0 then
		warn("colorDummy: genes are invalid")
		return
	end
	
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
	Calculates the distance between dummy and goal, lower scores are better.
	
	This is used to find who survived the best, and give them reproduction priority. 
]]
function GeneticAlgorithm.calcFitness(dummy, goal)
	if not dummy then
		warn("calcFitness: dummy is nil")
		return 1000
	end
	
	if not goal then
		warn("calcFitness: goal is nil")
		return 1000
	end
	
	return (dummy:GetPivot().Position * Vector3.new(1, 0, 1) - goal.Position * Vector3.new(1, 0, 1)).Magnitude
end

--[[
	Takes two parent genes, picks a random point along them,
	and swaps the the first slice of the first gene with the first slice
	of the second.
	
	This is meant to find the 'best of both worlds' and make children that
	take the best traits from their parents 
]]
function GeneticAlgorithm.crossover(gene1, gene2)
	if not gene1 or not gene2 or #gene1 == 0 or #gene2 == 0 then
		warn("crossover: genes are invalid")
		return GeneticAlgorithm.makeRandomGenome(), GeneticAlgorithm.makeRandomGenome()
	end
	
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
function GeneticAlgorithm.pointMutate(gene)
	if not gene or #gene == 0 then
		warn("pointMutate: gene is invalid")
		return GeneticAlgorithm.makeRandomGenome()
	end
	
	local idx = rand:NextInteger(1, GeneticAlgorithm.NUM_RAYS * 2)
	gene[idx] = rand:NextNumber(-1, 1)
	return gene
end

print("GeneticAlgorithm module loaded")
return GeneticAlgorithm 