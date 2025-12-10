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

-- Pagination
local currentPage = 1
local ITEMS_PER_PAGE = 12  -- 2 rows of 6

-- Layout
local PREVIEW_SIZE = 128
local PADDING = 20
local COLUMNS = 6

-- Teams module for enemy units
local Teams
pcall(function() Teams = require("teams") end)

-- UI drawing module for command bar
local UIDraw
pcall(function() UIDraw = require("ui_draw") end)

-- Shared command bar module
local CommandBar
pcall(function() CommandBar = require("command_bar") end)

-- Entity definitions for preview
local entityDefs = {
    -- Player Units
    {name = "Peon", type = "unit", module = "peon", create = function(m, x, y)
        return m.new({worldX = x, worldY = y, map = nil, team = Teams and Teams.PLAYER or 1})
    end},
    {name = "Footman", type = "unit", module = "footman", create = function(m, x, y)
        return m.new({worldX = x, worldY = y, map = nil, team = Teams and Teams.PLAYER or 1})
    end},
    {name = "Archer", type = "unit", module = "archer", create = function(m, x, y)
        return m.new({worldX = x, worldY = y, map = nil, team = Teams and Teams.PLAYER or 1})
    end},
    {name = "Knight", type = "unit", module = "knight", create = function(m, x, y)
        return m.new({worldX = x, worldY = y, map = nil, team = Teams and Teams.PLAYER or 1})
    end},
    {name = "Paladin", type = "unit", module = "knight", create = function(m, x, y)
        return m.new({worldX = x, worldY = y, map = nil, team = Teams and Teams.PLAYER or 1, isPaladin = true})
    end},
    {name = "Ballista", type = "unit", module = "ballista", create = function(m, x, y)
        return m.new({worldX = x, worldY = y, map = nil, team = Teams and Teams.PLAYER or 1})
    end},
    {name = "Flying Scout", type = "unit", module = "flyingscout", create = function(m, x, y)
        return m.new({worldX = x, worldY = y, map = nil, team = Teams and Teams.PLAYER or 1})
    end},
    {name = "Kamikaze", type = "unit", module = "kamikaze", create = function(m, x, y)
        return m.new({worldX = x, worldY = y, map = nil, team = Teams and Teams.PLAYER or 1})
    end},

    -- Enemy/Orc Units
    {name = "Grunt (Orc)", type = "unit", module = "footman", create = function(m, x, y)
        return m.new({worldX = x, worldY = y, map = nil, team = Teams and Teams.ENEMY or 2})
    end},
    {name = "Raider (Orc)", type = "unit", module = "knight", create = function(m, x, y)
        return m.new({worldX = x, worldY = y, map = nil, team = Teams and Teams.ENEMY or 2})
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
    {name = "Guard Tower", type = "building", module = "scouttower", tier = 2, create = function(m, x, y)
        local e = m.new({gridX = 1, gridY = 1, map = nil})
        e.completed = true
        e.tier = 2
        e.name = "Guard Tower"
        return e
    end},
    {name = "Cannon Tower", type = "building", module = "scouttower", tier = 3, create = function(m, x, y)
        local e = m.new({gridX = 1, gridY = 1, map = nil})
        e.completed = true
        e.tier = 3
        e.name = "Cannon Tower"
        return e
    end},
    {name = "Archery Range", type = "building", module = "archeryrange", create = function(m, x, y)
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
    currentPage = 1
    
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

-- Helper functions (must be defined before DevPreview.draw)

local function generateLogText()
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

local function drawLogPanel(screenW, screenH)
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

local function getPreviewButtons(def, entity)
    local buttons = {}
    local moduleName = def.module

    if def.type == "unit" then
        if moduleName == "peon" then
            -- Peon build buttons
            buttons = {
                {hotkey = "F", text = "Farm", icon = "farm", cost = "100/50"},
                {hotkey = "B", text = "Barracks", icon = "barracks", cost = "600/100"},
                {hotkey = "T", text = "Tower", icon = "tower", cost = "200/100"},
                {hotkey = "L", text = "Mill", icon = "generic", cost = "150/75"},
                {hotkey = "K", text = "Smith", icon = "generic", cost = "400/200"},
            }
        else
            -- Combat units - Attack and Stop
            buttons = {
                {hotkey = "A", text = "Attack", icon = "attack"},
                {hotkey = "S", text = "Stop", icon = "stop"},
            }
        end
    elseif def.type == "building" then
        if moduleName == "townhall" then
            buttons = {
                {hotkey = "W", text = "Peon", icon = "peon", cost = "100"},
            }
            if entity.tier == 1 then
                table.insert(buttons, {hotkey = "U", text = "Hold", icon = "generic", cost = "300/150"})
            elseif entity.tier == 2 then
                table.insert(buttons, {hotkey = "U", text = "Keep", icon = "generic", cost = "500/200"})
            end
        elseif moduleName == "barracks" then
            buttons = {
                {hotkey = "T", text = "Footman", icon = "footman", cost = "135"},
                {hotkey = "A", text = "Archer", icon = "generic", cost = "150/50"},
                {hotkey = "K", text = "Knight", icon = "generic", cost = "250/100"},
                {hotkey = "B", text = "Ballista", icon = "generic", cost = "500/200"},
            }
        elseif moduleName == "archeryrange" then
            buttons = {
                {hotkey = "A", text = "Archer", icon = "generic", cost = "150/50"},
            }
        elseif moduleName == "stable" then
            buttons = {
                {hotkey = "K", text = "Knight", icon = "generic", cost = "250/100"},
                {hotkey = "P", text = "Paladin", icon = "generic", cost = "200"},
            }
        elseif moduleName == "siegeworkshop" then
            buttons = {
                {hotkey = "S", text = "Scout", icon = "generic", cost = "200/100"},
                {hotkey = "K", text = "Kamikaze", icon = "generic", cost = "150/50"},
                {hotkey = "B", text = "Ballista", icon = "generic", cost = "500/200"},
            }
        elseif moduleName == "scouttower" then
            -- Scout Tower upgrade buttons (only for tier 1)
            if entity.tier == 1 or entity.tier == nil then
                buttons = {
                    {hotkey = "G", text = "Guard Tower", icon = "tower", cost = "200/100", requirement = "Lumber Mill"},
                    {hotkey = "C", text = "Cannon Tower", icon = "tower", cost = "400/200", requirement = "Blacksmith + Keep"},
                }
            end
        end
    end

    return buttons
end

local function drawCommandBarPreview(screenW, screenH)
    if not selectedEntity then return end

    -- Get buttons for this entity
    local buttons = getPreviewButtons(selectedEntity.def, selectedEntity.entity)

    -- Use shared CommandBar module if available
    if CommandBar and CommandBar.drawSimple then
        -- Create a simple entity object for the CommandBar
        local entityInfo = {
            name = selectedEntity.def.name,
            hp = selectedEntity.entity.hp,
            maxHp = selectedEntity.entity.maxHp,
            isBuilding = selectedEntity.entity.isBuilding,
            isProducing = selectedEntity.entity.isProducing,
            getStateText = selectedEntity.entity.getStateText and function(self)
                return selectedEntity.entity:getStateText()
            end or nil
        }
        CommandBar.drawSimple(screenW, screenH, entityInfo, buttons)
    else
        -- Fallback: draw manually
        local barH = 80
        local barY = screenH - barH

        -- Draw bar background
        if UIDraw and UIDraw.drawCommandBar then
            UIDraw.drawCommandBar(screenW, screenH)
        else
            love.graphics.setColor(0.12, 0.1, 0.08, 0.95)
            love.graphics.rectangle("fill", 0, barY, screenW, barH)
            love.graphics.setColor(0.4, 0.35, 0.25, 1)
            love.graphics.setLineWidth(2)
            love.graphics.line(0, barY, screenW, barY)
        end

        -- Entity name
        love.graphics.setColor(1, 0.9, 0.6, 1)
        love.graphics.setFont(love.graphics.newFont(16))
        love.graphics.print(selectedEntity.def.name, 20, barY + 10)

        -- Draw buttons
        local btnSize = 50
        local btnSpacing = 4
        local btnStartX = 200
        local btnY = barY + 12

        for i, btn in ipairs(buttons) do
            local btnX = btnStartX + (i - 1) * (btnSize + btnSpacing)
            if UIDraw and UIDraw.drawCommandButton then
                UIDraw.drawCommandButton(btnX, btnY, btnSize, btnSize, btn.text, btn.hotkey, true, false, false, btn.icon)
            end
            if btn.cost then
                love.graphics.setColor(0.9, 0.85, 0.6, 0.8)
                love.graphics.setFont(love.graphics.newFont(9))
                local costW = love.graphics.getFont():getWidth(btn.cost)
                love.graphics.print(btn.cost, btnX + (btnSize - costW) / 2, btnY + btnSize + 2)
            end
        end
    end
end

function DevPreview.draw()
    local screenW, screenH = love.graphics.getDimensions()

    -- Background
    love.graphics.setColor(0.15, 0.18, 0.22, 1)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    -- Calculate pagination
    local totalPages = math.ceil(#entities / ITEMS_PER_PAGE)
    local startIdx = (currentPage - 1) * ITEMS_PER_PAGE + 1
    local endIdx = math.min(currentPage * ITEMS_PER_PAGE, #entities)

    -- Title
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(love.graphics.newFont(24))
    love.graphics.print("Developer Preview - Entity Gallery", 20, 10)
    love.graphics.setFont(love.graphics.newFont(12))
    love.graphics.print("Click to select | R to mark 'needs redo' | L to show log | C to copy log | ESC to exit", 20, 40)

    -- Page indicator
    love.graphics.setColor(0.8, 0.9, 1, 1)
    love.graphics.setFont(love.graphics.newFont(14))
    local pageText = string.format("Page %d / %d  (Left/Right arrows or A/D to navigate)", currentPage, totalPages)
    love.graphics.print(pageText, screenW - 450, 15)

    -- Draw grid of entities (only current page)
    love.graphics.push()
    love.graphics.translate(0, 60 - scrollY)

    for i = startIdx, endIdx do
        local e = entities[i]
        local pageIdx = i - startIdx  -- 0-based index within page
        local col = pageIdx % COLUMNS
        local row = math.floor(pageIdx / COLUMNS)
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

    -- Command bar preview (drawn on top of everything)
    drawCommandBarPreview(screenW, screenH)

    love.graphics.setColor(1, 1, 1, 1)
end

function DevPreview.mousepressed(x, y, button)
    if button == 1 then
        local adjustedY = y - 60 + scrollY

        -- Only check entities on current page
        local startIdx = (currentPage - 1) * ITEMS_PER_PAGE + 1
        local endIdx = math.min(currentPage * ITEMS_PER_PAGE, #entities)

        -- Clear previous selection
        if selectedEntity then
            selectedEntity.selected = false
            selectedEntity.entity.selected = false
        end
        selectedEntity = nil

        for i = startIdx, endIdx do
            local e = entities[i]
            local pageIdx = i - startIdx  -- 0-based index within page
            local col = pageIdx % COLUMNS
            local row = math.floor(pageIdx / COLUMNS)
            local boxX = PADDING + col * (PREVIEW_SIZE + PADDING)
            local boxY = PADDING + row * (PREVIEW_SIZE + PADDING)

            if x >= boxX and x <= boxX + PREVIEW_SIZE and
               adjustedY >= boxY and adjustedY <= boxY + PREVIEW_SIZE then
                -- Select this entity (single selection)
                e.selected = true
                e.entity.selected = true  -- Set on actual entity for selection circle
                selectedEntity = e
                break
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
    local totalPages = math.ceil(#entities / ITEMS_PER_PAGE)

    if key == "escape" then
        -- Return to title screen
        if Game and Game.SceneManager then
            Game.SceneManager.switch("title")
        end
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
    elseif key == "left" or key == "a" then
        -- Previous page
        currentPage = currentPage - 1
        if currentPage < 1 then
            currentPage = totalPages  -- Wrap to last page
        end
    elseif key == "right" or key == "d" then
        -- Next page
        currentPage = currentPage + 1
        if currentPage > totalPages then
            currentPage = 1  -- Wrap to first page
        end
    end
end

return DevPreview
