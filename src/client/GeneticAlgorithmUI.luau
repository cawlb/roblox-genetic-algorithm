local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GeneticAlgorithmUI = {}

-- Get remote events
local remotes = ReplicatedStorage:WaitForChild("GeneticAlgorithmRemotes")
local remoteEvents = {
    startSimulation = remotes:WaitForChild("startSimulation"),
    stopSimulation = remotes:WaitForChild("stopSimulation"),
    updateConfig = remotes:WaitForChild("updateConfig"),
    getStatus = remotes:WaitForChild("getStatus"),
    generationCompleted = remotes:WaitForChild("generationCompleted"),
    simulationCompleted = remotes:WaitForChild("simulationCompleted")
}

-- UI elements
local ui = {}

-- Create the main UI
function GeneticAlgorithmUI.createUI()
    local player = Players.LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui")
    
    -- Create ScreenGui
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "GeneticAlgorithmUI"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = playerGui
    
    -- Create main frame
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 300, 0, 400)
    mainFrame.Position = UDim2.new(1, -320, 0, 20)
    mainFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui
    
    -- Add title
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "TitleLabel"
    titleLabel.Size = UDim2.new(1, 0, 0, 40)
    titleLabel.Position = UDim2.new(0, 0, 0, 0)
    titleLabel.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    titleLabel.BorderSizePixel = 0
    titleLabel.Text = "Genetic Algorithm Simulator"
    titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleLabel.TextSize = 18
    titleLabel.Font = Enum.Font.SourceSansBold
    titleLabel.Parent = mainFrame
    
    -- Create content frame
    local contentFrame = Instance.new("Frame")
    contentFrame.Name = "ContentFrame"
    contentFrame.Size = UDim2.new(1, -20, 1, -60)
    contentFrame.Position = UDim2.new(0, 10, 0, 50)
    contentFrame.BackgroundTransparency = 1
    contentFrame.Parent = mainFrame
    
    -- Add status section
    local statusFrame = Instance.new("Frame")
    statusFrame.Name = "StatusFrame"
    statusFrame.Size = UDim2.new(1, 0, 0, 100)
    statusFrame.Position = UDim2.new(0, 0, 0, 0)
    statusFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    statusFrame.BorderSizePixel = 0
    statusFrame.Parent = contentFrame
    
    -- Status labels
    local statusLabels = {
        { name = "Status", text = "Status: Not Running" },
        { name = "Generation", text = "Generation: 0/0" },
        { name = "BestScore", text = "Best Score: N/A" },
        { name = "NumDummies", text = "Population: 0" }
    }
    
    for i, labelInfo in ipairs(statusLabels) do
        local label = Instance.new("TextLabel")
        label.Name = labelInfo.name .. "Label"
        label.Size = UDim2.new(1, -20, 0, 20)
        label.Position = UDim2.new(0, 10, 0, 10 + (i-1) * 25)
        label.BackgroundTransparency = 1
        label.Text = labelInfo.text
        label.TextColor3 = Color3.fromRGB(255, 255, 255)
        label.TextSize = 14
        label.Font = Enum.Font.SourceSans
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = statusFrame
        
        ui[labelInfo.name .. "Label"] = label
    end
    
    -- Add configuration section
    local configFrame = Instance.new("Frame")
    configFrame.Name = "ConfigFrame"
    configFrame.Size = UDim2.new(1, 0, 0, 150)
    configFrame.Position = UDim2.new(0, 0, 0, 110)
    configFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    configFrame.BorderSizePixel = 0
    configFrame.Parent = contentFrame
    
    -- Configuration title
    local configTitle = Instance.new("TextLabel")
    configTitle.Name = "ConfigTitle"
    configTitle.Size = UDim2.new(1, -20, 0, 20)
    configTitle.Position = UDim2.new(0, 10, 0, 10)
    configTitle.BackgroundTransparency = 1
    configTitle.Text = "Configuration"
    configTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    configTitle.TextSize = 16
    configTitle.Font = Enum.Font.SourceSansBold
    configTitle.TextXAlignment = Enum.TextXAlignment.Left
    configTitle.Parent = configFrame
    
    -- Configuration inputs
    local configInputs = {
        { name = "NumDummies", label = "Population Size:", default = "32" },
        { name = "NumGenerations", label = "Generations:", default = "25" },
        { name = "GenerationTime", label = "Gen. Time (sec):", default = "5" }
    }
    
    for i, inputInfo in ipairs(configInputs) do
        -- Label
        local label = Instance.new("TextLabel")
        label.Name = inputInfo.name .. "Label"
        label.Size = UDim2.new(0.5, -20, 0, 20)
        label.Position = UDim2.new(0, 10, 0, 40 + (i-1) * 30)
        label.BackgroundTransparency = 1
        label.Text = inputInfo.label
        label.TextColor3 = Color3.fromRGB(255, 255, 255)
        label.TextSize = 14
        label.Font = Enum.Font.SourceSans
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = configFrame
        
        -- Input box
        local input = Instance.new("TextBox")
        input.Name = inputInfo.name .. "Input"
        input.Size = UDim2.new(0.5, -20, 0, 20)
        input.Position = UDim2.new(0.5, 10, 0, 40 + (i-1) * 30)
        input.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
        input.BorderSizePixel = 0
        input.Text = inputInfo.default
        input.TextColor3 = Color3.fromRGB(255, 255, 255)
        input.TextSize = 14
        input.Font = Enum.Font.SourceSans
        input.Parent = configFrame
        
        ui[inputInfo.name .. "Input"] = input
    end
    
    -- Add buttons section
    local buttonsFrame = Instance.new("Frame")
    buttonsFrame.Name = "ButtonsFrame"
    buttonsFrame.Size = UDim2.new(1, 0, 0, 80)
    buttonsFrame.Position = UDim2.new(0, 0, 0, 270)
    buttonsFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    buttonsFrame.BorderSizePixel = 0
    buttonsFrame.Parent = contentFrame
    
    -- Buttons
    local buttons = {
        { name = "Start", text = "Start Simulation", position = UDim2.new(0, 10, 0, 10), color = Color3.fromRGB(0, 120, 0) },
        { name = "Stop", text = "Stop Simulation", position = UDim2.new(0, 10, 0, 40), color = Color3.fromRGB(120, 0, 0) }
    }
    
    for _, buttonInfo in ipairs(buttons) do
        local button = Instance.new("TextButton")
        button.Name = buttonInfo.name .. "Button"
        button.Size = UDim2.new(1, -20, 0, 25)
        button.Position = buttonInfo.position
        button.BackgroundColor3 = buttonInfo.color
        button.BorderSizePixel = 0
        button.Text = buttonInfo.text
        button.TextColor3 = Color3.fromRGB(255, 255, 255)
        button.TextSize = 14
        button.Font = Enum.Font.SourceSansBold
        button.Parent = buttonsFrame
        
        ui[buttonInfo.name .. "Button"] = button
    end
    
    -- Store UI elements
    ui.screenGui = screenGui
    ui.mainFrame = mainFrame
    
    return ui
