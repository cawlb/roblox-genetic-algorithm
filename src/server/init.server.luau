local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

print("Starting Genetic Algorithm Server...")

-- Create a RemoteEvent for updating the scoreboard
if not ReplicatedStorage:FindFirstChild("UpdateScoreboard") then
    local updateScoreboard = Instance.new("RemoteEvent")
    updateScoreboard.Name = "UpdateScoreboard"
    updateScoreboard.Parent = ReplicatedStorage
end

-- Create collision group for dummies
if not pcall(function() PhysicsService:GetCollisionGroupId("Dummies") end) then
    PhysicsService:CreateCollisionGroup("Dummies")
    -- Only make dummies not collide with each other, but still collide with everything else
    PhysicsService:CollisionGroupSetCollidable("Dummies", "Dummies", false)
    print("Created 'Dummies' collision group")
end

-- Constants
local NUM_RAYS = 5
local MAX_RAY_ANGLE = math.pi / 3 -- Radians, this is 60 degrees  
local RAY_DEPTH = 4
local NUM_DUMMIES = 32 -- because of later code, this number must have 4 as a factor 
local NUM_GENS = 25 
local GEN_TIME = 8 -- Changed from 20 to 8 seconds
local MUTATION_RATE = 0.1 -- Increased from 0.05 to encourage more exploration
local OBSTACLE_PENALTY = 500 -- Penalty for hitting an obstacle
local NUM_BLOODLINES = 8 -- Number of distinct bloodlines to track

-- Bloodline tracking
local bloodlines = {}
for i = 1, NUM_BLOODLINES do
    bloodlines[i] = {
        color = Color3.fromHSV((i-1)/NUM_BLOODLINES, 0.8, 0.9), -- Distinct colors
        name = "Bloodline " .. i,
        bestScore = math.huge,
        currentScore = math.huge,
        reachedGoal = false,
        goalReachedGen = 0,
        dummyCount = 0,
        successRate = 0
    }
end

-- Function to update the scoreboard
local function updateScoreboard(generation)
    -- Calculate success rates
    for i, bloodline in ipairs(bloodlines) do
        if bloodline.dummyCount > 0 then
            -- Convert score to a percentage (lower is better, so invert)
            local maxDistance = 113 -- Approximate max distance from start to goal
            local normalizedScore = math.min(bloodline.currentScore, maxDistance) / maxDistance
            bloodline.successRate = math.max(0, math.floor((1 - normalizedScore) * 100))
        end
    end
    
    -- Sort bloodlines by success rate (highest first)
    table.sort(bloodlines, function(a, b)
        return a.successRate > b.successRate
    end)
    
    -- Send update to all clients
    local scoreboardData = {
        generation = generation,
        bloodlines = bloodlines
    }
    ReplicatedStorage.UpdateScoreboard:FireAllClients(scoreboardData)
end

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
            obstacle.Color = Color3.fromRGB(255, 0, 0) -- Make them red to indicate danger
            obstacle.Parent = obstacles
        end
    else
        -- Update existing obstacles to be kill blocks if they aren't already
        for _, obstacle in pairs(obstacles:GetChildren()) do
            if obstacle:IsA("BasePart") then
                obstacle.Color = Color3.fromRGB(255, 0, 0) -- Make them red
            end
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
        torso.CanCollide = true -- Enable collision with environment
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
        head.CanCollide = true -- Enable collision with environment
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

-- Create a table to track which dummies hit obstacles
local dummiesHitObstacle = {}

