local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GeneticAlgorithm = require(ReplicatedStorage.Shared.GeneticAlgorithm)

local SimulationManager = {}
SimulationManager.__index = SimulationManager

-- Default configuration
local DEFAULT_CONFIG = {
    numDummies = 32, -- Must be divisible by 4 for the algorithm to work properly
    numGenerations = 25,
    generationTime = 5, -- seconds
    platformsFolder = nil, -- Will be set during initialization
    dummyTemplate = nil, -- Will be set during initialization
    startPosition = nil, -- Will be set during initialization
    goalPosition = nil, -- Will be set during initialization
    isRunning = false,
    currentGeneration = 0,
    bestScore = math.huge,
    activeSimulations = {}
}

-- Create a new simulation manager
function SimulationManager.new(config)
    print("Creating new SimulationManager instance")
    local self = setmetatable({}, SimulationManager)
    
    -- Apply default config and override with provided config
    self.config = table.clone(DEFAULT_CONFIG)
    if config then
        for key, value in pairs(config) do
            self.config[key] = value
        end
    end
    
    -- Initialize raycast parameters
    self.castParams = RaycastParams.new()
    self.castParams.FilterType = Enum.RaycastFilterType.Whitelist
    
    -- Create events
    self.events = {
        generationCompleted = Instance.new("BindableEvent"),
        simulationCompleted = Instance.new("BindableEvent"),
        dummyUpdated = Instance.new("BindableEvent")
    }
    
    print("SimulationManager instance created")
    return self
end

-- Initialize the simulation with the required instances
function SimulationManager:initialize(platformsFolder, dummyTemplate, startPosition, goalPosition)
    print("Initializing SimulationManager with:")
    print("- platformsFolder: " .. (platformsFolder and platformsFolder:GetFullName() or "nil"))
    print("- dummyTemplate: " .. (dummyTemplate and dummyTemplate:GetFullName() or "nil"))
    print("- startPosition: " .. (startPosition and startPosition:GetFullName() or "nil"))
    print("- goalPosition: " .. (goalPosition and goalPosition:GetFullName() or "nil"))
    
    self.config.platformsFolder = platformsFolder
    self.config.dummyTemplate = dummyTemplate
    self.config.startPosition = startPosition
    self.config.goalPosition = goalPosition
    
    -- Set up raycast filter
    self.castParams.FilterDescendantsInstances = {platformsFolder}
    
    print("SimulationManager initialization complete")
    return self
end