end

-- Connect UI events
function GeneticAlgorithmUI.connectEvents(ui)
    -- Start button
    ui.StartButton.MouseButton1Click:Connect(function()
        -- Update configuration before starting
        local config = {
            numDummies = tonumber(ui.NumDummiesInput.Text) or 32,
            numGenerations = tonumber(ui.NumGenerationsInput.Text) or 25,
            generationTime = tonumber(ui.GenerationTimeInput.Text) or 5
        }
        
        -- Ensure numDummies is divisible by 4
        if config.numDummies % 4 ~= 0 then
            config.numDummies = math.floor(config.numDummies / 4) * 4
            if config.numDummies < 4 then config.numDummies = 4 end
            ui.NumDummiesInput.Text = tostring(config.numDummies)
        end
        
        -- Update configuration
        remoteEvents.updateConfig:FireServer(config)
        
        -- Start simulation
        remoteEvents.startSimulation:FireServer()
    end)
    
    -- Stop button
    ui.StopButton.MouseButton1Click:Connect(function()
        remoteEvents.stopSimulation:FireServer()
    end)
    
    -- Generation completed event
    remoteEvents.generationCompleted.OnClientEvent:Connect(function(generation, bestScore, bestGenes)
        local status = remoteEvents.getStatus:InvokeServer()
        updateStatusDisplay(ui, status)
    end)
    
    -- Simulation completed event
    remoteEvents.simulationCompleted.OnClientEvent:Connect(function(bestScore)
        local status = remoteEvents.getStatus:InvokeServer()
        updateStatusDisplay(ui, status)
    end)
end

-- Update status display
function updateStatusDisplay(ui, status)
    ui.StatusLabel.Text = "Status: " .. (status.isRunning and "Running" or "Not Running")
    ui.GenerationLabel.Text = string.format("Generation: %d/%d", status.currentGeneration, status.totalGenerations)
    ui.BestScoreLabel.Text = string.format("Best Score: %.2f", status.bestScore ~= math.huge and status.bestScore or 0)
    ui.NumDummiesLabel.Text = string.format("Population: %d", status.numDummies)
end

-- Initialize the UI
function GeneticAlgorithmUI.init()
    local ui = GeneticAlgorithmUI.createUI()
    GeneticAlgorithmUI.connectEvents(ui)
    
    -- Initial status update
    task.spawn(function()
        task.wait(1) -- Wait a bit for the server to initialize
        local status = remoteEvents.getStatus:InvokeServer()
        updateStatusDisplay(ui, status)
    end)
    
    return ui
end

return GeneticAlgorithmUI 