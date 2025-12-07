--[[
    Developer Preview Scene
    Shows all units and buildings for visual design iteration
    Allows selection and generates feedback logs
]]

local DevPreview = {}

-- Entity modules (loaded on demand)
local entityModules = {}

-- Preview state
local entities = {}
local selectedEntity = nil
local feedbackLog = {}
local scrollY = 0
local showLog = false
local animTimer = 0

-- Layout
local PREVIEW_SIZE = 128
local PADDING = 20
local COLUMNS = 6

-- Entity definitions for preview
local entityDefs = {
    -- Units
    {name = "Peon", type = "unit", module = "peon", create = function(m, x, y) 
        return m.new({worldX = x, worldY = y, map = nil}) 
    end},
    {name = "Footman", type = "unit", module = "footman", create = function(m, x, y)
        return m.new({worldX = x, worldY = y, map = nil})
    end},
    {name = "Archer", type = "unit", module = "archer", create = function(m, x, y)
        return m.new({worldX = x, worldY = y, map = nil})
    end},
    {name = "Knight", type = "unit", module = "knight", create = function(m, x, y)
        return m.new({worldX = x, worldY = y, map = nil})
    end},
    {name = "Ballista", type = "unit", module = "ballista", create = function(m, x, y)
        return m.new({worldX = x, worldY = y, map = nil})
    end},
    {name = "Flying Scout", type = "unit", module = "flyingscout", create = function(m, x, y)
        return m.new({worldX = x, worldY = y, map = nil})
    end},
    {name = "Kamikaze", type = "unit", module = "kamikaze", create = function(m, x, y)
        return m.new({worldX = x, worldY = y, map = nil})
    end},
    
    -- Buildings
    {name = "Town Hall", type = "building", module = "townhall", tier = 1, create = function(m, x, y)
        local e = m.new({gridX = 1, gridY = 1, map = nil})
        e.tier = 1
        e.completed = true
        return e
    end},
    {name = "Hold", type = "building", module = "townhall", tier = 2, create = function(m, x, y)
        local e = m.new({gridX = 1, gridY = 1, map = nil})
        e.tier = 2
        e.name = "Hold"
        e.completed = true
        return e
    end},
    {name = "Keep", type = "building", module = "townhall", tier = 3, create = function(m, x, y)
        local e = m.new({gridX = 1, gridY = 1, map = nil})
        e.tier = 3
        e.name = "Keep"
        e.completed = true
        return e
    end},
    {name = "Barracks", type = "building", module = "barracks", create = function(m, x, y)
        local e = m.new({gridX = 1, gridY = 1, map = nil})
        e.completed = true
        return e
    end},
    {name = "Farm", type = "building", module = "farm", create = function(m, x, y)
        local e = m.new({gridX = 1, gridY = 1, map = nil})
        e.completed = true
        return e
    end},
    {name = "Lumber Mill", type = "building", module = "lumbermill", create = function(m, x, y)
        local e = m.new({gridX = 1, gridY = 1, map = nil})
        e.completed = true
        return e
    end},
    {name = "Blacksmith", type = "building", module = "blacksmith", create = function(m, x, y)
        local e = m.new({gridX = 1, gridY = 1, map = nil})
        e.completed = true
        return e
    end},
    {name = "Scout Tower", type = "building", module = "scouttower", create = function(m, x, y)
        local e = m.new({gridX = 1, gridY = 1, map = nil})
        e.completed = true
        return e
    end},
    {name = "Stable", type = "building", module = "stable", create = function(m, x, y)
        local e = m.new({gridX = 1, gridY = 1, map = nil})
        e.completed = true
        return e
    end},
    {name = "Siege Workshop", type = "building", module = "siegeworkshop", create = function(m, x, y)
        local e = m.new({gridX = 1, gridY = 1, map = nil})
        e.completed = true
        return e
    end},
    {name = "Gold Mine", type = "building", module = "goldmine", create = function(m, x, y)
        return m.new({gridX = 1, gridY = 1, map = nil})
    end},
}

