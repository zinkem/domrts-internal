--[[
    Interactive Tutorial
    Guides the player through the game step by step
    Uses passive AI that builds but never attacks
]]

local Tutorial = {}

-- Import gameplay module (we'll run a modified version)
local Gameplay = require("gameplay")

-- Tutorial state
local currentStep = 1
local stepCompleted = false
local stepTimer = 0
local showingMessage = true
local messageAlpha = 1
local arrowTimer = 0
local tutorialComplete = false
local initialPeonCount = 0

-- UI colors
local UI = {
    panelBg = {0.1, 0.08, 0.06, 0.95},
    panelBorder = {0.72, 0.58, 0.26, 1},
    textGold = {1, 0.85, 0.3, 1},
    textLight = {0.95, 0.92, 0.85, 1},
    highlight = {1, 0.9, 0.3, 0.4},
    arrow = {1, 0.85, 0.2, 1},
}

-- Tutorial steps
local steps = {
    {
        message = "Welcome, Commander!\n\nThis is your Town Hall. It produces Peons who gather resources.\n\nClick on your Town Hall to select it.",
        check = function(state)
            local sel = state.selectedEntities and state.selectedEntities[1]
            return sel and sel.type == "townhall" and sel.team == state.playerTeam
        end,
        arrowTarget = "townhall",  -- Points to player's town hall
    },
    {
        message = "Good! Your Town Hall can train Peons.\n\nClick the Peon button below, or press W.",
        check = function(state)
            local th = state.townHall
            return th and th.isProducing
        end,
        arrowTarget = "bottom_panel",  -- Points to bottom panel buttons
    },
    {
        message = "A Peon is now being trained!\n\nPeons cost 400 gold. Watch the progress bar.",
        check = function(state)
            return state.peonCount and state.peonCount > initialPeonCount
        end,
        waitTime = 2,
    },
    {
        message = "Your new Peon is ready!\n\nNow let's build a Farm. Select any Peon by clicking on one.",
        check = function(state)
            local sel = state.selectedEntities and state.selectedEntities[1]
            return sel and sel.type == "peon" and sel.team == state.playerTeam
        end,
        arrowTarget = "peons",  -- Points toward peons
        allowOnly = "peon",  -- Only allow selecting peons
    },
    {
        message = "Press F to build a Farm.",
        check = function(state)
            return state.isPlacingBuilding and state.placingBuildingType == "farm"
        end,
        arrowTarget = "bottom_panel",
        lockSelection = true,  -- Don't allow selection changes
    },
    {
        message = "Move your mouse to place the Farm.\n\nGreen = valid, Red = blocked. Click to build!",
        check = function(state)
            for _, farm in ipairs(state.farms or {}) do
                if farm.team == state.playerTeam and farm.isBuilding then
                    return true
                end
            end
            return false
        end,
        lockSelection = true,  -- Busy placing building
    },
    {
        message = "The Peon is building the Farm.\n\nFarms provide +4 population. Wait for it...",
        check = function(state)
            local count = 0
            for _, farm in ipairs(state.farms or {}) do
                if farm.team == state.playerTeam and not farm.isBuilding then
                    count = count + 1
                end
            end
            return count > 1
        end,
        waitTime = 2,
        lockSelection = true,  -- Wait for building
    },
    {
        message = "Farm complete!\n\nNow build a Barracks: Select a Peon, then press B.",
        check = function(state)
            return state.isPlacingBuilding and state.placingBuildingType == "barracks"
        end,
        arrowTarget = "peons",  -- Point at peons since user needs to select one first
        allowOnly = "peon",  -- Only allow selecting peons
    },
    {
        message = "Place the Barracks near your base.",
        check = function(state)
            for _, b in ipairs(state.barracks or {}) do
                if b.team == state.playerTeam and b.isBuilding then
                    return true
                end
            end
            return false
        end,
        lockSelection = true,  -- Busy placing
    },
    {
        message = "Barracks under construction!\n\nThis lets you train Footmen. Wait for it...",
        check = function(state)
            for _, b in ipairs(state.barracks or {}) do
                if b.team == state.playerTeam and not b.isBuilding then
                    return true
                end
            end
            return false
        end,
        waitTime = 2,
        lockSelection = true,  -- Wait for building
    },
    {
        message = "Barracks ready!\n\nClick on the Barracks to select it.",
        check = function(state)
            local sel = state.selectedEntities and state.selectedEntities[1]
            return sel and sel.type == "barracks" and sel.team == state.playerTeam
        end,
        arrowTarget = "barracks",
        allowOnly = "barracks",  -- Only allow selecting barracks
    },
    {
        message = "Now train some Footmen!\n\nClick the Footman button below, or press T.",
        check = function(state)
            for _, b in ipairs(state.barracks or {}) do
                if b.team == state.playerTeam and b.isProducing then
                    return true
                end
            end
            return false
        end,
        arrowTarget = "bottom_panel",
        lockSelection = true,  -- Keep barracks selected while training
    },
    {
        message = "Training a Footman!\n\nKeep pressing T to queue more. Train at least 3 total.",
        check = function(state)
            local count = 0
            for _, f in ipairs(state.footmen or {}) do
                if f.team == state.playerTeam then
                    count = count + 1
                end
            end
            return count >= 3
        end,
        arrowTarget = "bottom_panel",
        lockSelection = true,  -- Keep barracks selected to queue
    },
    {
        message = "You have an army!\n\nDrag a box around your Footmen, or Shift+click to add more.",
        check = function(state)
            local footmenSelected = 0
            for _, sel in ipairs(state.selectedEntities or {}) do
                if sel.type == "footman" and sel.team == state.playerTeam then
                    footmenSelected = footmenSelected + 1
                end
            end
            return footmenSelected >= 2
        end,
        arrowTarget = "footmen",
        -- No restrictions - box selection is complex
    },
    {
        message = "Now for the attack!\n\nPress A, then click toward the enemy base (top-right).",
        check = function(state)
            for _, f in ipairs(state.footmen or {}) do
                if f.team == state.playerTeam and (f.state == "AttackMoving" or f.state == "Attacking") then
                    return true
                end
            end
            return false
        end,
        arrowTarget = "enemy_base",
        lockSelection = true,  -- Keep footmen selected for attack
    },
    {
        message = "Your army is attacking!\n\nDestroy all enemy buildings to win!",
        check = function(state)
            return state.victory
        end,
    },
    {
        message = "Victory!\n\nAfter each battle, you'll see a stats screen showing\nyour performance. Press ENTER to continue.",
        check = function(state)
            return false  -- Wait for player to press enter
        end,
        waitTime = 0,
        final = true,
    },
}

function Tutorial.load()
    -- Load gameplay with tutorial mode
    Gameplay.load({
        tutorialMode = true,
        aiPersonality = "passive",
        disableFog = true,
    })
    
    -- Get initial peon count
    local state = Gameplay.getTutorialState and Gameplay.getTutorialState() or {}
    initialPeonCount = state.peonCount or 7
    
    -- Reset tutorial state
    currentStep = 1
    stepCompleted = false
    stepTimer = 0
    showingMessage = true
    messageAlpha = 1
    arrowTimer = 0
    tutorialComplete = false
end

function Tutorial.update(dt)
    -- Update gameplay
    Gameplay.update(dt)
    
    arrowTimer = arrowTimer + dt
    
    -- Get game state for step checking
    local state = Gameplay.getTutorialState and Gameplay.getTutorialState() or {}
    
    -- Check current step completion
    if currentStep <= #steps and not stepCompleted then
        local step = steps[currentStep]
        if step.check and step.check(state) then
            stepCompleted = true
            stepTimer = step.waitTime or 1
        end
    end
    
    -- Handle step transition
    if stepCompleted then
        stepTimer = stepTimer - dt
        if stepTimer <= 0 then
            if steps[currentStep].final then
                tutorialComplete = true
            else
                currentStep = currentStep + 1
                stepCompleted = false
                messageAlpha = 0
            end
        end
    end
    
    -- Fade in message
    if messageAlpha < 1 then
        messageAlpha = math.min(1, messageAlpha + dt * 2)
    end
end

-- Helper function to draw an arrow pointing from (ax,ay) toward (tx,ty)
local function drawArrow(ax, ay, tx, ty)
    -- Calculate angle from arrow position to target
    local dx = tx - ax
    local dy = ty - ay
    local angle = math.atan2(dy, dx)
    
    love.graphics.push()
    love.graphics.translate(ax, ay)
    -- Arrow shape points in +Y direction (tip at y=25), so rotate to point toward target
    -- atan2 gives angle from +X axis, +Y is at pi/2, so subtract pi/2 to align
    love.graphics.rotate(angle - math.pi/2)
    
    -- Outer glow
    local glowPulse = 0.5 + math.sin(arrowTimer * 3) * 0.3
    love.graphics.setColor(1, 0.9, 0.2, 0.3 * glowPulse)
    love.graphics.polygon("fill", 0, 25, -18, -8, 18, -8)
    love.graphics.setColor(1, 0.85, 0.1, 0.5 * glowPulse)
    love.graphics.polygon("fill", 0, 20, -14, -5, 14, -5)
    
    -- Main arrow
    love.graphics.setColor(1, 0.85, 0.15, 1)
    love.graphics.polygon("fill", 0, 18, -12, -4, 12, -4)
    
    -- Bright center
    love.graphics.setColor(1, 1, 0.6, 1)
    love.graphics.polygon("fill", 0, 12, -6, 0, 6, 0)
    
    -- Outline
    love.graphics.setColor(0.6, 0.4, 0, 1)
    love.graphics.setLineWidth(2)
    love.graphics.polygon("line", 0, 18, -12, -4, 12, -4)
    
    love.graphics.pop()
end

function Tutorial.draw()
    -- Draw gameplay
    Gameplay.draw()
    
    local screenW, screenH = love.graphics.getDimensions()
    local state = Gameplay.getTutorialState and Gameplay.getTutorialState() or {}
    
    -- Draw tutorial overlay
    if currentStep <= #steps then
        local step = steps[currentStep]
        
        -- Count lines in message to size panel
        local lineCount = 1
        for _ in step.message:gmatch("\n") do lineCount = lineCount + 1 end
        local panelH = 50 + lineCount * 18
        
        -- Message panel at top center
        local panelW = 520
        local panelX = (screenW - panelW) / 2
        local panelY = 50
        
        -- Panel background
        love.graphics.setColor(UI.panelBg[1], UI.panelBg[2], UI.panelBg[3], UI.panelBg[4] * messageAlpha)
        love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 8)
        
        -- Panel border
        love.graphics.setColor(UI.panelBorder[1], UI.panelBorder[2], UI.panelBorder[3], messageAlpha)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 8)
        
        -- Corner rivets
        local rivetPositions = {
            {panelX + 12, panelY + 12},
            {panelX + panelW - 12, panelY + 12},
            {panelX + 12, panelY + panelH - 12},
            {panelX + panelW - 12, panelY + panelH - 12},
        }
        for _, pos in ipairs(rivetPositions) do
            love.graphics.setColor(0.5, 0.4, 0.2, messageAlpha)
            love.graphics.circle("fill", pos[1], pos[2], 5)
            love.graphics.setColor(0.7, 0.6, 0.3, messageAlpha)
            love.graphics.circle("fill", pos[1] - 1, pos[2] - 1, 2)
        end
        
        -- Step indicator
        love.graphics.setColor(UI.textGold[1], UI.textGold[2], UI.textGold[3], messageAlpha)
        love.graphics.setFont(Game.fonts.small)
        love.graphics.print("Step " .. currentStep .. " of " .. #steps, panelX + 20, panelY + 10)
        
        -- ESC hint or completion checkmark (top-right of panel)
        if stepCompleted then
            love.graphics.setColor(0.3, 0.9, 0.3, messageAlpha)
            love.graphics.setFont(Game.fonts.large)
            love.graphics.print("✓", panelX + panelW - 35, panelY + 10)
        else
            love.graphics.setColor(0.5, 0.45, 0.4, 0.6 * messageAlpha)
            love.graphics.setFont(Game.fonts.small)
            local skipText = "ESC to skip"
            local skipW = Game.fonts.small:getWidth(skipText)
            love.graphics.print(skipText, panelX + panelW - skipW - 15, panelY + 12)
        end
        
        -- Message text
        love.graphics.setColor(UI.textLight[1], UI.textLight[2], UI.textLight[3], messageAlpha)
        love.graphics.setFont(Game.fonts.medium)
        love.graphics.printf(step.message, panelX + 20, panelY + 30, panelW - 40, "left")
        
        -- Draw arrow pointing to target
        if step.arrowTarget and not stepCompleted then
            local targetX, targetY = nil, nil
            local arrowOffset = 60  -- Distance from target to place arrow
            local bounce = math.sin(arrowTimer * 5) * 8
            
            -- Calculate actual target position based on type
            if step.arrowTarget == "bottom_panel" then
                -- Command bar buttons are in the center-right of screen
                -- Primary button is centered, others to the right
                targetX = screenW / 2
                targetY = screenH - 35  -- Command bar is at bottom
                -- Arrow comes from above
                local arrowX = targetX
                local arrowY = targetY - arrowOffset + bounce
                drawArrow(arrowX, arrowY, targetX, targetY)
                
            elseif step.arrowTarget == "townhall" then
                -- Get player's town hall screen position
                local townHall = state.townHall
                if townHall and townHall.getScreenPos then
                    local sx, sy = townHall:getScreenPos()
                    local size = townHall.pixelSize or 96
                    targetX = sx + size / 2
                    targetY = sy + size / 2
                    -- Arrow comes from above-right
                    local arrowX = targetX + arrowOffset
                    local arrowY = targetY - arrowOffset + bounce
                    drawArrow(arrowX, arrowY, targetX, targetY)
                end
                
            elseif step.arrowTarget == "barracks" then
                -- Find player's first barracks
                for _, b in ipairs(state.barracks or {}) do
                    if b.team == state.playerTeam and b.getScreenPos then
                        local sx, sy = b:getScreenPos()
                        local size = b.pixelSize or 96
                        targetX = sx + size / 2
                        targetY = sy + size / 2
                        -- Arrow comes from above-right
                        local arrowX = targetX + arrowOffset
                        local arrowY = targetY - arrowOffset + bounce
                        drawArrow(arrowX, arrowY, targetX, targetY)
                        break
                    end
                end
                
            elseif step.arrowTarget == "peons" then
                -- Find a player peon that's visible (not in mine)
                for _, p in ipairs(state.peons or {}) do
                    if p.team == state.playerTeam and p.visible and p.getScreenPos then
                        local sx, sy = p:getScreenPos()
                        targetX = sx
                        targetY = sy
                        -- Arrow comes from above
                        local arrowX = targetX
                        local arrowY = targetY - arrowOffset + bounce
                        drawArrow(arrowX, arrowY, targetX, targetY)
                        break
                    end
                end
                
            elseif step.arrowTarget == "footmen" then
                -- Find a player footman
                for _, f in ipairs(state.footmen or {}) do
                    if f.team == state.playerTeam and f.getScreenPos then
                        local sx, sy = f:getScreenPos()
                        targetX = sx
                        targetY = sy
                        -- Arrow comes from above
                        local arrowX = targetX
                        local arrowY = targetY - arrowOffset + bounce
                        drawArrow(arrowX, arrowY, targetX, targetY)
                        break
                    end
                end
                
            elseif step.arrowTarget == "enemy_base" then
                -- Point toward top-right corner of map
                targetX = screenW - 100
                targetY = 200
                -- Arrow comes from below-left
                local arrowX = targetX - arrowOffset
                local arrowY = targetY + arrowOffset + bounce
                drawArrow(arrowX, arrowY, targetX, targetY)
            end
        end
    end
    
    -- Tutorial complete overlay
    if tutorialComplete then
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", 0, 0, screenW, screenH)
        
        -- Victory panel
        local vpW, vpH = 400, 150
        local vpX, vpY = (screenW - vpW) / 2, (screenH - vpH) / 2
        
        love.graphics.setColor(UI.panelBg)
        love.graphics.rectangle("fill", vpX, vpY, vpW, vpH, 10)
        love.graphics.setColor(UI.panelBorder)
        love.graphics.setLineWidth(4)
        love.graphics.rectangle("line", vpX, vpY, vpW, vpH, 10)
        
        love.graphics.setColor(UI.textGold)
        love.graphics.setFont(Game.fonts.large)
        local text = "Tutorial Complete!"
        local textW = Game.fonts.large:getWidth(text)
        love.graphics.print(text, (screenW - textW) / 2, vpY + 30)
        
        love.graphics.setColor(UI.textLight)
        love.graphics.setFont(Game.fonts.medium)
        love.graphics.printf("You're ready to play!\n\nPress ENTER to return to the menu.", vpX + 20, vpY + 70, vpW - 40, "center")
    end
end

function Tutorial.keypressed(key)
    if tutorialComplete then
        if key == "return" or key == "escape" then
            Game.SceneManager.switch("title")
            return
        end
    end
    
    -- Handle ENTER on the final "Victory!" step to go to title
    local state = Gameplay.getTutorialState and Gameplay.getTutorialState() or {}
    if currentStep == #steps and state.victory and (key == "return" or key == "space") then
        Game.SceneManager.switch("title")
        return
    end
    
    -- Skip tutorial with Escape
    if key == "escape" and not tutorialComplete then
        Game.SceneManager.switch("title")
        return
    end
    
    -- Pass to gameplay
    Gameplay.keypressed(key)
end

-- Get current step's selection restrictions
function Tutorial.getSelectionRestrictions()
    if currentStep > #steps then
        return nil, nil
    end
    local step = steps[currentStep]
    return step.lockSelection, step.allowOnly
end

function Tutorial.mousepressed(x, y, button)
    if tutorialComplete then return end
    Gameplay.mousepressed(x, y, button)
end

function Tutorial.mousereleased(x, y, button)
    if tutorialComplete then return end
    
    -- Get current selection before the click
    local state = Gameplay.getTutorialState and Gameplay.getTutorialState() or {}
    local prevSelection = state.selectedEntities and state.selectedEntities[1]
    local lockSelection, allowOnly = Tutorial.getSelectionRestrictions()
    
    -- Let gameplay handle the click
    Gameplay.mousereleased(x, y, button)
    
    -- Check if we need to revert selection
    if lockSelection or allowOnly then
        local newState = Gameplay.getTutorialState()
        local newSelection = newState.selectedEntities and newState.selectedEntities[1]
        
        if lockSelection then
            -- Revert any selection change
            if newSelection ~= prevSelection then
                -- Need to restore previous selection
                if Gameplay.forceSelect then
                    Gameplay.forceSelect(prevSelection)
                end
            end
        elseif allowOnly and newSelection then
            -- Only allow specific entity type
            if newSelection.type ~= allowOnly then
                -- Wrong type selected, revert
                if Gameplay.forceSelect then
                    Gameplay.forceSelect(prevSelection)
                end
            end
        end
    end
end

function Tutorial.mousemoved(x, y, dx, dy)
    if tutorialComplete then return end
    if Gameplay.mousemoved then
        Gameplay.mousemoved(x, y, dx, dy)
    end
end

function Tutorial.wheelmoved(x, y)
    if tutorialComplete then return end
    if Gameplay.wheelmoved then
        Gameplay.wheelmoved(x, y)
    end
end

return Tutorial
