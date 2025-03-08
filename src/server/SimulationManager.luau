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
    
    return self
end

-- Initialize the simulation with the required instances
function SimulationManager:initialize(platformsFolder, dummyTemplate, startPosition, goalPosition)
    self.config.platformsFolder = platformsFolder
    self.config.dummyTemplate = dummyTemplate
    self.config.startPosition = startPosition
    self.config.goalPosition = goalPosition
    
    -- Set up raycast filter
    self.castParams.FilterDescendantsInstances = {platformsFolder}
    
    return self
end

-- Simulate a single dummy with the given genes
function SimulationManager:simulateDummy(genes)
    local dummy = self.config.dummyTemplate:Clone()
    dummy.Parent = workspace
    
    -- Position the dummy at the start
    dummy:PivotTo(self.config.startPosition.CFrame)
    
    -- Color the dummy based on genes
    GeneticAlgorithm.colorDummy(dummy, genes)
    
    -- Store the dummy in active simulations
    table.insert(self.config.activeSimulations, dummy)
    
    -- Set up the dummy's behavior
    local connection
    connection = RunService.Stepped:Connect(function()
        if not dummy.Parent then
            connection:Disconnect()
            return
        end
        
        local weights = GeneticAlgorithm.getWeights(dummy:GetPivot().Position, genes, self.castParams)
        local shouldMove, shouldJump = GeneticAlgorithm.getActions(weights)
        
        -- Control the dummy's movement
        dummy.Humanoid:Move(-Vector3.zAxis * (shouldMove and 1 or 0))
        dummy.Humanoid.Jump = shouldJump
        
        -- Fire update event for client visualization
        self.events.dummyUpdated:Fire(dummy, weights)
    end)
    
    return dummy
end

-- Run a complete simulation with multiple generations
function SimulationManager:runSimulation()
    if self.config.isRunning then
        return false, "Simulation is already running"
    end
    
    self.config.isRunning = true
    self.config.currentGeneration = 0
    self.config.bestScore = math.huge
    
    -- Initialize genes for the first generation
    local genes = {}
    for i = 1, self.config.numDummies do
        table.insert(genes, GeneticAlgorithm.makeRandomGenome())
    end
    
    -- Run the simulation asynchronously
    task.spawn(function()
        for gen = 1, self.config.numGenerations do
            if not self.config.isRunning then break end
            
            self.config.currentGeneration = gen
            print(string.format("Generation %i; Best Fitness Score: %f", gen, self.config.bestScore))
            
            -- Create dummies for this generation
            local dummies = {}
            for i = 1, self.config.numDummies do
                dummies[i] = self:simulateDummy(genes[i])
            end
            
            -- Wait for the generation to complete
            task.wait(self.config.generationTime)
            
            -- Calculate fitness scores
            local scores = {}
            for i, d in dummies do
                scores[i] = {GeneticAlgorithm.calcFitness(d, self.config.goalPosition), genes[i]}
                d:Destroy()
            end
            
            -- Clear active simulations
            table.clear(self.config.activeSimulations)
            
            -- Sort scores (lower is better)
            table.sort(scores, function(a, b)
                return a[1] < b[1]
            end)
            
            -- Update best score
            if scores[1][1] < self.config.bestScore then
                self.config.bestScore = scores[1][1]
            end
            
            -- Create the next generation through selection, crossover, and mutation
            table.clear(genes)
            for i = 1, self.config.numDummies / 2 - 1, 2 do
                local g1 = scores[i][2]
                local g2 = scores[i + 1][2]
                local c1, c2 = GeneticAlgorithm.crossover(g1, g2)
                table.insert(genes, c1)
                table.insert(genes, c2)
                table.insert(genes, g1)
                table.insert(genes, g2)
            end
            
            -- Apply mutations
            for _, gene in genes do
                if Random.new():NextNumber() < GeneticAlgorithm.MUTATION_RATE then
                    GeneticAlgorithm.pointMutate(gene)
                end
            end
            
            -- Fire generation completed event
            self.events.generationCompleted:Fire(gen, self.config.bestScore, scores[1][2])
        end
        
        -- Simulation completed
        self.config.isRunning = false
        self.events.simulationCompleted:Fire(self.config.bestScore)
    end)
    
    return true
end

-- Stop the current simulation
function SimulationManager:stopSimulation()
    if not self.config.isRunning then
        return false, "No simulation is running"
    end
    
    self.config.isRunning = false
    
    -- Clean up any active dummies
    for _, dummy in self.config.activeSimulations do
        if dummy and dummy.Parent then
            dummy:Destroy()
        end
    end
    
    table.clear(self.config.activeSimulations)
    
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
    if self.config.isRunning then
        return false, "Cannot update config while simulation is running"
    end
    
    for key, value in pairs(newConfig) do
        if self.config[key] ~= nil then
            self.config[key] = value
        end
    end
    
    return true
end

return SimulationManager 