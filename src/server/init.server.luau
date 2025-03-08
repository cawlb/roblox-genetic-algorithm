local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")
local PhysicsService = game:GetService("PhysicsService")

print("Starting Genetic Algorithm Server...")

-- Create collision group for dummies
if not pcall(function() PhysicsService:GetCollisionGroupId("Dummies") end) then
    PhysicsService:CreateCollisionGroup("Dummies")
    PhysicsService:CollisionGroupSetCollidable("Dummies", "Dummies", false)
    print("Created 'Dummies' collision group")
end

-- Constants
local NUM_RAYS = 5
local MAX_RAY_ANGLE = math.pi / 3 -- Radians, this is 60 degrees  
local RAY_DEPTH = 4
local NUM_DUMMIES = 32 -- because of later code, this number must have 4 as a factor 
local NUM_GENS = 25 
local GEN_TIME = 20 -- Changed from 5 to 20 seconds
local MUTATION_RATE = 0.05

-- Setup workspace
local function setupWorkspace()
    print("Setting up workspace...")
    
    -- Create platforms folder if it doesn't exist
    if not workspace:FindFirstChild("Platforms") then
        local platforms = Instance.new("Folder")
        platforms.Name = "Platforms"
        platforms.Parent = workspace
        
        -- Create a simple platform (baseplate)
        local platform = Instance.new("Part")
        platform.Name = "Platform1"
        platform.Size = Vector3.new(100, 1, 100)
        platform.Position = Vector3.new(0, 0, 0)
        platform.Anchored = true
        platform.Material = Enum.Material.Grass
        platform.Color = Color3.fromRGB(106, 127, 63)
        platform.Parent = platforms
    end
    
    -- Create start position if it doesn't exist
    if not workspace:FindFirstChild("Start") then
        local start = Instance.new("Part")
        start.Name = "Start"
        start.Size = Vector3.new(8, 1, 8)
        start.Position = Vector3.new(-40, 0.5, -40) -- At the same level as baseplate
        start.Anchored = true
        start.CanCollide = true
        start.Material = Enum.Material.SmoothPlastic
        start.Transparency = 0.3
        start.Color = Color3.fromRGB(0, 255, 0)
        start.Parent = workspace
    end
    
    -- Create goal position if it doesn't exist
    if not workspace:FindFirstChild("Goal") then
        local goal = Instance.new("Part")
        goal.Name = "Goal"
        goal.Size = Vector3.new(8, 1, 8)
        goal.Position = Vector3.new(40, 0.5, 40) -- At the same level as baseplate
        goal.Anchored = true
        goal.CanCollide = true
        goal.Material = Enum.Material.SmoothPlastic
        goal.Transparency = 0.3
        goal.Color = Color3.fromRGB(255, 0, 0)
        goal.Parent = workspace
    end
    
    -- Create some obstacles between start and goal
    local obstacles
    if workspace.Platforms:FindFirstChild("Obstacles") then
        obstacles = workspace.Platforms.Obstacles
    else
        obstacles = Instance.new("Folder")
        obstacles.Name = "Obstacles"
        obstacles.Parent = workspace.Platforms
    end
    
    -- Create a few obstacles if they don't exist
    if #obstacles:GetChildren() == 0 then
        local positions = {
            Vector3.new(0, 1, 0),
            Vector3.new(-20, 1, -20),
            Vector3.new(20, 1, 20),
            Vector3.new(-20, 1, 20),
            Vector3.new(20, 1, -20)
        }
        
        for i, pos in ipairs(positions) do
            local obstacle = Instance.new("Part")
            obstacle.Name = "Obstacle" .. i
            obstacle.Size = Vector3.new(10, 2, 10)
            obstacle.Position = pos
            obstacle.Anchored = true
            obstacle.Material = Enum.Material.Concrete
            obstacle.Color = Color3.fromRGB(120, 120, 120)
            obstacle.Parent = obstacles
        end
    end
    
    -- Create dummy template if it doesn't exist
    if not ServerStorage:FindFirstChild("Dummy") then
        -- Create a simple dummy template
        local dummy = Instance.new("Model")
        dummy.Name = "Dummy"
        
        -- Create the HumanoidRootPart first
        local torso = Instance.new("Part")
        torso.Name = "HumanoidRootPart"
        torso.Size = Vector3.new(2, 2, 1)
        torso.Position = Vector3.new(0, 3, 0)
        torso.Transparency = 0.3 -- Make parts slightly transparent
        torso.CanCollide = false -- Disable collision
        torso.Parent = dummy
        
        -- Then create the humanoid
        local humanoid = Instance.new("Humanoid")
        humanoid.Parent = dummy
        
        -- Create a head
        local head = Instance.new("Part")
        head.Name = "Head"
        head.Size = Vector3.new(1, 1, 1)
        head.Position = Vector3.new(0, 4.5, 0)
        head.Transparency = 0.3 -- Make parts slightly transparent
        head.CanCollide = false -- Disable collision
        head.Parent = dummy
        
        -- Create a weld to connect the head to the torso
        local weld = Instance.new("WeldConstraint")
        weld.Part0 = torso
        weld.Part1 = head
        weld.Parent = torso
        
        -- Set the primary part
        dummy.PrimaryPart = torso
        
        dummy.Parent = ServerStorage
        print("Created dummy template")
    end
