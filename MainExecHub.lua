local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Camera = Workspace.CurrentCamera

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local char = player.Character or player.CharacterAdded:Wait()
local humanoid = char:WaitForChild("Humanoid")
local rootPart = char:WaitForChild("HumanoidRootPart")

-- State variables
local state = {
    isFlying = false,
    flySpeed = 50,
    bodyVelocity = nil,
    bodyGyro = nil,
    flightConnection = nil,
    boundKeyFly = Enum.KeyCode.F,
    boundKeyPartSpawn = Enum.KeyCode.P,
    boundKeyFloat = Enum.KeyCode.O,
    boundKeyDirection = Enum.KeyCode.U,
    boundKeyTeleport = Enum.KeyCode.T,
    boundKeySpeed = Enum.KeyCode.R,
    boundKeyCFrameSpeed = Enum.KeyCode.E,
    boundKeyScreenVisibility = Enum.KeyCode.V,
    boundKeyRagdollPower = Enum.KeyCode.N,
    spawnDistance = 5,
    underFeetPart = nil,
    directionPart = nil,
    renderConnection = nil,
    deathPosition = nil,
    teleportOnDeathEnabled = false,
    targetPlayer = nil,
    walkSpeed = 16,
    speedEnabled = false,
    cframeSpeed = 2,
    cframeSpeedEnabled = false,
    cframeConnection = nil,
    followEnabled = false,
    followConnection = nil,
    followTargetPlayer = nil,
    followDistance = 5,
    screenVisible = true,
    directionPartSize = Vector3.new(5, 1, 5),
    directionPartColor = BrickColor.new("Bright red"),
    directionPartTransparency = 0,
    directionPartCanCollide = true,
    directionPartAnchored = true,
    noDashCooldown = false,
    noMeleeCooldown = false,
    noWallComboCooldown = false,
    dashSpeedMultiplier = 100,
    meleeSpeedMultiplier = 100,
    ragdollTimerMultiplier = 100,
    ragdollPowerActive = false,
    guiVisible = true,
    originalRagdollTimer = 100,
    instantTransform = true,
    noSlowdowns = true,
    noStunOnMiss = true,
    disableFinishers = true,
    disableHitStun = true,
    noJumpFatigue = true,
    disableCombatTimer = true,
    disableBlocking = false,
    screenConnection = nil
}

local connections = {}

-- Screen object handling
local screen = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("Screens") and Workspace.Map.Screens:FindFirstChild("Leaderboards") and Workspace.Map.Screens.Leaderboards:FindFirstChild("Total") and Workspace.Map.Screens.Leaderboards.Total:FindFirstChild("Screen")
local beam = screen and screen:FindFirstChild("Beam")
if beam then beam:Destroy() end
local surfacegui = screen and screen:FindFirstChild("SurfaceGui")
if surfacegui then surfacegui.Enabled = false end

local function updateScreenPosition()
    if screen and char and char:FindFirstChild("HumanoidRootPart") and not state.followEnabled then
        if screen:IsA("BasePart") then
            screen.Size = Vector3.new(3, 3, 3)
            screen.CanCollide = true
            screen.Transparency = state.screenVisible and 0 or 0.99
            screen.Position = char.HumanoidRootPart.Position + char.HumanoidRootPart.CFrame.LookVector * 7
        elseif screen:IsA("Model") then
            for _, child in pairs(screen:GetChildren()) do
                if child:IsA("BasePart") then
                    child.Size = Vector3.new(3, 3, 3)
                    child.CanCollide = true
                    child.Transparency = state.screenVisible and 0 or 0.99
                end
            end
            screen:SetPrimaryPartCFrame(CFrame.new(char.HumanoidRootPart.Position + char.HumanoidRootPart.CFrame.LookVector * 7))
        end
    end
end

if screen then
    state.screenConnection = RunService.Heartbeat:Connect(updateScreenPosition)
    table.insert(connections, state.screenConnection)
end

-- Update character on respawn
local function onCharacterAdded(newCharacter)
    char = newCharacter
    humanoid = char:WaitForChild("Humanoid")
    rootPart = char:WaitForChild("HumanoidRootPart")
    
    if state.speedEnabled then
        humanoid.WalkSpeed = state.walkSpeed
    end
    if state.isFlying then
        startFlying()
    end
    if state.cframeSpeedEnabled then
        toggleCFrameSpeed(true)
    end
    if state.followEnabled and state.followTargetPlayer then
        toggleFollow(state.followTargetPlayer.Name)
    end
    humanoid.Died:Connect(function()
        state.deathPosition = rootPart.Position
        if state.teleportOnDeathEnabled then
            task.spawn(function()
                task.wait(0.1)
                if char and char:FindFirstChild("HumanoidRootPart") then
                    char.HumanoidRootPart.CFrame = CFrame.new(state.deathPosition)
                end
            end)
        end
    end)
    -- Reinitialize screen connection on character respawn
    if state.screenConnection then
        state.screenConnection:Disconnect()
    end
    if screen then
        state.screenConnection = RunService.Heartbeat:Connect(updateScreenPosition)
        table.insert(connections, state.screenConnection)
    end
end
player.CharacterAdded:Connect(onCharacterAdded)

-- Utility functions
local function toggleScreenVisibility()
    state.screenVisible = not state.screenVisible
    local transparencyValue = state.screenVisible and 0 or 0.99
    if screen then
        if screen:IsA("BasePart") then
            screen.Transparency = transparencyValue
        elseif screen:IsA("Model") then
            for _, child in pairs(screen:GetChildren()) do
                if child:IsA("BasePart") then
                    child.Transparency = transparencyValue
                end
            end
        end
    end
    local settingsFrame = tabFrames.Settings
    if settingsFrame:FindFirstChild("ScreenVisibilityContainer") then
        settingsFrame.ScreenVisibilityContainer.ScreenVisibilityToggle.Text = state.screenVisible and "On" or "Off"
    end
end

local function startFlying()
    if state.isFlying or not char or not char:FindFirstChild("HumanoidRootPart") or not char:FindFirstChild("Humanoid") then return end
    state.isFlying = true
    
    -- Clean up existing flight objects
    if state.bodyVelocity then state.bodyVelocity:Destroy() end
    if state.bodyGyro then state.bodyGyro:Destroy() end
    if state.flightConnection then state.flightConnection:Disconnect() end
    
    -- Create new BodyVelocity
    state.bodyVelocity = Instance.new("BodyVelocity")
    state.bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    state.bodyVelocity.Velocity = Vector3.new(0, 0, 0)
    state.bodyVelocity.Parent = rootPart
    
    -- Create new BodyGyro
    state.bodyGyro = Instance.new("BodyGyro")
    state.bodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    state.bodyGyro.CFrame = Camera.CFrame
    state.bodyGyro.Parent = rootPart
    
    humanoid.PlatformStand = true
    
    -- Flight logic
    state.flightConnection = RunService.RenderStepped:Connect(function()
        if state.isFlying and char and char:FindFirstChild("HumanoidRootPart") and char:FindFirstChild("Humanoid") then
            local moveDirection = Vector3.new(0, 0, 0)
            local camCFrame = Camera.CFrame
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then
                moveDirection = moveDirection + camCFrame.LookVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then
                moveDirection = moveDirection - camCFrame.LookVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then
                moveDirection = moveDirection - camCFrame.RightVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then
                moveDirection = moveDirection + camCFrame.RightVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                moveDirection = moveDirection + Vector3.new(0, 1, 0)
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
                moveDirection = moveDirection - Vector3.new(0, 1, 0)
            end
            if moveDirection.Magnitude > 0 then
                state.bodyVelocity.Velocity = moveDirection.Unit * state.flySpeed
                state.bodyGyro.CFrame = CFrame.new(Vector3.new(0, 0, 0), moveDirection.Unit)
            else
                state.bodyVelocity.Velocity = Vector3.new(0, 0, 0)
            end
        else
            stopFlying()
        end
    end)
    table.insert(connections, state.flightConnection)