-- Simulate a single dummy with the given genes
function SimulationManager:simulateDummy(genes)
    print("simulateDummy called with genes length: " .. (genes and #genes or "nil"))
    
    if not self.config.dummyTemplate then
        warn("Dummy template is nil!")
        return nil
    end
    
    -- Check if genes are valid
    if not genes or #genes < GeneticAlgorithm.NUM_RAYS * 2 then
        print("Creating default genes because provided genes are invalid")
        genes = GeneticAlgorithm.makeRandomGenome()
    end
    
    print("Cloning dummy template")
    local dummy = self.config.dummyTemplate:Clone()
    if not dummy then
        warn("Failed to clone dummy template!")
        return nil
    end
    
    -- Ensure the dummy has a humanoid
    local humanoid = dummy:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        warn("Dummy has no humanoid! Creating one...")
        humanoid = Instance.new("Humanoid")
        humanoid.Parent = dummy
    end
    
    -- Ensure the dummy has a HumanoidRootPart
    local rootPart = dummy:FindFirstChild("HumanoidRootPart")
    if not rootPart then
        warn("Dummy has no HumanoidRootPart! Creating one...")
        rootPart = Instance.new("Part")
        rootPart.Name = "HumanoidRootPart"
        rootPart.Size = Vector3.new(2, 2, 1)
        rootPart.Parent = dummy
        humanoid.RootPart = rootPart
    end
    
    -- Set humanoid properties for better movement
    humanoid.WalkSpeed = 16
    humanoid.JumpPower = 50
    humanoid.JumpHeight = 7.2
    
    -- Parent the dummy to workspace
    print("Parenting dummy to workspace")
    dummy.Parent = workspace
    
    -- Position the dummy at the start
    if self.config.startPosition then
        local startCF = self.config.startPosition.CFrame + Vector3.new(0, 3, 0) -- Lift it above the start platform
        dummy:PivotTo(startCF)
        print("Positioned dummy at start: " .. tostring(startCF.Position))
    else
        warn("Start position is nil!")
    end
    
    -- Color the dummy based on genes
    print("Coloring dummy based on genes")
    GeneticAlgorithm.colorDummy(dummy, genes)
    
    -- Store the dummy in active simulations
    table.insert(self.config.activeSimulations, dummy)
    
    -- Set up the dummy's behavior
    print("Setting up dummy behavior")
    local connection
    connection = RunService.Stepped:Connect(function()
        if not dummy or not dummy.Parent then
            if connection then
                connection:Disconnect()
            end
            return
        end
        
        if not humanoid or humanoid.Health <= 0 then
            if connection then
                connection:Disconnect()
            end
            return
        end
        
        -- Get the dummy's position
        local dummyPos = dummy:GetPivot().Position
        
        -- Check if the dummy fell off the platform
        if dummyPos.Y < -10 then
            print("Dummy fell off the platform")
            if connection then
                connection:Disconnect()
            end
            if dummy and dummy.Parent then
                dummy:Destroy()
            end
            return
        end
        
        -- Calculate weights and actions
        local weights = GeneticAlgorithm.getWeights(dummyPos, genes, self.castParams)
        local shouldMove, shouldJump = GeneticAlgorithm.getActions(weights)
        
        -- Control the dummy's movement
        if shouldMove then
            -- Calculate direction towards goal
            local goalDir = (self.config.goalPosition.Position - dummyPos).Unit
            goalDir = Vector3.new(goalDir.X, 0, goalDir.Z).Unit -- Flatten to XZ plane
            
            -- Move towards goal
            humanoid:Move(goalDir)
        else
            humanoid:Move(Vector3.new(0, 0, 0))
        end
        
        -- Control jumping
        humanoid.Jump = shouldJump
        
        -- Fire update event for client visualization
        self.events.dummyUpdated:Fire(dummy, weights)
    end)
    
    print("Dummy created and behavior set up successfully")
    return dummy
end

-- Run a complete simulation with multiple generations
function SimulationManager:runSimulation()
    print("runSimulation called")
    
    if self.config.isRunning then
        self.lastError = "Simulation is already running"
        warn(self.lastError)
        return false, self.lastError
    end
    
    print("Starting simulation with " .. self.config.numDummies .. " dummies for " .. self.config.numGenerations .. " generations")
    
    self.config.isRunning = true
    self.config.currentGeneration = 0
    self.config.bestScore = math.huge
    
    -- Initialize genes for the first generation
    print("Initializing genes for first generation")
    local genes = {}
    for i = 1, self.config.numDummies do
        table.insert(genes, GeneticAlgorithm.makeRandomGenome())
    end
    
    -- Run the simulation asynchronously
    print("Spawning simulation task")
    task.spawn(function()
        print("Simulation task started")
        for gen = 1, self.config.numGenerations do
            if not self.config.isRunning then 
                print("Simulation stopped early")
                break 
            end
            
            self.config.currentGeneration = gen
            print(string.format("Generation %i; Best Fitness Score: %f", gen, self.config.bestScore))
            
            -- Create dummies for this generation
            print("Creating dummies for generation " .. gen)
            local dummies = {}
            for i = 1, self.config.numDummies do
                print("Creating dummy " .. i .. " of " .. self.config.numDummies)
                local dummy = self:simulateDummy(genes[i])
                if dummy then
                    dummies[i] = dummy
                    print("Dummy " .. i .. " created successfully")
                else
                    warn("Failed to create dummy " .. i)
                end
            end
            
            -- Wait for the generation to complete
            print("Waiting " .. self.config.generationTime .. " seconds for generation to complete")
            task.wait(self.config.generationTime)
            
            -- Calculate fitness scores
            print("Calculating fitness scores")
            local scores = {}
            for i, d in pairs(dummies) do
                if d and d.Parent then
                    local score = GeneticAlgorithm.calcFitness(d, self.config.goalPosition)
                    scores[i] = {score, genes[i]}
                    print("Dummy " .. i .. " score: " .. score)
                    d:Destroy()
                else
                    -- If dummy was destroyed (fell off), give it a bad score
                    scores[i] = {1000, genes[i]}
                    print("Dummy " .. i .. " was destroyed")
                end
            end
            
            -- Clear active simulations
            table.clear(self.config.activeSimulations)
            
            -- Sort scores (lower is better)
            table.sort(scores, function(a, b)
                return a[1] < b[1]
            end)
            
            -- Update best score
            if scores[1] and scores[1][1] < self.config.bestScore then
                self.config.bestScore = scores[1][1]
                print("New best score: " .. self.config.bestScore)
            end
            
            -- Create the next generation through selection, crossover, and mutation
            print("Creating next generation")
            table.clear(genes)
            for i = 1, self.config.numDummies / 2 - 1, 2 do
                if scores[i] and scores[i+1] then
                    local g1 = scores[i][2]
                    local g2 = scores[i + 1][2]
                    local c1, c2 = GeneticAlgorithm.crossover(g1, g2)
                    table.insert(genes, c1)
                    table.insert(genes, c2)
                    table.insert(genes, g1)
                    table.insert(genes, g2)
                end
            end
            
            -- If we don't have enough genes, fill with random ones
            while #genes < self.config.numDummies do
                table.insert(genes, GeneticAlgorithm.makeRandomGenome())
            end
            
            -- Apply mutations
            print("Applying mutations")
            for _, gene in pairs(genes) do
                if Random.new():NextNumber() < GeneticAlgorithm.MUTATION_RATE then
                    GeneticAlgorithm.pointMutate(gene)
                end
            end
            
            -- Fire generation completed event
            print("Generation " .. gen .. " completed")
            self.events.generationCompleted:Fire(gen, self.config.bestScore, scores[1] and scores[1][2] or nil)
        end
        
        -- Simulation completed
        self.config.isRunning = false
        self.events.simulationCompleted:Fire(self.config.bestScore)
        print("Simulation completed with best score: " .. self.config.bestScore)
    end)
    
    print("Simulation started successfully")
    return true
end

-- Stop the current simulation
function SimulationManager:stopSimulation()
    print("stopSimulation called")
    
    if not self.config.isRunning then
        self.lastError = "No simulation is running"
        warn(self.lastError)
        return false, self.lastError
    end
    
    self.config.isRunning = false
    
    -- Clean up any active dummies
    print("Cleaning up active dummies: " .. #self.config.activeSimulations)
    for _, dummy in pairs(self.config.activeSimulations) do
        if dummy and dummy.Parent then
            dummy:Destroy()
        end
    end
    
    table.clear(self.config.activeSimulations)
    
    print("Simulation stopped successfully")
    return true
end

-- Get the current simulation status
function SimulationManager:getStatus()
    return {
        isRunning = self.config.isRunning,
        currentGeneration = self.config.currentGeneration,
        totalGenerations = self.config.numGenerations,
        bestScore = self.config.bestScore,
        numDummies = self.config.numDummies
    }
end

-- Update simulation parameters
function SimulationManager:updateConfig(newConfig)
    print("updateConfig called with:")
    for key, value in pairs(newConfig) do
        print("  - " .. key .. ": " .. tostring(value))
    end
    
    if self.config.isRunning then
        self.lastError = "Cannot update config while simulation is running"
        warn(self.lastError)
        return false, self.lastError
    end
    
    for key, value in pairs(newConfig) do
        if self.config[key] ~= nil then
            self.config[key] = value
            print("Updated config " .. key .. " to " .. tostring(value))
        end
    end
    
    print("Configuration updated successfully")
    return true
end

return SimulationManager 