function DevPreview.load()
    entities = {}
    selectedEntity = nil
    feedbackLog = {}
    scrollY = 0
    showLog = false
    animTimer = 0
    
    -- Load all entity modules
    for _, def in ipairs(entityDefs) do
        if not entityModules[def.module] then
            local success, mod = pcall(require, def.module)
            if success then
                entityModules[def.module] = mod
            else
                print("Failed to load module: " .. def.module)
            end
        end
    end
    
    -- Create preview entities
    for i, def in ipairs(entityDefs) do
        local mod = entityModules[def.module]
        if mod then
            local col = ((i - 1) % COLUMNS)
            local row = math.floor((i - 1) / COLUMNS)
            local x = PADDING + col * (PREVIEW_SIZE + PADDING) + PREVIEW_SIZE/2
            local y = PADDING + row * (PREVIEW_SIZE + PADDING) + PREVIEW_SIZE/2
            
            local entity = def.create(mod, x, y)
            if entity then
                table.insert(entities, {
                    def = def,
                    entity = entity,
                    x = x,
                    y = y,
                    selected = false,
                    needsRedo = false
                })
            end
        end
    end
end

function DevPreview.update(dt)
    animTimer = animTimer + dt
    
    -- Update entities for animation
    for _, e in ipairs(entities) do
        if e.entity.update then
            pcall(function() e.entity:update(dt) end)
        end
        -- Manually update animTimer for entities that need it
        if e.entity.animTimer ~= nil then
            e.entity.animTimer = animTimer
        end
    end
end

function DevPreview.draw()
    local screenW, screenH = love.graphics.getDimensions()
    
    -- Background
    love.graphics.setColor(0.15, 0.18, 0.22, 1)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)
    
    -- Title
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(love.graphics.newFont(24))
    love.graphics.print("Developer Preview - Entity Gallery", 20, 10)
    love.graphics.setFont(love.graphics.newFont(12))
    love.graphics.print("Click to select | R to toggle 'needs redo' | L to show log | C to copy log | ESC to exit", 20, 40)
    
    -- Draw grid of entities
    love.graphics.push()
    love.graphics.translate(0, 60 - scrollY)
    
    for i, e in ipairs(entities) do
        local col = ((i - 1) % COLUMNS)
        local row = math.floor((i - 1) / COLUMNS)
        local boxX = PADDING + col * (PREVIEW_SIZE + PADDING)
        local boxY = PADDING + row * (PREVIEW_SIZE + PADDING)
        
        -- Background box
        if e.selected then
            love.graphics.setColor(0.3, 0.5, 0.7, 1)
        elseif e.needsRedo then
            love.graphics.setColor(0.6, 0.3, 0.2, 1)
        else
            love.graphics.setColor(0.25, 0.28, 0.32, 1)
        end
        love.graphics.rectangle("fill", boxX, boxY, PREVIEW_SIZE, PREVIEW_SIZE, 8)
        
        -- Border
        if e.selected then
            love.graphics.setColor(0.5, 0.8, 1, 1)
            love.graphics.setLineWidth(3)
        elseif e.needsRedo then
            love.graphics.setColor(1, 0.5, 0.3, 1)
            love.graphics.setLineWidth(2)
        else
            love.graphics.setColor(0.4, 0.42, 0.45, 1)
            love.graphics.setLineWidth(1)
        end
        love.graphics.rectangle("line", boxX, boxY, PREVIEW_SIZE, PREVIEW_SIZE, 8)
        
        -- Draw entity
        love.graphics.push()
        local centerX = boxX + PREVIEW_SIZE/2
        local centerY = boxY + PREVIEW_SIZE/2
        
        if e.def.type == "unit" then
            -- Units draw at worldX, worldY - need to offset for screen pos
            if e.entity.draw then
                -- Temporarily set screen position
                local oldGetScreen = e.entity.getScreenPos
                e.entity.getScreenPos = function() return centerX - 16, centerY - 16 end
                e.entity.worldX = centerX
                e.entity.worldY = centerY
                pcall(function() e.entity:draw() end)
                e.entity.getScreenPos = oldGetScreen
            end
        else
            -- Buildings draw at grid position
            if e.entity.draw then
                local size = e.entity.pixelSize or 64
                local oldGetScreen = e.entity.getScreenPos
                e.entity.getScreenPos = function() return centerX - size/2, centerY - size/2 end
                pcall(function() e.entity:draw() end)
                e.entity.getScreenPos = oldGetScreen
            end
        end
        love.graphics.pop()
        
        -- Label
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setFont(love.graphics.newFont(10))
        local textW = love.graphics.getFont():getWidth(e.def.name)
        love.graphics.print(e.def.name, boxX + (PREVIEW_SIZE - textW)/2, boxY + PREVIEW_SIZE + 2)
        
        -- Redo indicator
        if e.needsRedo then
            love.graphics.setColor(1, 0.4, 0.3, 1)
            love.graphics.print("REDO", boxX + 4, boxY + 4)
        end
    end
    
    love.graphics.pop()
    
    -- Log panel
    if showLog then
        drawLogPanel(screenW, screenH)
    end
    
    love.graphics.setColor(1, 1, 1, 1)