end

local function stopFlying()
    if not state.isFlying then return end
    state.isFlying = false
    if state.bodyVelocity then state.bodyVelocity:Destroy() state.bodyVelocity = nil end
    if state.bodyGyro then state.bodyGyro:Destroy() state.bodyGyro = nil end
    if state.flightConnection then state.flightConnection:Disconnect() state.flightConnection = nil end
    if char and char:FindFirstChild("Humanoid") then
        char.Humanoid.PlatformStand = false
    end
end

local function createPart()
    if char and char:FindFirstChild("HumanoidRootPart") and char:FindFirstChild("Humanoid") then
        local root = char.HumanoidRootPart
        local humanoid = char.Humanoid
        local offset = root.CFrame.LookVector * state.spawnDistance
        local part = Instance.new("Part")
        part.Name = "GeneratedPart"
        part.Size = Vector3.new(5, 1, 5)
        part.Position = root.Position + offset - Vector3.new(0, root.Size.Y / 2 + humanoid.HipHeight + part.Size.Y / 2, 0)
        part.Anchored = true
        part.BrickColor = BrickColor.new("Bright red")
        part.Parent = Workspace
    end
end

local function createDirectionPart()
    if char and char:FindFirstChild("HumanoidRootPart") and char:FindFirstChild("Humanoid") then
        if state.directionPart then
            state.directionPart:Destroy()
            state.directionPart = nil
        end
        local root = char.HumanoidRootPart
        local humanoid = char.Humanoid
        local yPosition = root.Position.Y - (root.Size.Y / 2 + humanoid.HipHeight + state.directionPartSize.Y / 2)
        state.directionPart = Instance.new("Part")
        state.directionPart.Name = "DirectionPart"
        state.directionPart.Size = state.directionPartSize
        state.directionPart.Position = Vector3.new(root.Position.X, yPosition, root.Position.Z)
        state.directionPart.BrickColor = state.directionPartColor
        state.directionPart.Transparency = state.directionPartTransparency
        state.directionPart.CanCollide = state.directionPartCanCollide
        state.directionPart.Anchored = state.directionPartAnchored
        state.directionPart.Parent = Workspace
    end
end

local function toggleUnderFeetPart()
    if char and char:FindFirstChild("HumanoidRootPart") and char:FindFirstChild("Humanoid") then
        if not state.underFeetPart then
            local root = char.HumanoidRootPart
            local humanoid = char.Humanoid
            state.underFeetPart = Instance.new("Part")
            state.underFeetPart.Name = "UnderFeetPart"
            state.underFeetPart.Size = Vector3.new(5, 1, 5)
            local initialY = root.Position.Y - (root.Size.Y / 2 + humanoid.HipHeight + state.underFeetPart.Size.Y / 2)
            state.underFeetPart.Position = Vector3.new(root.Position.X, initialY, root.Position.Z)
            state.underFeetPart.Anchored = true
            state.underFeetPart.BrickColor = BrickColor.new("Bright green")
            state.underFeetPart.Parent = Workspace
            state.renderConnection = RunService.RenderStepped:Connect(function()
                if state.underFeetPart and char and char:FindFirstChild("HumanoidRootPart") then
                    local rootPos = char.HumanoidRootPart.Position
                    state.underFeetPart.Position = Vector3.new(rootPos.X, initialY, rootPos.Z)
                end
            end)
            table.insert(connections, state.renderConnection)
        else
            if state.renderConnection then
                state.renderConnection:Disconnect()
                state.renderConnection = nil
            end
            if state.underFeetPart then
                state.underFeetPart:Destroy()
                state.underFeetPart = nil
            end
        end
    end
end

local function deleteAllParts()
    local partsDeleted = 0
    for _, child in ipairs(Workspace:GetChildren()) do
        if child:IsA("Part") and (child.Name == "GeneratedPart" or child.Name == "UnderFeetPart" or child.Name == "DirectionPart") then
            child:Destroy()
            partsDeleted = partsDeleted + 1
        end
    end
    state.directionPart = nil
    state.underFeetPart = nil
    if state.renderConnection then
        state.renderConnection:Disconnect()
        state.renderConnection = nil
    end
end

local function toggleFollow(targetName)
    local newTarget = Players:FindFirstChild(targetName)
    if newTarget and newTarget.Character and newTarget.Character:FindFirstChild("HumanoidRootPart") and newTarget ~= player then
        state.followTargetPlayer = newTarget
        state.followEnabled = not state.followEnabled
        if state.followEnabled then
            if state.followConnection then state.followConnection:Disconnect() end
            state.followConnection = RunService.RenderStepped:Connect(function()
                if state.followTargetPlayer and state.followTargetPlayer.Character and state.followTargetPlayer.Character:FindFirstChild("HumanoidRootPart") and char and char:FindFirstChild("HumanoidRootPart") then
                    local targetRoot = state.followTargetPlayer.Character.HumanoidRootPart
                    local targetPos = targetRoot.Position
                    local playerPos = char.HumanoidRootPart.Position
                    local directionToTarget = (targetPos - playerPos).Unit
                    local followPos = targetPos - directionToTarget * state.followDistance
                    followPos = Vector3.new(followPos.X, playerPos.Y, followPos.Z)
                    char.HumanoidRootPart.CFrame = CFrame.new(followPos, targetPos)
                else
                    state.followEnabled = false
                    if state.followConnection then state.followConnection:Disconnect() state.followConnection = nil end
                    state.followTargetPlayer = nil
                    -- Reinitialize screen connection when follow is disabled
                    if state.screenConnection then
                        state.screenConnection:Disconnect()
                    end
                    if screen then
                        state.screenConnection = RunService.Heartbeat:Connect(updateScreenPosition)
                        table.insert(connections, state.screenConnection)
                    end
                end
            end)
            table.insert(connections, state.followConnection)
            -- Pause screen movement while following
            if state.screenConnection then
                state.screenConnection:Disconnect()
                state.screenConnection = nil
            end
        else
            if state.followConnection then state.followConnection:Disconnect() state.followConnection = nil end
            state.followTargetPlayer = nil
            -- Reinitialize screen connection when follow is disabled
            if state.screenConnection then
                state.screenConnection:Disconnect()
            end
            if screen then
                state.screenConnection = RunService.Heartbeat:Connect(updateScreenPosition)
                table.insert(connections, state.screenConnection)
            end
        end
    end