end

-- Set up the workspace with required objects
setupWorkspace()

-- Set up raycast parameters
local CAST_PARAMS = RaycastParams.new()
CAST_PARAMS.FilterType = Enum.RaycastFilterType.Whitelist
CAST_PARAMS.FilterDescendantsInstances = {workspace.Platforms} -- we only want dummies to see platforms 

local rand = Random.new()

--[[
	Draws rays starting at the dummies feet and rotating up to the max angle,
	calculating a weight based off distance and genes to allow the dummy to act
]]
local function getWeights(pos, genes)
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
local function getActions(weights)
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
local function makeRandomGenome()
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
local function colorDummy(dummy, genes)
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
	local dummy = ServerStorage.Dummy:Clone()
	dummy.Parent = workspace
	
	-- Position the dummy at the start position
	dummy:PivotTo(workspace.Start.CFrame + Vector3.new(0, 3, 0))
	
	-- Color the dummy based on genes
	colorDummy(dummy, genes)
	
	-- Get the humanoid
	local humanoid = dummy:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		print("No humanoid found in dummy, creating one")
		humanoid = Instance.new("Humanoid")
		humanoid.Parent = dummy
	end
	
	-- Set humanoid properties
	humanoid.WalkSpeed = 16
	humanoid.JumpPower = 50
	
	-- Set collision group to prevent dummies from colliding with each other
	for _, part in pairs(dummy:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CollisionGroup = "Dummies"
			part.CanCollide = false -- Ensure all parts don't collide
		end
	end
	
	local connection
	connection = RunService.Stepped:Connect(function()
		if not dummy.Parent then 
			-- When it is destroyed, we just want to stop this loop
			connection:Disconnect()
			return 
		end
		
		-- Get the dummy's position
		local dummyPos = dummy:GetPivot().Position
		
		-- Calculate weights and actions
		local weights = getWeights(dummyPos, genes)
		local shouldMove, shouldJump = getActions(weights)
		
		-- Calculate direction towards goal
		local goalDir = (workspace.Goal.Position - dummyPos).Unit
		goalDir = Vector3.new(goalDir.X, 0, goalDir.Z).Unit -- Flatten to XZ plane
		
		-- Move the dummy
		if shouldMove then
			humanoid:Move(goalDir)
		else
			humanoid:Move(Vector3.new(0, 0, 0))
		end
		
		-- Make the dummy jump
		humanoid.Jump = shouldJump
	end)
	
	return dummy
end

--[[
	Calculates the distance between dummy and goal, lower scores are better.
	
	This is used to find who survived the best, and give them reproduction priority. 
]]
local function calcFitness(dummy)
	return (dummy:GetPivot().Position * Vector3.new(1, 0, 1) - workspace.Goal.Position * Vector3.new(1, 0, 1)).Magnitude
end

--[[
	Takes two parent genes, picks a random point along them,
	and swaps the the first slice of the first gene with the first slice
	of the second.
	
	This is meant to find the 'best of both worlds' and make children that
	take the best traits from their parents 
]]
local function crossover(gene1, gene2)
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
	local idx = rand:NextInteger(1, NUM_RAYS * 2)
	gene[idx] = rand:NextNumber(-1, 1)
	return gene
end

local function simulateEvolution()
	print("Starting genetic algorithm simulation...")
	
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
			print("Creating dummy " .. i)
			dummies[i] = simulateDummy(genes[i])
		end
		print("Created " .. #dummies .. " dummies for generation " .. gen)
		task.wait(GEN_TIME)

		local scores = {}
		for i, d in pairs(dummies) do
			if d and d.Parent then
				scores[i] = {calcFitness(d), genes[i]}
				d:Destroy()
			else
				-- If dummy was destroyed, give it a bad score
				scores[i] = {1000, genes[i]}
			end
		end

		-- Sort scores in ascending order, since good scores are low 
		table.sort(scores, function(a, b)
			return a[1] < b[1]
		end)
		-- Update all time best score 
		if scores[1] and scores[1][1] < bestScore then
			bestScore = scores[1][1]
		end

		-- We wipe all genes, keep the top half of the good genes
		-- and add a bottom half of new children to hopefully make
		-- the population better able to survive
		-- (this is the reason we need num_dummies to be divisble by 4, it keeps gene count good)
		table.clear(genes)
		for i = 1, NUM_DUMMIES / 2 - 1, 2 do
			if scores[i] and scores[i+1] then
				local g1 = scores[i][2]
				local g2 = scores[i + 1][2]
				local c1, c2 = crossover(g1, g2)
				table.insert(genes, c1)
				table.insert(genes, c2)
				table.insert(genes, g1)
				table.insert(genes, g2)
			end
		end
		
		-- If we don't have enough genes, fill with random ones
		while #genes < NUM_DUMMIES do
			table.insert(genes, makeRandomGenome())
		end
		
		-- Small chance that a gene will mutate 
		for _, gene in pairs(genes) do
			if rand:NextNumber() < MUTATION_RATE then
				pointMutate(gene)
			end
		end
	end
	
	print("Genetic algorithm simulation completed!")
end

-- Start the simulation
print("Waiting 2 seconds before starting simulation...")
task.wait(2) -- Wait a bit for the game to fully load
simulateEvolution()