-- Create a function to check for collisions with obstacles
local function checkObstacleCollisions()
    local obstacles = workspace.Platforms:FindFirstChild("Obstacles")
    if not obstacles then return end
    
    -- This function will run every frame to check if dummies are touching obstacles
    RunService.Heartbeat:Connect(function()
        for _, obstacle in pairs(obstacles:GetChildren()) do
            if obstacle:IsA("BasePart") then
                -- Get all parts overlapping with this obstacle
                local partsInObstacle = workspace:GetPartsInPart(obstacle)
                
                for _, part in ipairs(partsInObstacle) do
                    -- Check if the part belongs to a dummy
                    local model = part:FindFirstAncestorOfClass("Model")
                    if model and model:FindFirstChildOfClass("Humanoid") and model.Parent == workspace then
                        -- Record that this dummy hit an obstacle before destroying it
                        dummiesHitObstacle[model] = true
                        print("Dummy hit an obstacle and was destroyed!")
                        
                        -- Create a small explosion effect
                        local explosion = Instance.new("Explosion")
                        explosion.BlastRadius = 0
                        explosion.BlastPressure = 0
                        explosion.Position = model:GetPivot().Position
                        explosion.DestroyJointRadiusPercent = 0
                        explosion.ExplosionType = Enum.ExplosionType.NoCraters
                        explosion.Visible = true
                        explosion.Parent = workspace
                        
                        -- Destroy the dummy immediately
                        model:Destroy()
                    end
                end
            end
        end
    end)
    
    -- Also add TouchInterest to obstacles for more reliable detection
    for _, obstacle in pairs(obstacles:GetChildren()) do
        if obstacle:IsA("BasePart") then
            -- Add a touched event to each obstacle
            obstacle.Touched:Connect(function(otherPart)
                local model = otherPart:FindFirstAncestorOfClass("Model")
                if model and model:FindFirstChildOfClass("Humanoid") and model.Parent == workspace then
                    -- Check if we already processed this dummy
                    if not dummiesHitObstacle[model] then
                        dummiesHitObstacle[model] = true
                        print("Dummy touched obstacle and was destroyed!")
                        
                        -- Create a small explosion effect
                        local explosion = Instance.new("Explosion")
                        explosion.BlastRadius = 0
                        explosion.BlastPressure = 0
                        explosion.Position = model:GetPivot().Position
                        explosion.DestroyJointRadiusPercent = 0
                        explosion.ExplosionType = Enum.ExplosionType.NoCraters
                        explosion.Visible = true
                        explosion.Parent = workspace
                        
                        -- Destroy the dummy immediately
                        model:Destroy()
                    end
                end
            end)
        end
    end
end

-- Call the function to start checking for collisions
checkObstacleCollisions()

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
	for i = 1, NUM_RAYS * 4, 4 do
		local result = workspace:Raycast(pos, refCF.LookVector * RAY_DEPTH, CAST_PARAMS)
		local dist = RAY_DEPTH -- default to farthest away dist 
		if result and result.Instance then
			dist = (result.Position - pos).Magnitude -- if we have a hit, we update dist accordingly 
		end
		-- For each cast, we have to update all four weights
		table.insert(weights, genes[i] * (dist/RAY_DEPTH))       -- Forward
		table.insert(weights, genes[i + 1] * (dist/RAY_DEPTH))   -- Jump
		table.insert(weights, genes[i + 2] * (dist/RAY_DEPTH))   -- Left
		table.insert(weights, genes[i + 3] * (dist/RAY_DEPTH))   -- Right
		
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
	local moveLeftSum = 0
	local moveRightSum = 0
	
	for i, w in weights do
		-- Since each ray has multiple weights now, we distribute them
		local weightIndex = i % 4
		if weightIndex == 1 then
			moveSum += w -- Forward movement
		elseif weightIndex == 2 then
			jumpSum += w -- Jump
		elseif weightIndex == 3 then
			moveLeftSum += w -- Left movement
		elseif weightIndex == 0 then
			moveRightSum += w -- Right movement
		end
	end
	
	-- if our sums are positive, that means we do the action
	return moveSum > 0, jumpSum > 0, moveLeftSum > 0, moveRightSum > 0
end 

--[[
	Create a completely random gene with random weights.
	
	Gives the intial population variation and the chance to evolve based on random
	traits. 
]]
local function makeRandomGenome()
	local genes = {}
	-- Each ray has four values: forward, jump, left, right
	-- so our genome is 4 times rays  
	for i = 1, NUM_RAYS * 4 do
		table.insert(genes, rand:NextNumber(-1, 1))
	end
	return genes
end