end

local function toggleCFrameSpeed(enabled)
    state.cframeSpeedEnabled = enabled
    if enabled then
        if state.cframeConnection then state.cframeConnection:Disconnect() end
        state.cframeConnection = RunService.Heartbeat:Connect(function(step)
            if char and char:FindFirstChild("HumanoidRootPart") and humanoid.MoveDirection.Magnitude > 0 then
                char.HumanoidRootPart.CFrame = char.HumanoidRootPart.CFrame + humanoid.MoveDirection * state.cframeSpeed * step
            end
        end)
        table.insert(connections, state.cframeConnection)
    else
        if state.cframeConnection then
            state.cframeConnection:Disconnect()
            state.cframeConnection = nil
        end
    end
end

local function deleteAll()
    stopFlying()
    deleteAllParts()
    if state.cframeConnection then state.cframeConnection:Disconnect() state.cframeConnection = nil end
    if state.flightConnection then state.flightConnection:Disconnect() state.flightConnection = nil end
    if state.followConnection then state.followConnection:Disconnect() state.followConnection = nil end
    if state.screenConnection then state.screenConnection:Disconnect() state.screenConnection = nil end
    state.followEnabled = false
    state.followTargetPlayer = nil
    humanoid.PlatformStand = false
    Camera.CameraSubject = char and char.Humanoid or nil
    if screenGui then
        screenGui:Destroy()
        screenGui = nil
    end
    for _, connection in ipairs(connections) do
        connection:Disconnect()
    end
    connections = {}
    local settings = ReplicatedStorage:FindFirstChild("Settings")
    if settings then
        local cooldowns = settings:FindFirstChild("Cooldowns")
        if cooldowns then
            if cooldowns:FindFirstChild("Dash") then cooldowns.Dash.Value = 100 end
            if cooldowns:FindFirstChild("Melee") then cooldowns.Melee.Value = 100 end
            if cooldowns:FindFirstChild("WallCombo") then cooldowns.WallCombo.Value = 100 end
        end
        local multipliers = settings:FindFirstChild("Multipliers")
        if multipliers then
            if multipliers:FindFirstChild("DashSpeed") then multipliers.DashSpeed.Value = 100 end
            if multipliers:FindFirstChild("MeleeSpeed") then multipliers.MeleeSpeed.Value = 100 end
            if multipliers:FindFirstChild("RagdollTimer") then multipliers.RagdollTimer.Value = 100 end
            if multipliers:FindFirstChild("RagdollPower") then multipliers.RagdollPower.Value = 100 end
        end
        local toggles = settings:FindFirstChild("Toggles")
        if toggles then
            if toggles:FindFirstChild("InstantTransformation") then toggles.InstantTransformation.Value = false end
            if toggles:FindFirstChild("NoSlowdowns") then toggles.NoSlowdowns.Value = false end
            if toggles:FindFirstChild("NoStunOnMiss") then toggles.NoStunOnMiss.Value = false end
            if toggles:FindFirstChild("DisableFinishers") then toggles.DisableFinishers.Value = false end
            if toggles:FindFirstChild("DisableHitStun") then toggles.DisableHitStun.Value = false end
            if toggles:FindFirstChild("NoJumpFatigue") then toggles.NoJumpFatigue.Value = false end
            if toggles:FindFirstChild("DisableCombatTimer") then toggles.DisableCombatTimer.Value = false end
            if toggles:FindFirstChild("DisableBlocking") then toggles.DisableBlocking.Value = false end
        end
    end
end

local function toggleCooldown(name, enabled)
    local settings = ReplicatedStorage:FindFirstChild("Settings")
    if settings and settings:FindFirstChild("Cooldowns") then
        local cooldown = settings.Cooldowns:FindFirstChild(name)
        if cooldown then
            cooldown.Value = enabled and 0 or 100
        end
    end
end

local function toggleSetting(name, enabled)
    local settings = ReplicatedStorage:FindFirstChild("Settings")
    if settings and settings:FindFirstChild("Toggles") then
        local toggle = settings.Toggles:FindFirstChild(name)
        if toggle then
            toggle.Value = enabled
        end
    end
end

local function updateMultiplier(name, value)
    local settings = ReplicatedStorage:FindFirstChild("Settings")
    if settings and settings:FindFirstChild("Multipliers") then
        local multiplier = settings.Multipliers:FindFirstChild(name)
        if multiplier then
            multiplier.Value = value
        end
    end
end

-- Create ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ExecHubGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui
screenGui.Enabled = state.guiVisible

-- Main Frame
local frame = Instance.new("Frame")
frame.Name = "MainFrame"
frame.Size = UDim2.new(0, 450, 0, 640)
frame.Position = UDim2.new(0.5, -225, 0.5, -320)
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
frame.BackgroundTransparency = 0
frame.BorderSizePixel = 0
frame.Active = true
frame.Visible = state.guiVisible
frame.Parent = screenGui

local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, 12)
uiCorner.Parent = frame

local uiGradient = Instance.new("UIGradient")
uiGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 30, 50)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(50, 50, 80))
})
uiGradient.Rotation = 45
uiGradient.Parent = frame

local uiStroke = Instance.new("UIStroke")
uiStroke.Color = Color3.fromRGB(80, 80, 120)
uiStroke.Thickness = 2
uiStroke.Parent = frame

-- Drag Bar
local dragBar = Instance.new("Frame")
dragBar.Name = "DragBar"
dragBar.Size = UDim2.new(1, 0, 0, 40)
dragBar.BackgroundColor3 = Color3.fromRGB(20, 20, 40)
dragBar.BackgroundTransparency = 0.1
dragBar.BorderSizePixel = 0
dragBar.Active = true
dragBar.Parent = frame

local dragCorner = Instance.new("UICorner")
dragCorner.CornerRadius = UDim.new(0, 12)
dragCorner.Parent = dragBar

local dragLabel = Instance.new("TextLabel")
dragLabel.Size = UDim2.new(1, -60, 1, 0)
dragLabel.Position = UDim2.new(0, 15, 0, 0)
dragLabel.BackgroundTransparency = 1
dragLabel.Text = "Exec Hub"
dragLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
dragLabel.TextSize = 20
dragLabel.Font = Enum.Font.SourceSansBold
dragLabel.TextXAlignment = Enum.TextXAlignment.Left
dragLabel.Parent = dragBar

local dragStroke = Instance.new("UIStroke")
dragStroke.Color = Color3.fromRGB(100, 100, 140)
dragStroke.Thickness = 1
dragStroke.Parent = dragBar

-- Close Button
local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(0, 30, 0, 30)
closeButton.Position = UDim2.new(1, -35, 0, 5)
closeButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
closeButton.Text = "X"
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.TextSize = 16
closeButton.Font = Enum.Font.SourceSansBold
closeButton.Parent = dragBar

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 8)
closeCorner.Parent = closeButton

