local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GeneticAlgorithmUI = {}

print("Loading GeneticAlgorithmUI module...")

-- Get remote events
local remotes
local remoteEvents = {}

local function setupRemoteEvents()
    print("Setting up remote events...")
    remotes = ReplicatedStorage:WaitForChild("GeneticAlgorithmRemotes", 10)
    if not remotes then
        error("GeneticAlgorithmRemotes folder not found in ReplicatedStorage after 10 seconds")
    end
    
    local requiredEvents = {
        "startSimulation",
        "stopSimulation",
        "updateConfig",
        "getStatus",
        "generationCompleted",
        "simulationCompleted"
    }
    
    for _, eventName in ipairs(requiredEvents) do
        local event = remotes:WaitForChild(eventName, 5)
        if not event then
            error(eventName .. " not found in GeneticAlgorithmRemotes")
        end
        remoteEvents[eventName] = event
        print("Found remote event: " .. eventName)
    end
    
    print("Remote events setup complete")
end

local success, err = pcall(setupRemoteEvents)
if not success then
    warn("Failed to set up remote events: " .. tostring(err))
    -- We'll continue anyway and try to create the UI
end

-- UI elements
local ui = {}

-- Create the main UI
function GeneticAlgorithmUI.createUI()
    print("Creating UI...")
    local player = Players.LocalPlayer
    if not player then
        error("LocalPlayer not found")
    end
    
    local playerGui = player:WaitForChild("PlayerGui", 5)
    if not playerGui then
        error("PlayerGui not found for LocalPlayer")
    end
    
    -- Check if UI already exists and remove it
    local existingUI = playerGui:FindFirstChild("GeneticAlgorithmUI")
    if existingUI then
        existingUI:Destroy()
        print("Removed existing UI")
    end
    
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
    
    -- Add status message
    local statusMessage = Instance.new("TextLabel")
    statusMessage.Name = "StatusMessage"
    statusMessage.Size = UDim2.new(1, -20, 0, 40)
    statusMessage.Position = UDim2.new(0, 10, 0, 350)
    statusMessage.BackgroundTransparency = 1
    statusMessage.Text = "Ready"
    statusMessage.TextColor3 = Color3.fromRGB(255, 255, 255)
    statusMessage.TextSize = 14
    statusMessage.Font = Enum.Font.SourceSans
    statusMessage.TextXAlignment = Enum.TextXAlignment.Left
    statusMessage.TextWrapped = true
    statusMessage.Parent = mainFrame
    
    ui.StatusMessage = statusMessage
    
    -- Store UI elements
    ui.screenGui = screenGui
    ui.mainFrame = mainFrame
    
    print("UI created successfully")
    return ui
end

-- Connect UI events
function GeneticAlgorithmUI.connectEvents(ui)
    print("Connecting UI events...")
    
    if not remoteEvents.startSimulation or not remoteEvents.stopSimulation then
        ui.StatusMessage.Text = "Error: Remote events not found. Server may not be ready."
        ui.StartButton.Active = false
        ui.StopButton.Active = false
        warn("Cannot connect UI events: Remote events not found")
        return
    end
    
    -- Start button
    ui.StartButton.MouseButton1Click:Connect(function()
        print("Start button clicked")
        ui.StatusMessage.Text = "Starting simulation..."
        
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
        local success, err = pcall(function()
            remoteEvents.updateConfig:FireServer(config)
        end)
        
        if not success then
            ui.StatusMessage.Text = "Error updating config: " .. tostring(err)
            warn("Error updating config: " .. tostring(err))
            return
        end
        
        -- Start simulation
        success, err = pcall(function()
            remoteEvents.startSimulation:FireServer()
        end)
        
        if not success then
            ui.StatusMessage.Text = "Error starting simulation: " .. tostring(err)
            warn("Error starting simulation: " .. tostring(err))
            return
        end
        
        ui.StatusMessage.Text = "Simulation started"
    end)
    
    -- Stop button
    ui.StopButton.MouseButton1Click:Connect(function()
        print("Stop button clicked")
        ui.StatusMessage.Text = "Stopping simulation..."
        
        local success, err = pcall(function()
            remoteEvents.stopSimulation:FireServer()
        end)
        
        if not success then
            ui.StatusMessage.Text = "Error stopping simulation: " .. tostring(err)
            warn("Error stopping simulation: " .. tostring(err))
            return
        end
        
        ui.StatusMessage.Text = "Simulation stopped"
    end)
    
    -- Generation completed event
    if remoteEvents.generationCompleted then
        remoteEvents.generationCompleted.OnClientEvent:Connect(function(generation, bestScore, bestGenes)
            print("Generation completed event received: " .. generation)
            
            local success, status = pcall(function()
                return remoteEvents.getStatus:InvokeServer()
            end)
            
            if success then
                updateStatusDisplay(ui, status)
                ui.StatusMessage.Text = "Generation " .. generation .. " completed"
            else
                warn("Error getting status: " .. tostring(status))
            end
        end)
    else
        warn("generationCompleted event not found")
    end
    
    -- Simulation completed event
    if remoteEvents.simulationCompleted then
        remoteEvents.simulationCompleted.OnClientEvent:Connect(function(bestScore)
            print("Simulation completed event received")
            
            local success, status = pcall(function()
                return remoteEvents.getStatus:InvokeServer()
            end)
            
            if success then
                updateStatusDisplay(ui, status)
                ui.StatusMessage.Text = "Simulation completed. Best score: " .. bestScore
            else
                warn("Error getting status: " .. tostring(status))
            end
        end)
    else
        warn("simulationCompleted event not found")
    end
    
    print("UI events connected")
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
    print("Initializing GeneticAlgorithmUI...")
    
    local ui = GeneticAlgorithmUI.createUI()
    GeneticAlgorithmUI.connectEvents(ui)
    
    -- Initial status update
    task.spawn(function()
        task.wait(2) -- Wait a bit for the server to initialize
        
        if remoteEvents.getStatus then
            local success, status = pcall(function()
                return remoteEvents.getStatus:InvokeServer()
            end)
            
            if success then
                updateStatusDisplay(ui, status)
                ui.StatusMessage.Text = "Connected to server"
            else
                ui.StatusMessage.Text = "Error connecting to server: " .. tostring(status)
                warn("Error getting status: " .. tostring(status))
            end
        else
            ui.StatusMessage.Text = "Error: getStatus remote function not found"
            warn("getStatus remote function not found")
        end
    end)
    
    print("GeneticAlgorithmUI initialized")
    return ui
end

return GeneticAlgorithmUI 