end

function drawLogPanel(screenW, screenH)
    local panelW = 400
    local panelH = screenH - 100
    local panelX = screenW - panelW - 20
    local panelY = 80
    
    -- Panel background
    love.graphics.setColor(0.1, 0.12, 0.15, 0.95)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 8)
    love.graphics.setColor(0.4, 0.5, 0.6, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 8)
    
    -- Title
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(love.graphics.newFont(14))
    love.graphics.print("Feedback Log (C to copy)", panelX + 10, panelY + 10)
    
    -- Generate log text
    local logText = generateLogText()
    
    -- Log content
    love.graphics.setFont(love.graphics.newFont(11))
    love.graphics.setColor(0.9, 0.95, 1, 1)
    love.graphics.printf(logText, panelX + 10, panelY + 35, panelW - 20)
end

function generateLogText()
    local lines = {"=== ENTITY DESIGN FEEDBACK ===", ""}
    
    local needsRedoList = {}
    local okList = {}
    
    for _, e in ipairs(entities) do
        if e.needsRedo then
            table.insert(needsRedoList, e.def.name)
        else
            table.insert(okList, e.def.name)
        end
    end
    
    if #needsRedoList > 0 then
        table.insert(lines, "NEEDS REDESIGN:")
        for _, name in ipairs(needsRedoList) do
            table.insert(lines, "  - " .. name)
        end
        table.insert(lines, "")
    end
    
    if #okList > 0 then
        table.insert(lines, "APPROVED:")
        for _, name in ipairs(okList) do
            table.insert(lines, "  + " .. name)
        end
    end
    
    table.insert(lines, "")
    table.insert(lines, "=== END FEEDBACK ===")
    
    return table.concat(lines, "\n")
end

function DevPreview.mousepressed(x, y, button)
    if button == 1 then
        local adjustedY = y - 60 + scrollY
        
        for i, e in ipairs(entities) do
            local col = ((i - 1) % COLUMNS)
            local row = math.floor((i - 1) / COLUMNS)
            local boxX = PADDING + col * (PREVIEW_SIZE + PADDING)
            local boxY = PADDING + row * (PREVIEW_SIZE + PADDING)
            
            if x >= boxX and x <= boxX + PREVIEW_SIZE and
               adjustedY >= boxY and adjustedY <= boxY + PREVIEW_SIZE then
                -- Toggle selection
                e.selected = not e.selected
                if e.selected then
                    selectedEntity = e
                else
                    selectedEntity = nil
                end
            end
        end
    end
end

function DevPreview.wheelmoved(x, y)
    scrollY = scrollY - y * 40
    scrollY = math.max(0, scrollY)
    
    local rows = math.ceil(#entities / COLUMNS)
    local maxScroll = math.max(0, rows * (PREVIEW_SIZE + PADDING) + PADDING - 500)
    scrollY = math.min(scrollY, maxScroll)
end

function DevPreview.keypressed(key)
    if key == "escape" then
        -- Return to title screen
        local SceneManager = require("scenemanager")
        SceneManager.switch("titlescreen")
    elseif key == "r" then
        -- Toggle redo flag on selected entities
        for _, e in ipairs(entities) do
            if e.selected then
                e.needsRedo = not e.needsRedo
            end
        end
    elseif key == "l" then
        showLog = not showLog
    elseif key == "c" then
        -- Copy log to clipboard
        local logText = generateLogText()
        love.system.setClipboardText(logText)
    elseif key == "a" then
        -- Select all
        for _, e in ipairs(entities) do
            e.selected = true
        end
    elseif key == "d" then
        -- Deselect all
        for _, e in ipairs(entities) do
            e.selected = false
        end
        selectedEntity = nil
    end
end

return DevPreview