local closeStroke = Instance.new("UIStroke")
closeStroke.Color = Color3.fromRGB(255, 100, 100)
closeStroke.Thickness = 1
closeStroke.Parent = closeButton

-- Tabs Frame
local tabsFrame = Instance.new("Frame")
tabsFrame.Name = "TabsFrame"
tabsFrame.Size = UDim2.new(0, 120, 1, -50)
tabsFrame.Position = UDim2.new(0, 5, 0, 45)
tabsFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
tabsFrame.BackgroundTransparency = 0.1
tabsFrame.Parent = frame

local tabsGradient = Instance.new("UIGradient")
tabsGradient.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0.2),
    NumberSequenceKeypoint.new(1, 0.9)
})
tabsGradient.Parent = tabsFrame

local tabsCorner = Instance.new("UICorner")
tabsCorner.CornerRadius = UDim.new(0, 8)
tabsCorner.Parent = tabsFrame

local tabsStroke = Instance.new("UIStroke")
tabsStroke.Color = Color3.fromRGB(100, 100, 140)
tabsStroke.Thickness = 1
tabsStroke.Parent = tabsFrame

local tabNames = {"Main", "Movement", "Parts", "Follow", "Cooldowns", "Multipliers", "Binds", "Settings"}
local tabFrames = {}
local currentTab = nil

-- Helper function to create simple buttons
local function createSimpleButton(name, positionY, color, text, parent, callback)
    local button = Instance.new("TextButton")
    button.Name = name
    button.Size = UDim2.new(0, 310, 0, 35)
    button.Position = UDim2.new(-0.37, 125, 0, positionY)
    button.BackgroundColor3 = color
    button.BackgroundTransparency = 0.1
    button.Text = text
    button.TextColor3 = Color3.fromRGB(220, 220, 220)
    button.TextSize = 16
    button.Font = Enum.Font.SourceSansBold
    button.Parent = parent 

    button.MouseEnter:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.2), {
            Size = UDim2.new(0, 312, 0, 37),
            BackgroundColor3 = Color3.fromRGB(math.min(color.R * 255 + 20, 255), math.min(color.G * 255 + 20, 255), math.min(color.B * 255 + 20, 255))
        }):Play()
        TweenService:Create(buttonStroke, TweenInfo.new(0.2), {Color = Color3.fromRGB(150, 150, 180)}):Play()
    end)

    button.MouseLeave:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.2), {
            Size = UDim2.new(0, 310, 0, 35),
            BackgroundColor3 = color
        }):Play()
        TweenService:Create(buttonStroke, TweenInfo.new(0.2), {Color = Color3.fromRGB(100, 100, 140)}):Play()
    end)

    button.MouseButton1Click:Connect(callback)
    return button
end

-- Helper function to create toggle buttons
local function createToggleButton(name, positionY, color, text, parent, stateKey, defaultState, folder, path, callback)
    local container = Instance.new("Frame")
    container.Name = name .. "Container"
    container.Size = UDim2.new(0, 310, 0, 35)
    container.Position = UDim2.new(-0.37, 125, 0, positionY)
    container.BackgroundTransparency = 1
    container.Parent = parent

    local label = Instance.new("TextLabel")
    label.Name = name .. "Label"
    label.Size = UDim2.new(0, 250, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(220, 220, 220)
    label.TextSize = 16
    label.Font = Enum.Font.SourceSansBold
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = container

    local toggle = Instance.new("TextButton")
    toggle.Name = name .. "Toggle"
    toggle.Size = UDim2.new(0, 40, 0, 30)
    toggle.Position = UDim2.new(1, -40, 0, 2.5)
    toggle.BackgroundColor3 = defaultState and Color3.fromRGB(0, 200, 0) or Color3.fromRGB(200, 50, 50)
    toggle.BackgroundTransparency = 0.1
    toggle.Text = defaultState and "On" or "Off"
    toggle.TextColor3 = Color3.fromRGB(220, 220, 220)
    toggle.TextSize = 14
    toggle.Font = Enum.Font.Arial
    toggle.Parent = container

    local toggleCorner = Instance.new("UICorner")
    toggleCorner.CornerRadius = UDim.new(0, 8)
    toggleCorner.Parent = toggle

    local toggleStroke = Instance.new("UIStroke")
    toggleStroke.Color = Color3.fromRGB(100, 100, 140)
    toggleStroke.Thickness = 1
    toggleStroke.Parent = toggle

    toggle.MouseEnter:Connect(function()
        TweenService:Create(toggle, TweenInfo.new(0.2), {
            Size = UDim2.new(0, 42, 0, 32),
            BackgroundColor3 = state[stateKey] and Color3.fromRGB(0, 220, 0) or Color3.fromRGB(220, 50, 50)
        }):Play()
        TweenService:Create(toggleStroke, TweenInfo.new(0.2), {Color = Color3.fromRGB(150, 150, 180)}):Play()
    end)

    toggle.MouseLeave:Connect(function()
        TweenService:Create(toggle, TweenInfo.new(0.2), {
            Size = UDim2.new(0, 40, 0, 30),
            BackgroundColor3 = state[stateKey] and Color3.fromRGB(0, 200, 0) or Color3.fromRGB(200, 50, 50)
        }):Play()
        TweenService:Create(toggleStroke, TweenInfo.new(0.2), {Color = Color3.fromRGB(100, 100, 140)}):Play()
    end)

    toggle.MouseButton1Click:Connect(function()
        state[stateKey] = not state[stateKey]
        toggle.Text = state[stateKey] and "On" or "Off"
        toggle.BackgroundColor3 = state[stateKey] and Color3.fromRGB(0, 200, 0) or Color3.fromRGB(200, 50, 50)
        if folder == "Cooldowns" then
            toggleCooldown(path, state[stateKey])
        elseif folder == "Toggles" then
            toggleSetting(path, state[stateKey])
        end
        if callback then
            callback(state[stateKey])
        end
    end)

    return container, toggle
end

-- Helper function to create sliders with label and input
local function createSliderLabel(name, positionY, defaultValue, parent, stateKey, minValue, maxValue, multiplierPath)
    local container = Instance.new("Frame")
    container.Name = name .. "Container"
    container.Size = UDim2.new(0, 310, 0, 70)
    container.Position = UDim2.new(-0.37, 125, 0, positionY)
    container.BackgroundTransparency = 1
    container.Parent = parent

    local label = Instance.new("TextLabel")
    label.Name = name .. "Label"
    label.Size = UDim2.new(0, 310, 0, 35)
    label.BackgroundTransparency = 1
    label.Text = name .. ": " .. defaultValue
    label.TextColor3 = Color3.fromRGB(220, 220, 220)
    label.TextSize = 16
    label.Font = Enum.Font.SourceSansBold
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = container

    local input = Instance.new("TextBox")
    input.Name = name .. "Input"
    input.Size = UDim2.new(0, 60, 0, 25)
    input.Position = UDim2.new(1, -70, 0, 0)
    input.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
    input.BackgroundTransparency = 0.1
    input.Text = tostring(defaultValue)
    input.TextColor3 = Color3.fromRGB(220, 220, 220)
    input.TextSize = 14
    input.Font = Enum.Font.Arial
    input.Parent = container

    local inputCorner = Instance.new("UICorner")
    inputCorner.CornerRadius = UDim.new(0, 8)
    inputCorner.Parent = input

    local inputStroke = Instance.new("UIStroke")
    inputStroke.Color = Color3.fromRGB(100, 100, 140)
    inputStroke.Thickness = 1
    inputStroke.Parent = input

    local sliderFrame = Instance.new("Frame")
    sliderFrame.Name = name .. "SliderFrame"
    sliderFrame.Size = UDim2.new(0, 310, 0, 25)
    sliderFrame.Position = UDim2.new(0, 0, 0, 40)
    sliderFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
    sliderFrame.BackgroundTransparency = 0.1
    sliderFrame.Parent = container

    local sliderCorner = Instance.new("UICorner")
    sliderCorner.CornerRadius = UDim.new(0, 8)
    sliderCorner.Parent = sliderFrame

    local sliderBar = Instance.new("Frame")
    sliderBar.Name = "SliderBar"
    sliderBar.Size = UDim2.new(1, 0, 0, 6)
    sliderBar.Position = UDim2.new(0, 0, 0.5, -3)
    sliderBar.BackgroundColor3 = Color3.fromRGB(100, 100, 140)
    sliderBar.Parent = sliderFrame

    local sliderKnob = Instance.new("Frame")
    sliderKnob.Name = "SliderKnob"
    sliderKnob.Size = UDim2.new(0, 20, 0, 20)
    sliderKnob.Position = UDim2.new((defaultValue - minValue) / (maxValue - minValue), -10, 0, 2.5)
    sliderKnob.BackgroundColor3 = Color3.fromRGB(0, 200, 0)
    sliderKnob.Parent = sliderFrame

    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(0, 10)
    knobCorner.Parent = sliderKnob

    local knobStroke = Instance.new("UIStroke")
    knobStroke.Color = Color3.fromRGB(100, 100, 140)
    knobStroke.Thickness = 1
    knobStroke.Parent = sliderKnob

    local draggingSlider = false
    sliderKnob.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            draggingSlider = true
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if draggingSlider and input.UserInputType == Enum.UserInputType.MouseMovement then
            local mouseX = input.Position.X
            local sliderPos = sliderFrame.AbsolutePosition.X
            local sliderWidth = sliderFrame.AbsoluteSize.X
            local relativeX = math.clamp((mouseX - sliderPos) / sliderWidth, 0, 1)
            local newValue = minValue + relativeX * (maxValue - minValue)
            newValue = math.floor(newValue + 0.5)
            state[stateKey] = newValue
            sliderKnob.Position = UDim2.new(relativeX, -10, 0, 2.5)
            label.Text = name .. ": " .. newValue
            input.Text = tostring(newValue)
            if multiplierPath then
                updateMultiplier(multiplierPath, newValue)
            end
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            draggingSlider = false
        end
    end)

    input.FocusLost:Connect(function()
        local newValue = tonumber(input.Text)
        if newValue then
            newValue = math.clamp(math.floor(newValue + 0.5), minValue, maxValue)
            state[stateKey] = newValue
            sliderKnob.Position = UDim2.new((newValue - minValue) / (maxValue - minValue), -10, 0, 2.5)
            label.Text = name .. ": " .. newValue
            input.Text = tostring(newValue)
            if multiplierPath then
                updateMultiplier(multiplierPath, newValue)
            end
        else
            input.Text = tostring(state[stateKey])
        end
    end)

    return container