--[[
	Makes the dummy a color based on their genes.
	Only leads to gray-blue-green colors because of the range
	of numbers we are dealing with but its good enough 
]]
local function colorDummy(dummy, genes, bloodlineIndex)
    -- If bloodlineIndex is provided, use that bloodline's color
    if bloodlineIndex then
        local color = bloodlines[bloodlineIndex].color
        for _, part in dummy:GetDescendants() do
            if part:IsA("BasePart") then
                part.Color = color
            end
        end
        -- Store the bloodline index on the dummy
        dummy:SetAttribute("BloodlineIndex", bloodlineIndex)
        return
    end
    
    -- Otherwise, calculate color from genes and assign to nearest bloodline
    local avg = 0
    for _, num in genes do
        avg += num
    end
    avg = math.abs(avg / #genes * 1000)
    
    -- Convert to a color
    local color = Color3.fromHex(string.format("%.3x", avg))
    
    -- Find the closest bloodline color using RGB components
    local closestIndex = 1
    local closestDistance = math.sqrt(
        (bloodlines[1].color.R - color.R)^2 + 
        (bloodlines[1].color.G - color.G)^2 + 
        (bloodlines[1].color.B - color.B)^2
    )
    
    for i = 2, #bloodlines do
        local distance = math.sqrt(
            (bloodlines[i].color.R - color.R)^2 + 
            (bloodlines[i].color.G - color.G)^2 + 
            (bloodlines[i].color.B - color.B)^2
        )
        if distance < closestDistance then
            closestDistance = distance
            closestIndex = i
        end
    end
    
    -- Use the bloodline color instead of the calculated one
    color = bloodlines[closestIndex].color
    
    for _, part in dummy:GetDescendants() do
        if part:IsA("BasePart") then
            part.Color = color
        end
    end
    
    -- Store the bloodline index on the dummy
    dummy:SetAttribute("BloodlineIndex", closestIndex)
    
    -- Increment the dummy count for this bloodline
    bloodlines[closestIndex].dummyCount += 1
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
	
	-- Store the initial position to track progress
	local initialPosition = dummy:GetPivot().Position
	
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
			-- Keep CanCollide true so they collide with environment
			part.CanCollide = true
		end
	end
	
	-- Store the best position (closest to goal) for fitness calculation
	local bestPosition = initialPosition
	local bestDistance = (initialPosition * Vector3.new(1, 0, 1) - workspace.Goal.Position * Vector3.new(1, 0, 1)).Magnitude
	
	local connection
	connection = RunService.Stepped:Connect(function()
		if not dummy.Parent then 
			-- When it is destroyed, we just want to stop this loop
			connection:Disconnect()
			return 
		end
		
		-- Get the dummy's position
		local dummyPos = dummy:GetPivot().Position
		
		-- Update best position if this is closer to the goal
		local currentDistance = (dummyPos * Vector3.new(1, 0, 1) - workspace.Goal.Position * Vector3.new(1, 0, 1)).Magnitude
		if currentDistance < bestDistance then
			bestDistance = currentDistance
			bestPosition = dummyPos
			
			-- Add a small visual indicator at the best position
			if not workspace:FindFirstChild("BestPos_" .. dummy.Name) then
				local marker = Instance.new("Part")
				marker.Name = "BestPos_" .. dummy.Name
				marker.Size = Vector3.new(0.5, 0.5, 0.5)
				marker.Position = bestPosition
				marker.Anchored = true
				marker.CanCollide = false
				marker.Transparency = 0.5
				marker.Color = dummy.HumanoidRootPart.Color
				marker.Shape = Enum.PartType.Ball
				marker.Parent = workspace
				
				-- Destroy the marker when the dummy is destroyed
				dummy.AncestryChanged:Connect(function(_, parent)
					if parent == nil and marker and marker.Parent then
						marker:Destroy()
					end
				end)
			end
		end
		
		-- Calculate weights and actions
		local weights = getWeights(dummyPos, genes)
		local shouldMoveForward, shouldJump, shouldMoveLeft, shouldMoveRight = getActions(weights)
		
		-- Calculate direction towards goal
		local goalDir = (workspace.Goal.Position - dummyPos).Unit
		goalDir = Vector3.new(goalDir.X, 0, goalDir.Z).Unit -- Flatten to XZ plane
		
		-- Calculate left and right directions relative to the goal direction
		local rightDir = Vector3.new(-goalDir.Z, 0, goalDir.X)
		local leftDir = Vector3.new(goalDir.Z, 0, -goalDir.X)
		
		-- Combine all movement directions
		local moveDir = Vector3.new(0, 0, 0)
		if shouldMoveForward then
			moveDir += goalDir
		end
		if shouldMoveLeft then
			moveDir += leftDir
		end
		if shouldMoveRight then
			moveDir += rightDir
		end
		
		-- Normalize the direction if it's not zero
		if moveDir.Magnitude > 0 then
			moveDir = moveDir.Unit
		end
		
		-- Move the dummy
		humanoid:Move(moveDir)
		
		-- Make the dummy jump
		humanoid.Jump = shouldJump
	end)
	
	-- Store the best position with the dummy for fitness calculation
	dummy:SetAttribute("BestPosition", bestPosition)
	dummy:SetAttribute("InitialPosition", initialPosition)
	
	return dummy
end

--[[
	Calculates the distance between dummy and goal, lower scores are better.
	
	This is used to find who survived the best, and give them reproduction priority. 
	Also provides visual feedback when a dummy reaches the goal.
]]
local function calcFitness(dummy, wasDestroyed)
    local bloodlineIndex = dummy:GetAttribute("BloodlineIndex") or 1
    
	-- If the dummy hit an obstacle, apply a penalty but still consider its progress
	if wasDestroyed then
		-- Get the best position the dummy reached before being destroyed
		local bestPos = dummy:GetAttribute("BestPosition")
		local initialPos = dummy:GetAttribute("InitialPosition")
		
		if bestPos then
			-- Calculate distance from best position to goal
			local bestDistance = (bestPos * Vector3.new(1, 0, 1) - workspace.Goal.Position * Vector3.new(1, 0, 1)).Magnitude
			
			-- Calculate how far the dummy moved from its starting position
			local initialDistance = (initialPos * Vector3.new(1, 0, 1) - workspace.Goal.Position * Vector3.new(1, 0, 1)).Magnitude
			local progressMade = initialDistance - bestDistance
			
			-- Apply obstacle penalty but give credit for progress made
			local score = 0
			if progressMade > 0 then
				-- The dummy made some progress, so penalize less
				score = OBSTACLE_PENALTY - progressMade
			else
				-- The dummy didn't make progress, full penalty
				score = OBSTACLE_PENALTY
			end
            
            -- Update bloodline score if this is better
            if score < bloodlines[bloodlineIndex].currentScore then
                bloodlines[bloodlineIndex].currentScore = score
            end
            
			return score
		else
			-- No best position recorded, apply full penalty
            if OBSTACLE_PENALTY < bloodlines[bloodlineIndex].currentScore then
                bloodlines[bloodlineIndex].currentScore = OBSTACLE_PENALTY
            end
			return OBSTACLE_PENALTY
		end
	end
	
	-- For dummies that are still alive, calculate based on current position
	local distance = (dummy:GetPivot().Position * Vector3.new(1, 0, 1) - workspace.Goal.Position * Vector3.new(1, 0, 1)).Magnitude
	
	-- Check if the dummy has reached the goal (within 5 studs)
	if distance < 5 then
		-- Visual feedback - make the dummy glow and change color when it reaches the goal
		for _, part in pairs(dummy:GetDescendants()) do
			if part:IsA("BasePart") then
				-- Make the part glow green
				part.Color = Color3.fromRGB(0, 255, 0)
				
				-- Add a highlight effect if it doesn't exist
				if not part:FindFirstChild("ReachedGoalEffect") then
					local highlight = Instance.new("Highlight")
					highlight.Name = "ReachedGoalEffect"
					highlight.FillColor = Color3.fromRGB(0, 255, 0)
					highlight.OutlineColor = Color3.fromRGB(255, 255, 0)
					highlight.FillTransparency = 0.5
					highlight.Parent = part
				end
			end
		end
		
		print("Dummy reached the goal! Distance: " .. distance)
        print("Bloodline " .. bloodlineIndex .. " reached the goal!")
        
        -- Update bloodline information
        bloodlines[bloodlineIndex].reachedGoal = true
        bloodlines[bloodlineIndex].currentScore = distance * 0.1
        if bloodlines[bloodlineIndex].bestScore > distance * 0.1 then
            bloodlines[bloodlineIndex].bestScore = distance * 0.1
        end
		
		-- Give a significant fitness bonus for reaching the goal
		-- Return a very low score (good fitness) with a small component based on actual distance
		-- This ensures dummies that reach the goal are always ranked higher than those that don't
		return distance * 0.1  -- Much better score than any dummy that doesn't reach the goal
	end
	
	-- For dummies that don't reach the goal, return their distance
    -- Update bloodline score if this is better
    if distance < bloodlines[bloodlineIndex].currentScore then
        bloodlines[bloodlineIndex].currentScore = distance
    end
    
	return distance
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
	local idx = rand:NextInteger(1, NUM_RAYS * 4)
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
	local goalReached = false
	for gen = 1, NUM_GENS do
		print("\n\n")
		print("*******************************************************")
		print("*                  GENERATION " .. gen .. "                      *")
		print("*******************************************************")
		
		-- Clear the obstacle hit tracking for this generation
		dummiesHitObstacle = {}
        
        -- Reset bloodline stats for this generation
        for i = 1, #bloodlines do
            bloodlines[i].currentScore = math.huge
            bloodlines[i].dummyCount = 0
        end
		
		-- Start by creating the population for this generation 
		local dummies = {}
		for i = 1, NUM_DUMMIES do
			dummies[i] = simulateDummy(genes[i])
		end
		print("Created " .. #dummies .. " dummies for generation " .. gen)
		print("Simulating for " .. GEN_TIME .. " seconds...")
		print("CHALLENGE MODE: Red obstacles will destroy dummies on contact!")
		task.wait(GEN_TIME)

		local scores = {}
		local reachedGoalCount = 0
		local killedByObstacleCount = 0
		
		for i, d in pairs(dummies) do
			if d and d.Parent then
				-- Dummy survived the generation
				local fitnessScore = calcFitness(d, false)
				scores[i] = {fitnessScore, genes[i], d:GetAttribute("BloodlineIndex") or 1}
				
				-- Check if this dummy reached the goal (score will be very low if it did)
				if fitnessScore < 5 then
					reachedGoalCount += 1
                    
                    -- Record which generation this bloodline first reached the goal
                    local bloodlineIndex = d:GetAttribute("BloodlineIndex") or 1
                    if bloodlines[bloodlineIndex].goalReachedGen == 0 then
                        bloodlines[bloodlineIndex].goalReachedGen = gen
                    end
				end
				
				-- Destroy all dummies immediately after scoring
				d:Destroy()
			else
				-- Dummy was destroyed during simulation
				killedByObstacleCount += 1
				
				-- Calculate a fitness score that considers how far it got before being destroyed
				local fitnessScore = calcFitness(dummies[i], true)
                local bloodlineIndex = dummies[i]:GetAttribute("BloodlineIndex") or 1
				scores[i] = {fitnessScore, genes[i], bloodlineIndex}
			end
		end

		-- Sort scores in ascending order, since good scores are low 
		table.sort(scores, function(a, b)
			return a[1] < b[1]
		end)
		
		-- Update all time best score 
		if scores[1] and scores[1][1] < bestScore then
			bestScore = scores[1][1]
			
			-- Check if the best dummy reached the goal
			if scores[1][1] < 5 then
				goalReached = true
				print("\n!!! SUCCESS! A dummy has reached the goal! !!!")
			end
		end
		
		-- Display detailed fitness scores for this generation with very clear formatting
		print("\n=======================================================")
		print("                FITNESS SCORES SUMMARY                 ")
		print("=======================================================")
		print("GENERATION " .. gen .. " BEST SCORE: " .. string.format("%.2f", scores[1][1]))
		print("ALL-TIME BEST SCORE: " .. string.format("%.2f", bestScore))
		print("-------------------------------------------------------")
		print("TOP 5 SCORES THIS GENERATION:")
		for i = 1, math.min(5, #scores) do
			print("  #" .. i .. ": " .. string.format("%.2f", scores[i][1]) .. " (Bloodline " .. scores[i][3] .. ")")
		end
		
		-- Calculate average score
		local sum = 0
		local count = 0
		for _, score in ipairs(scores) do
			if score[1] < OBSTACLE_PENALTY then -- Only count valid scores (not killed by obstacles)
				sum += score[1]
				count += 1
			end
		end
		local average = count > 0 and (sum / count) or 0
		print("-------------------------------------------------------")
		print("AVERAGE SCORE: " .. string.format("%.2f", average))
		print("DUMMIES THAT REACHED GOAL: " .. reachedGoalCount)
		print("DUMMIES KILLED BY OBSTACLES: " .. killedByObstacleCount)
        print("-------------------------------------------------------")
        print("BLOODLINE PERFORMANCE:")
        for i, bloodline in ipairs(bloodlines) do
            if bloodline.dummyCount > 0 then
                local status = bloodline.reachedGoal and "REACHED GOAL" or "IN PROGRESS"
                print("  Bloodline " .. i .. ": " .. string.format("%.2f", bloodline.currentScore) .. " - " .. status)
            end
        end
		print("=======================================================")
		
		if goalReached then
			print("Best dummy has reached the goal! Continuing evolution to optimize path...")
		end

		-- We wipe all genes, keep the top half of the good genes
		-- and add a bottom half of new children to hopefully make
		-- the population better able to survive
		-- (this is the reason we need num_dummies to be divisble by 4, it keeps gene count good)
		table.clear(genes)
        
        -- Track which bloodlines are being used for reproduction
        local bloodlineOffspring = {}
        for i = 1, #bloodlines do
            bloodlineOffspring[i] = 0
        end
        
		for i = 1, NUM_DUMMIES / 2 - 1, 2 do
			if scores[i] and scores[i+1] then
				local g1 = scores[i][2]
				local g2 = scores[i + 1][2]
                local b1 = scores[i][3]
                local b2 = scores[i+1][3]
				local c1, c2 = crossover(g1, g2)
				table.insert(genes, c1)
				table.insert(genes, c2)
				table.insert(genes, g1)
				table.insert(genes, g2)
                
                -- Track which bloodlines are reproducing
                bloodlineOffspring[b1] = bloodlineOffspring[b1] + 2
                bloodlineOffspring[b2] = bloodlineOffspring[b2] + 2
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
		
		-- Clean up any remaining markers
		for _, obj in pairs(workspace:GetChildren()) do
			if obj.Name:find("BestPos_") then
				obj:Destroy()
			end
		end
        
        -- Update the scoreboard
        updateScoreboard(gen)
	end
	
	print("\n\n*******************************************************")
	print("*         GENETIC ALGORITHM SIMULATION COMPLETE        *")
	print("*******************************************************")
	if goalReached then
		print("SUCCESS: Dummies successfully evolved to reach the goal!")
		print("Final best fitness score: " .. string.format("%.2f", bestScore))
        
        -- Print final bloodline stats
        print("\nBLOODLINE FINAL RESULTS:")
        for i, bloodline in ipairs(bloodlines) do
            local status = bloodline.reachedGoal and "REACHED GOAL (Gen " .. bloodline.goalReachedGen .. ")" or "FAILED"
            print("  Bloodline " .. i .. ": Best Score " .. string.format("%.2f", bloodline.bestScore) .. " - " .. status)
        end
	else
		print("The simulation ended without any dummies reaching the goal.")
		print("Best fitness score achieved: " .. string.format("%.2f", bestScore))
	end
    
    -- Final scoreboard update
    updateScoreboard(NUM_GENS)
end

-- Start the simulation
print("Waiting 2 seconds before starting simulation...")
task.wait(2) -- Wait a bit for the game to fully load
simulateEvolution()