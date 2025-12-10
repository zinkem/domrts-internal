--[[
    Building Placement Module
    Handles the building placement preview and validation system.
    Extracted from gameplay.lua to reduce upvalue count.
]]

local BuildingPlacement = {}
BuildingPlacement.__index = BuildingPlacement

-- Audio (optional)
local Audio
pcall(function() Audio = require("audio") end)

-- Building module references (lazy-loaded to avoid circular dependencies)
local buildingModules = {}

local function getBuildingModule(buildingType)
    if not buildingModules[buildingType] then
        local ok, mod = pcall(require, buildingType)
        if ok then
            buildingModules[buildingType] = mod
        end
    end
    return buildingModules[buildingType]
end

function BuildingPlacement.new()
    local self = setmetatable({}, BuildingPlacement)

    self.active = false
    self.buildingType = nil
    self.peon = nil
    self.valid = false
    self.gridX = 0
    self.gridY = 0

    return self
end

function BuildingPlacement:start(peon, buildingType)
    self.active = true
    self.buildingType = buildingType
    self.peon = peon
    self.valid = false
end

function BuildingPlacement:cancel()
    self.active = false
    self.buildingType = nil
    self.peon = nil
    self.valid = false
end

function BuildingPlacement:isActive()
    return self.active
end

function BuildingPlacement:getBuildingType()
    return self.buildingType
end

function BuildingPlacement:getPeon()
    return self.peon
end

function BuildingPlacement:isValid()
    return self.valid
end

function BuildingPlacement:getGridPosition()
    return self.gridX, self.gridY
end

function BuildingPlacement:getSize(buildingType)
    local bType = buildingType or self.buildingType
    local mod = getBuildingModule(bType)
    if mod and mod.GRID_SIZE then
        return mod.GRID_SIZE
    end
    return 3  -- fallback default
end

-- Check if two building footprints overlap
local function buildingsOverlap(ax, ay, aSize, bx, by, bSize)
    return ax < bx + bSize and ax + aSize > bx and
           ay < by + bSize and ay + aSize > by
end

-- Update placement validity based on mouse position
-- params: map, goldMines, allBuildings (from getAllBuildings())
function BuildingPlacement:update(map, goldMines, allBuildings)
    if not self.active then return end

    local mx, my = love.mouse.getPosition()
    if not map:isInViewport(mx, my) then
        self.valid = false
        return
    end

    local worldX, worldY = map:screenToWorld(mx, my)
    local gridX, gridY = map:worldToGrid(worldX, worldY)
    local buildSize = self:getSize()

    -- Check if area is clear of trees/terrain
    self.valid = map:isAreaClear(gridX, gridY, buildSize, buildSize)

    -- Check for overlap with existing buildings
    if self.valid then
        for _, building in ipairs(allBuildings) do
            if building.gridSize and buildingsOverlap(gridX, gridY, buildSize, building.gridX, building.gridY, building.gridSize) then
                self.valid = false
                break
            end
        end
    end

    -- Townhall cannot be placed within 2 tiles of a gold mine
    if self.valid and self.buildingType == "townhall" then
        local minGapFromMine = 2
        for _, mine in ipairs(goldMines) do
            local mineSize = mine.gridSize or 3
            local gapX = math.max(mine.gridX - (gridX + buildSize), gridX - (mine.gridX + mineSize))
            local gapY = math.max(mine.gridY - (gridY + buildSize), gridY - (mine.gridY + mineSize))

            local effectiveGap
            if gapX < 0 and gapY < 0 then
                effectiveGap = -1
            elseif gapX < 0 then
                effectiveGap = gapY
            elseif gapY < 0 then
                effectiveGap = gapX
            else
                effectiveGap = math.min(gapX, gapY)
            end

            if effectiveGap < minGapFromMine then
                self.valid = false
                break
            end
        end
    end

    self.gridX, self.gridY = gridX, gridY
end

-- Draw the placement preview
function BuildingPlacement:draw(map, fonts)
    if not self.active then return end

    local mx, my = love.mouse.getPosition()
    if not map:isInViewport(mx, my) then return end

    local buildSize = self:getSize()
    local screenX, screenY = map:worldToScreen(map:gridToWorld(self.gridX, self.gridY))
    local pixelSize = buildSize * 32

    -- Green if valid, red if invalid
    love.graphics.setColor(self.valid and {0, 1, 0, 0.4} or {1, 0, 0, 0.4})
    love.graphics.rectangle("fill", screenX, screenY, pixelSize, pixelSize)
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", screenX, screenY, pixelSize, pixelSize)

    -- Instructions
    if fonts and fonts.small then
        love.graphics.setFont(fonts.small)
    end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Left-click to place " .. self.buildingType .. " | Right-click to cancel",
                       map.viewportX + 10, map.viewportY + map.viewportH - 25)
end

-- Handle mouse click during placement
-- Returns: true if click was handled, false otherwise
-- On successful placement, returns: true, peon, buildingType, gridX, gridY
function BuildingPlacement:mousepressed(x, y, button, map)
    if not self.active then return false end

    if button == 1 and self.valid and map:isInViewport(x, y) then
        -- Left click on valid spot - confirm placement
        local peon = self.peon
        local buildingType = self.buildingType
        local gridX, gridY = self.gridX, self.gridY
        self:cancel()
        return true, peon, buildingType, gridX, gridY
    elseif button == 1 and not self.valid and map:isInViewport(x, y) then
        -- Left click on invalid (red) spot - play alert
        if Audio and Audio.playAlert then Audio.playAlert() end
        return true
    elseif button == 2 then
        -- Right click - cancel placement
        if Audio and Audio.playAlert then Audio.playAlert() end
        self:cancel()
        return true
    end

    return true  -- Still handled (block other interactions while placing)
end

-- Handle escape key
function BuildingPlacement:keypressed(key)
    if not self.active then return false end

    if key == "escape" then
        if Audio and Audio.playAlert then Audio.playAlert() end
        self:cancel()
        return true
    end

    return false
end

return BuildingPlacement