end

-- Helper function to create property inputs
local function createPropertyInput(labelName, inputName, positionY, defaultValue, parent, callback)
    local container = Instance.new("Frame")
    container.Name = inputName .. "Container"
    container.Size = UDim2.new(0, 310, 0, 55)
    container.Position = UDim2.new(-0.37, 125, 0, positionY)
    container.BackgroundTransparency = 1
    container.Parent = parent

    local label = Instance.new("TextLabel")
    label.Name = labelName
    label.Size = UDim2.new(0, 310, 0, 20)
    label.BackgroundTransparency = 1
    label.Text = labelName .. ": " .. defaultValue
    label.TextColor3 = Color3.fromRGB(220, 220, 220)
    label.TextSize = 14
    label.Font = Enum.Font.SourceSansBold
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = container

    local input = Instance.new("TextBox")
    input.Name = inputName
    input.Size = UDim2.new(0, 310, 0, 30)
    input.Position = UDim2.new(0, 0, 0, 25)
    input.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
    input.BackgroundTransparency = 0.1
    input.Text = tostring(defaultValue)
    input.TextColor3 = Color3.fromRGB(220, 220, 220)
    input.TextSize = 14
    input.Font = Enum.Font.Arial
    input.Parent = container

    local inputCorner = Instance.new("UICorner")
    inputCorner.CornerRadius = UDim.new(0, 8)
    inputCorner.Parent = input

    local inputStroke = Instance.new("UIStroke")
    inputStroke.Color = Color3.fromRGB(100, 100, 140)
    inputStroke.Thickness = 1
    inputStroke.Parent = input

    input.FocusLost:Connect(function()
        callback(input.Text, label)
    end)

    return container
end

-- Create Tabs
for i, tabName in ipairs(tabNames) do
    local tabButton = Instance.new("TextButton")
    tabButton.Name = tabName .. "Tab"
    tabButton.Size = UDim2.new(0, 110, 0, 40)
    tabButton.Position = UDim2.new(0, 5, 0, (i-1) * 45 + 10)
    tabButton.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
    tabButton.BackgroundTransparency = 0.1
    tabButton.Text = tabName
    tabButton.TextColor3 = Color3.fromRGB(220, 220, 220)
    tabButton.TextSize = 14
    tabButton.Font = Enum.Font.Arial
    tabButton.Parent = tabsFrame

    local tabCorner = Instance.new("UICorner")
    tabCorner.CornerRadius = UDim.new(0, 8)
    tabCorner.Parent = tabButton

    local tabStroke = Instance.new("UIStroke")
    tabStroke.Color = Color3.fromRGB(100, 100, 140)
    tabStroke.Thickness = 1
    tabStroke.Parent = tabButton

    local tabFrame = Instance.new("Frame")
    tabFrame.Name = tabName .. "Frame"
    tabFrame.Size = UDim2.new(0, 315, 1, -90)
    tabFrame.Position = UDim2.new(0, 125, 0, 50)
    tabFrame.BackgroundTransparency = 1
    tabFrame.Visible = false
    tabFrame.Parent = frame
    tabFrames[tabName] = tabFrame

    tabButton.MouseEnter:Connect(function()
        if currentTab ~= tabName then
            TweenService:Create(tabButton, TweenInfo.new(0.2), {
                BackgroundColor3 = Color3.fromRGB(80, 80, 100),
                Size = UDim2.new(0, 112, 0, 42)
            }):Play()
            TweenService:Create(tabStroke, TweenInfo.new(0.2), {Color = Color3.fromRGB(150, 150, 180)}):Play()
        end
    end)

    tabButton.MouseLeave:Connect(function()
        if currentTab ~= tabName then
            TweenService:Create(tabButton, TweenInfo.new(0.2), {
                BackgroundColor3 = Color3.fromRGB(60, 60, 80),
                Size = UDim2.new(0, 110, 0, 40)
            }):Play()
            TweenService:Create(tabStroke, TweenInfo.new(0.2), {Color = Color3.fromRGB(100, 100, 140)}):Play()
        end
    end)

    tabButton.MouseButton1Click:Connect(function()
        if currentTab ~= tabName then
            if currentTab then
                tabFrames[currentTab].Visible = false
                local prevTab = tabsFrame:FindFirstChild(currentTab .. "Tab")
                if prevTab then
                    TweenService:Create(prevTab, TweenInfo.new(0.2), {
                        BackgroundColor3 = Color3.fromRGB(60, 60, 80),
                        Size = UDim2.new(0, 110, 0, 40)
                    }):Play()
                    TweenService:Create(prevTab.UIStroke, TweenInfo.new(0.2), {Color = Color3.fromRGB(100, 100, 140)}):Play()
                end
            end
            currentTab = tabName
            tabFrame.Visible = true
            TweenService:Create(tabButton, TweenInfo.new(0.2), {
                BackgroundColor3 = Color3.fromRGB(100, 100, 255),
                Size = UDim2.new(0, 112, 0, 42)
            }):Play()
            TweenService:Create(tabStroke, TweenInfo.new(0.2), {Color = Color3.fromRGB(150, 150, 255)}):Play()
        end
    end)
end

-- Main Tab
local mainFrame = tabFrames.Main
createSimpleButton("SpawnPart", 10, Color3.fromRGB(100, 100, 255), "Spawn Part (" .. state.boundKeyPartSpawn.Name .. ")", mainFrame, createPart)
createSimpleButton("Float", 55, Color3.fromRGB(0, 200, 0), "Float (" .. state.boundKeyFloat.Name .. ")", mainFrame, function()
    toggleUnderFeetPart()
    mainFrame.Float.Text = "Float (" .. state.boundKeyFloat.Name .. ")"
end)
createSimpleButton("DirectionPart", 100, Color3.fromRGB(255, 100, 100), "Direction Part (" .. state.boundKeyDirection.Name .. ")", mainFrame, createDirectionPart)
createSimpleButton("DeleteAllParts", 145, Color3.fromRGB(200, 50, 50), "Delete All Parts", mainFrame, deleteAllParts)

-- Movement Tab
local movementFrame = tabFrames.Movement
createToggleButton("Flight", 10, Color3.fromRGB(100, 100, 255), "Flight (" .. state.boundKeyFly.Name .. ")", movementFrame, "isFlying", false, "Movement", "Flight", function(enabled)
    if enabled then startFlying() else stopFlying() end
    movementFrame.FlightContainer.FlightToggle.Text = enabled and "On" or "Off"
end)
createSliderLabel("Flight Speed", 55, state.flySpeed, movementFrame, "flySpeed", 0, 200, "FlightSpeed")
createToggleButton("CFrameSpeed", 135, Color3.fromRGB(100, 100, 255), "CFrame Speed (" .. state.boundKeyCFrameSpeed.Name .. ")", movementFrame, "cframeSpeedEnabled", false, "Movement", "CFrameSpeed", function(enabled)
    toggleCFrameSpeed(enabled)
    movementFrame.CFrameSpeedContainer.CFrameSpeedToggle.Text = enabled and "On" or "Off"
end)
createSliderLabel("CFrame Speed", 180, state.cframeSpeed, movementFrame, "cframeSpeed", 0, 40, "CFrameSpeedValue")

-- Parts Tab
local partsFrame = tabFrames.Parts
local function updateDirectionPartProperties()
    if state.directionPart then
        local newSizeX = tonumber(partsFrame.SizeXInputContainer.SizeXInput.Text) or state.directionPartSize.X
        local newSizeY = tonumber(partsFrame.SizeYInputContainer.SizeYInput.Text) or state.directionPartSize.Y
        local newSizeZ = tonumber(partsFrame.SizeZInputContainer.SizeZInput.Text) or state.directionPartSize.Z
        state.directionPartSize = Vector3.new(newSizeX, newSizeY, newSizeZ)
        state.directionPart.Size = state.directionPartSize
        partsFrame.SizeXInputContainer.SizeX.Text = "Size X: " .. newSizeX
        partsFrame.SizeYInputContainer.SizeY.Text = "Size Y: " .. newSizeY
        partsFrame.SizeZInputContainer.SizeZ.Text = "Size Z: " .. newSizeZ

        local newColor = BrickColor.new(partsFrame.ColorInputContainer.ColorInput.Text)
        if newColor then
            state.directionPartColor = newColor
            state.directionPart.BrickColor = state.directionPartColor
            partsFrame.ColorInputContainer.Color.Text = "Color: " .. partsFrame.ColorInputContainer.ColorInput.Text
        end
    end
end

createPropertyInput("Size X", "SizeXInput", 0, 5, partsFrame, function(text, label)
    local value = tonumber(text) or state.directionPartSize.X
    state.directionPartSize = Vector3.new(value, state.directionPartSize.Y, state.directionPartSize.Z)
    label.Text = "Size X: " .. value
    updateDirectionPartProperties()
end)
createPropertyInput("Size Y", "SizeYInput", 65, 1, partsFrame, function(text, label)
    local value = tonumber(text) or state.directionPartSize.Y
    state.directionPartSize = Vector3.new(state.directionPartSize.X, value, state.directionPartSize.Z)
    label.Text = "Size Y: " .. value
    updateDirectionPartProperties()
end)
createPropertyInput("Size Z", "SizeZInput", 130, 5, partsFrame, function(text, label)
    local value = tonumber(text) or state.directionPartSize.Z
    state.directionPartSize = Vector3.new(state.directionPartSize.X, state.directionPartSize.Y, value)
    label.Text = "Size Z: " .. value
    updateDirectionPartProperties()
end)
createPropertyInput("Color", "ColorInput", 195, "Bright red", partsFrame, function(text, label)
    local newColor = BrickColor.new(text)
    if newColor then
        state.directionPartColor = newColor
        label.Text = "Color: " .. text
        updateDirectionPartProperties()
    end
end)
createToggleButton("CanCollide", 260, Color3.fromRGB(100, 100, 255), "CanCollide", partsFrame, "directionPartCanCollide", true, "Parts", "CanCollide", function(enabled)
    if state.directionPart then
        state.directionPart.CanCollide = enabled
    end
end)
createToggleButton("Anchored", 325, Color3.fromRGB(100, 100, 255), "Anchored", partsFrame, "directionPartAnchored", true, "Parts", "Anchored", function(enabled)
    if state.directionPart then
        state.directionPart.Anchored = enabled
    end
end)

-- Follow Tab
local followFrame = tabFrames.Follow
createToggleButton("FollowToggle", 10, Color3.fromRGB(100, 100, 255), "Follow Mode", followFrame, "followEnabled", false, nil, nil, function(enabled)
    if state.followTargetPlayer then
        toggleFollow(state.followTargetPlayer.Name)
        followFrame.FollowToggleContainer.FollowToggle.Text = enabled and "On" or "Off"
    end
end)
createSimpleButton("UpdatePlayers", 55, Color3.fromRGB(0, 200, 0), "Update Players List", followFrame, function()
    for _, child in ipairs(followFrame.PlayerList:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end
    local layoutOrder = 0
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player then
            local button = Instance.new("TextButton")
            button.Size = UDim2.new(1, 0, 0, 30)
            button.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
            button.BackgroundTransparency = 0.1
            button.Text = p.Name
            button.TextColor3 = Color3.fromRGB(220, 220, 220)
            button.TextSize = 14
            button.Font = Enum.Font.Arial
            button.LayoutOrder = layoutOrder
            button.Parent = followFrame.PlayerList

            local buttonCorner = Instance.new("UICorner")
            buttonCorner.CornerRadius = UDim.new(0, 8)
            buttonCorner.Parent = button

            local buttonStroke = Instance.new("UIStroke")
            buttonStroke.Color = Color3.fromRGB(100, 100, 140)
            buttonStroke.Thickness = 1
            buttonStroke.Parent = button

            button.MouseButton1Click:Connect(function()
                state.followTargetPlayer = p
            end)

            layoutOrder = layoutOrder + 1
        end
    end
    followFrame.PlayerList.CanvasSize = UDim2.new(0, 0, 0, layoutOrder * 35)
end)

local playerListFrame = Instance.new("ScrollingFrame")
playerListFrame.Name = "PlayerList"
playerListFrame.Size = UDim2.new(0, 310, 0, 120)
playerListFrame.Position = UDim2.new(-0.37, 125, 0, 100)
playerListFrame.BackgroundTransparency = 1
playerListFrame.ScrollBarThickness = 8
playerListFrame.Parent = followFrame

local playerListLayout = Instance.new("UIListLayout")
playerListLayout.SortOrder = Enum.SortOrder.LayoutOrder
playerListLayout.Padding = UDim.new(0, 5)
playerListLayout.Parent = playerListFrame

-- Cooldowns Tab
local cooldownsFrame = tabFrames.Cooldowns
createToggleButton("NoDashCooldown", 10, Color3.fromRGB(100, 100, 255), "No Dash Cooldown", cooldownsFrame, "noDashCooldown", false, "Cooldowns", "Dash")
createToggleButton("NoMeleeCooldown", 55, Color3.fromRGB(100, 100, 255), "No Melee Cooldown", cooldownsFrame, "noMeleeCooldown", false, "Cooldowns", "Melee")
createToggleButton("NoWallComboCooldown", 100, Color3.fromRGB(100, 100, 255), "No WallCombo Cooldown", cooldownsFrame, "noWallComboCooldown", false, "Cooldowns", "WallCombo")

-- Multipliers Tab
local multipliersFrame = tabFrames.Multipliers
createSliderLabel("Dash Speed", 10, state.dashSpeedMultiplier, multipliersFrame, "dashSpeedMultiplier", 0, 200, "DashSpeed")
createSliderLabel("Melee Speed", 90, state.meleeSpeedMultiplier, multipliersFrame, "meleeSpeedMultiplier", 0, 200, "MeleeSpeed")
createSliderLabel("Ragdoll Timer", 170, state.ragdollTimerMultiplier, multipliersFrame, "ragdollTimerMultiplier", 0, 200, "RagdollTimer")

local ragdollNote = Instance.new("TextLabel")
ragdollNote.Name = "RagdollPowerNotice"
ragdollNote.Size = UDim2.new(0, 310, 0, 40)
ragdollNote.Position = UDim2.new(-900.37, 125, 0, 250)
ragdollNote.BackgroundTransparency = 1
ragdollNote.Text = "Note: RagdollPower instantly kills after 4 hits or any ragdoll"
ragdollNote.TextColor3 = Color3.fromRGB(255, 100, 100)
ragdollNote.TextSize = 12
ragdollNote.TextWrapped = true
ragdollNote.Font = Enum.Font.SourceSansBold
ragdollNote.Parent = multipliersFrame

createPropertyInput("RagdollPower Key", "RagdollPowerBind", 300, state.boundKeyRagdollPower.Name, multipliersFrame, function(text, label)
    local newKey = Enum.KeyCode[text:upper()]
    if newKey then
        state.boundKeyRagdollPower = newKey
        label.Text = "RagdollPower Key: " .. newKey.Name
    else
        label.Text = "RagdollPower Key: " .. state.boundKeyRagdollPower.Name
    end
end)

local ragdollPowerIntValue = ReplicatedStorage:WaitForChild("Settings"):WaitForChild("Multipliers"):WaitForChild("RagdollPower")
local ragdollTimerIntValue = ReplicatedStorage:WaitForChild("Settings"):WaitForChild("Multipliers"):WaitForChild("RagdollTimer")

UserInputService.InputBegan:Connect(function(input)
    if input.KeyCode == state.boundKeyRagdollPower then
        state.ragdollPowerActive = true
        ragdollPowerIntValue.Value = 2147483647
        state.originalRagdollTimer = ragdollTimerIntValue.Value
        ragdollTimerIntValue.Value = 100
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.KeyCode == state.boundKeyRagdollPower then
        state.ragdollPowerActive = false
        ragdollPowerIntValue.Value = 100
        ragdollTimerIntValue.Value = state.originalRagdollTimer
    end
end)

-- Binds Tab
local bindsFrame = tabFrames.Binds
local function createBindInput(labelName, inputName, positionY, stateKey, buttonToUpdate, parent)
    local container = createPropertyInput(labelName, inputName, positionY, state[stateKey].Name, parent, function(text, label)
        local newKey = Enum.KeyCode[text:upper()]
        if newKey then
            state[stateKey] = newKey
            label.Text = labelName .. ": " .. newKey.Name
            if buttonToUpdate and buttonToUpdate.Parent then
                buttonToUpdate.Text = buttonToUpdate.Text:match("^(.-)%(") .. "(" .. newKey.Name .. ")"
            end
            -- Обновляем текст кнопки ScreenVisibilityToggle, если она уже создана
            if stateKey == "boundKeyScreenVisibility" and settingsFrame:FindFirstChild("ScreenVisibilityContainer") and settingsFrame.ScreenVisibilityContainer:FindFirstChild("ScreenVisibilityToggle") then
                settingsFrame.ScreenVisibilityContainer.ScreenVisibilityToggle.Text = state.screenVisible and "On" or "Off"
            end
        else
            label.Text = labelName .. ": " .. state[stateKey].Name
        end
    end)
    return container
end

createBindInput("Fly Key", "FlyBindInput", 10, "boundKeyFly", movementFrame.FlightContainer.FlightToggle, bindsFrame)
createBindInput("Part Spawn Key", "PartSpawnBindInput", 75, "boundKeyPartSpawn", mainFrame.SpawnPart, bindsFrame)
createBindInput("Float Key", "FloatBindInput", 140, "boundKeyFloat", mainFrame.Float, bindsFrame)
createBindInput("Direction Part Key", "DirectionPartBindInput", 205, "boundKeyDirection", mainFrame.DirectionPart, bindsFrame)
createBindInput("Teleport Key", "TeleportBindInput", 270, "boundKeyTeleport", nil, bindsFrame)
createBindInput("Speed Key", "SpeedBindInput", 335, "boundKeySpeed", nil, bindsFrame)
createBindInput("CFrame Speed Key", "CFrameSpeedBindInput", 400, "boundKeyCFrameSpeed", movementFrame.CFrameSpeedContainer.CFrameSpeedToggle, bindsFrame)
createBindInput("Screen Visibility Key", "ScreenVisibilityBindInput", 465, "boundKeyScreenVisibility", nil, bindsFrame)

-- Settings Tab
local settingsFrame = tabFrames.Settings
createToggleButton("TeleportOnDeath", 10, Color3.fromRGB(100, 100, 255), "Teleport on Death", settingsFrame, "teleportOnDeathEnabled", false, nil, nil)
createToggleButton("ScreenVisibility", 55, Color3.fromRGB(100, 100, 255), "Screen Visibility", settingsFrame, "screenVisible", true, nil, nil, function(enabled)
    toggleScreenVisibility()
    if settingsFrame:FindFirstChild("ScreenVisibilityContainer") and settingsFrame.ScreenVisibilityContainer:FindFirstChild("ScreenVisibilityToggle") then
        settingsFrame.ScreenVisibilityContainer.ScreenVisibilityToggle.Text = enabled and "On" or "Off"
    end
end)
createSimpleButton("DeleteAll", 100, Color3.fromRGB(200, 50, 50), "Delete All and Reset", settingsFrame, deleteAll)
createSimpleButton("ToggleGui", 145, Color3.fromRGB(255, 100, 100), "Hide GUI", settingsFrame, function()
    state.guiVisible = not state.guiVisible
    frame.Visible = state.guiVisible
    settingsFrame.ToggleGui.Text = state.guiVisible and "Hide GUI" or "Show GUI"
end)
createToggleButton("InstantTransform", 190, Color3.fromRGB(100, 100, 255), "Instant Transformation", settingsFrame, "instantTransform", true, "Toggles", "InstantTransformation")
createToggleButton("NoSlowdowns", 235, Color3.fromRGB(100, 100, 255), "No Slowdowns", settingsFrame, "noSlowdowns", true, "Toggles", "NoSlowdowns")
createToggleButton("NoStunOnMiss", 280, Color3.fromRGB(100, 100, 255), "No Stun on Miss", settingsFrame, "noStunOnMiss", true, "Toggles", "NoStunOnMiss")
createToggleButton("DisableFinishers", 325, Color3.fromRGB(100, 100, 255), "Disable Finishers", settingsFrame, "disableFinishers", true, "Toggles", "DisableFinishers")
createToggleButton("DisableHitStun", 370, Color3.fromRGB(100, 100, 255), "Disable Hit Stun", settingsFrame, "disableHitStun", true, "Toggles", "DisableHitStun")
createToggleButton("NoJumpFatigue", 415, Color3.fromRGB(100, 100, 255), "No Jump Fatigue", settingsFrame, "noJumpFatigue", true, "Toggles", "NoJumpFatigue")
createToggleButton("DisableCombatTimer", 460, Color3.fromRGB(100, 100, 255), "Disable Combat Timer", settingsFrame, "disableCombatTimer", true, "Toggles", "DisableCombatTimer")
createToggleButton("DisableBlocking", 505, Color3.fromRGB(100, 100, 255), "Disable Blocking", settingsFrame, "disableBlocking", false, "Toggles", "DisableBlocking")

-- Dragging Logic
local dragging = false
local dragStart = nil
local startPos = nil

dragBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = frame.Position
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragStart
        frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)

-- Close GUI
closeButton.MouseButton1Click:Connect(function()
    state.guiVisible = false
    frame.Visible = false
    settingsFrame.ToggleGui.Text = "Show GUI"
end)

-- Input handling
UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
    if not gameProcessedEvent and input.UserInputType == Enum.UserInputType.Keyboard then
        if input.KeyCode == Enum.KeyCode.L then
            state.guiVisible = not state.guiVisible
            frame.Visible = state.guiVisible
            if settingsFrame and settingsFrame:FindFirstChild("ToggleGui") then
                settingsFrame.ToggleGui.Text = state.guiVisible and "Hide GUI" or "Show GUI"
            end
        elseif input.KeyCode == state.boundKeyFly then
            state.isFlying = not state.isFlying
            if state.isFlying then startFlying() else stopFlying() end
            if movementFrame.FlightContainer then
                movementFrame.FlightContainer.FlightToggle.Text = state.isFlying and "On" or "Off"
            end
        elseif input.KeyCode == state.boundKeyPartSpawn then
            createPart()
        elseif input.KeyCode == state.boundKeyFloat then
            toggleUnderFeetPart()
            if mainFrame.Float then
                mainFrame.Float.Text = "Float (" .. state.boundKeyFloat.Name .. ")"
            end
        elseif input.KeyCode == state.boundKeyDirection then
            createDirectionPart()
        elseif input.KeyCode == state.boundKeyTeleport then
            state.teleportOnDeathEnabled = not state.teleportOnDeathEnabled
            if settingsFrame.TeleportOnDeathContainer then
                settingsFrame.TeleportOnDeathContainer.TeleportOnDeathToggle.Text = state.teleportOnDeathEnabled and "On" or "Off"
            end
        elseif input.KeyCode == state.boundKeySpeed then
            state.speedEnabled = not state.speedEnabled
            humanoid.WalkSpeed = state.speedEnabled and state.walkSpeed or 16
        elseif input.KeyCode == state.boundKeyCFrameSpeed then
            toggleCFrameSpeed(not state.cframeSpeedEnabled)
            if movementFrame.CFrameSpeedContainer then
                movementFrame.CFrameSpeedContainer.CFrameSpeedToggle.Text = state.cframeSpeedEnabled and "On" or "Off"
            end
        elseif input.KeyCode == state.boundKeyScreenVisibility then
            toggleScreenVisibility()
            if settingsFrame:FindFirstChild("ScreenVisibilityContainer") and settingsFrame.ScreenVisibilityContainer:FindFirstChild("ScreenVisibilityToggle") then
                settingsFrame.ScreenVisibilityContainer.ScreenVisibilityToggle.Text = state.screenVisible and "On" or "Off"
            end
        end
    end
end)

-- Initialize First Tab
currentTab = "Main"
tabFrames.Main.Visible = true
tabsFrame.MainTab.BackgroundColor3 = Color3.fromRGB(100, 100, 255)
tabsFrame.MainTab.Size = UDim2.new(0, 112, 0, 42)
tabsFrame.MainTab.UIStroke.Color = Color3.fromRGB(150, 150, 255)
