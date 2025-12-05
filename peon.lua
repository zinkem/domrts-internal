--[[
    Peon
    Worker unit that moves, harvests gold, and builds structures
    Size: 1x1 tile, free movement (not grid-aligned), circular collision
]]

local Button = require("button")
local FlowField = require("flowfield")

local Peon = {}
Peon.__index = Peon

-- States
Peon.STATE_IDLE = "Idle"
Peon.STATE_MOVING = "Moving"
Peon.STATE_HARVESTING = "Harvesting"
Peon.STATE_RETURNING = "Returning"
Peon.STATE_CHOPPING = "Chopping"
Peon.STATE_BUILDING = "Building"

Peon.RADIUS = 14  -- Fits inside 1 tile (32x32 pixels)

function Peon.new(params)
    local self = setmetatable({}, Peon)
    
    self.worldX = params.worldX or 0
    self.worldY = params.worldY or 0
    self.map = params.map
    self.radius = Peon.RADIUS
    self.speed = 120
    self.selected = false
    self.type = "peon"
    self.name = "Peon"
    self.state = Peon.STATE_IDLE
    
    self.targetX = nil
    self.targetY = nil
    self.flowField = nil  -- Flow field for pathfinding
    
    -- Gold harvesting
    self.carryingGold = 0
    self.harvestAmount = 10
    self.harvestTime = 1.0
    self.harvestTimer = 0
    self.targetMine = nil
    self.targetTownHall = nil
    self.visible = true
    
    -- Lumber harvesting
    self.carryingLumber = 0
    self.choppingAmount = 10
    self.choppingTime = 5.0
    self.choppingTimer = 0
    self.targetTreeX = nil
    self.targetTreeY = nil
    
    -- Building
    self.buildTargetX = nil
    self.buildTargetY = nil
    self.buildingType = nil
    self.buildCallback = nil
    
    -- UI
    self.buildFarmButton = nil
    self.buildBarracksButton = nil
    
    return self
end

function Peon:getScreenPos()
    if self.map then
        return self.map:worldToScreen(self.worldX, self.worldY)
    end
    return self.worldX, self.worldY
end

function Peon:wouldCollideWithBuilding(x, y, building)
    if not building.getWorldBounds then return false end
    local bx1, by1, bx2, by2 = building:getWorldBounds()
    local closestX = math.max(bx1, math.min(x, bx2))
    local closestY = math.max(by1, math.min(y, by2))
    local distX = x - closestX
    local distY = y - closestY
    return (distX * distX + distY * distY) < (self.radius * self.radius)
end

function Peon:getBuildingPenetration(x, y, building)
    if not building.getWorldBounds then return 0 end
    local bx1, by1, bx2, by2 = building:getWorldBounds()
    local closestX = math.max(bx1, math.min(x, bx2))
    local closestY = math.max(by1, math.min(y, by2))
    local distX = x - closestX
    local distY = y - closestY
    local dist = math.sqrt(distX * distX + distY * distY)
    if dist < self.radius then
        return self.radius - dist  -- penetration depth
    end
    return 0
end

-- Check if peon is touching (adjacent to) a building without being inside
-- Returns true if peon is within contactBuffer pixels of building edge
function Peon:isTouchingBuilding(building, contactBuffer)
    contactBuffer = contactBuffer or 4
    if not building.getWorldBounds then return false end
    local bx1, by1, bx2, by2 = building:getWorldBounds()
    local closestX = math.max(bx1, math.min(self.worldX, bx2))
    local closestY = math.max(by1, math.min(self.worldY, by2))
    local distX = self.worldX - closestX
    local distY = self.worldY - closestY
    local dist = math.sqrt(distX * distX + distY * distY)
    -- Touching means within radius + buffer distance of building edge
    return dist <= self.radius + contactBuffer
end

function Peon:canMoveTo(newX, newY, buildings)
    -- Check tree collision
    if self.map then
        local targetGridX, targetGridY = self.map:worldToGrid(newX, newY)
        local isTargetTree = self.targetTreeX and targetGridX == self.targetTreeX and targetGridY == self.targetTreeY
        if not isTargetTree and not self.map:isWorldPosPassable(newX, newY) then
            return false
        end
    end
    
    if not buildings then return true end
    
    for _, b in ipairs(buildings) do
        local currentPen = self:getBuildingPenetration(self.worldX, self.worldY, b)
        local newPen = self:getBuildingPenetration(newX, newY, b)
        
        if newPen > 0 then
            -- Would be inside building
            if currentPen > 0 then
                -- Already inside - only allow if reducing penetration (escaping)
                if newPen >= currentPen then
                    return false
                end
            else
                -- Not inside currently, don't allow entering
                return false
            end
        end
    end
    
    return true
end

function Peon:update(dt, townHall, buildings)
    local goldDeposited = 0
    local lumberDeposited = 0
    
    if self.state == Peon.STATE_MOVING then
        self:updateMoving(dt, buildings)
    elseif self.state == Peon.STATE_HARVESTING then
        self:updateHarvesting(dt)
    elseif self.state == Peon.STATE_CHOPPING then
        self:updateChopping(dt)
    elseif self.state == Peon.STATE_RETURNING then
        goldDeposited, lumberDeposited = self:updateReturning(dt, townHall, buildings)
    end
    -- STATE_BUILDING: peon waits, handled externally
    
    return goldDeposited, lumberDeposited
end

function Peon:updateMoving(dt, buildings)
    if not self.targetX or not self.targetY then
        self.state = Peon.STATE_IDLE
        return
    end
    
    -- Check for contact-based arrival (mines, town hall for returning)
    -- This happens BEFORE distance checks to handle collision-blocked movement
    if self.targetMine and not self.targetMine.depleted then
        if self:isTouchingBuilding(self.targetMine, 4) then
            self.state = Peon.STATE_HARVESTING
            self.harvestTimer = 0
            self.visible = false
            return
        end
    end
    
    -- Check tree arrival - adjacent to tree tile
    if self.targetTreeX and self.map:isTileTree(self.targetTreeX, self.targetTreeY) then
        local treeWorldX, treeWorldY = self.map:getTileWorldCenter(self.targetTreeX, self.targetTreeY)
        local tdx = treeWorldX - self.worldX
        local tdy = treeWorldY - self.worldY
        local tdist = math.sqrt(tdx * tdx + tdy * tdy)
        -- Tree tile is 32 pixels, so touching is radius + 16 + small buffer
        if tdist <= self.radius + 20 then
            self.state = Peon.STATE_CHOPPING
            self.choppingTimer = 0
            return
        end
    end
    
    -- Check build site arrival
    if self.buildTargetX and self.buildCallback then
        local buildWorldX, buildWorldY = self.map:gridToWorld(self.buildTargetX, self.buildTargetY)
        local bdx = (buildWorldX + 16) - self.worldX
        local bdy = (buildWorldY + 16) - self.worldY
        local bdist = math.sqrt(bdx * bdx + bdy * bdy)
        if bdist <= 40 then
            self.state = Peon.STATE_BUILDING
            self.visible = false
            self.buildCallback(self.buildTargetX, self.buildTargetY, self.buildingType, self)
            self.buildCallback = nil
            return
        end
    end
    
    local dx = self.targetX - self.worldX
    local dy = self.targetY - self.worldY
    local dist = math.sqrt(dx * dx + dy * dy)
    
    -- Simple move arrival (no special target)
    local arriveThreshold = 8
    if not self.targetMine and not self.targetTreeX and not self.buildTargetX then
        if dist <= arriveThreshold then
            self.state = Peon.STATE_IDLE
            self.targetX = nil
            self.targetY = nil
            self.flowField = nil
            return
        end
    end
    
    -- Get movement direction from flow field or direct path
    local moveDirX, moveDirY
    
    if self.flowField then
        moveDirX, moveDirY = self.flowField:getDirection(self.worldX, self.worldY, self.map)
    end
    
    -- Fall back to direct path if no flow field direction
    if not moveDirX or not moveDirY then
        if dist > 0.1 then
            moveDirX = dx / dist
            moveDirY = dy / dist
        else
            return
        end
    end
    
    -- Movement
    local moveSpeed = self.speed * dt
    local moveX = moveDirX * moveSpeed
    local moveY = moveDirY * moveSpeed
    local newX = self.worldX + moveX
    local newY = self.worldY + moveY
    
    if self:canMoveTo(newX, newY, buildings) then
        self.worldX = newX
        self.worldY = newY
    else
        -- Try sliding along X or Y axis
        if self:canMoveTo(newX, self.worldY, buildings) then
            self.worldX = newX
        elseif self:canMoveTo(self.worldX, newY, buildings) then
            self.worldY = newY
        end
        -- If both blocked, contact-based arrival will trigger next frame
    end
end

function Peon:updateHarvesting(dt)
    self.harvestTimer = self.harvestTimer + dt
    if self.harvestTimer >= self.harvestTime then
        self.visible = true
        if self.targetMine and not self.targetMine.depleted then
            self.carryingGold = self.targetMine:extractGold(self.harvestAmount)
        end
        self.state = Peon.STATE_RETURNING
        self.harvestTimer = 0
    end
end

function Peon:updateChopping(dt)
    self.choppingTimer = self.choppingTimer + dt
    if self.choppingTimer >= self.choppingTime then
        self.carryingLumber = self.choppingAmount
        self.state = Peon.STATE_RETURNING
        self.choppingTimer = 0
    end
end

function Peon:updateReturning(dt, townHall, buildings)
    if not townHall then
        self.state = Peon.STATE_IDLE
        return 0, 0
    end
    
    self.targetTownHall = townHall
    
    -- Check for contact-based arrival at town hall
    if self:isTouchingBuilding(townHall, 4) then
        -- Deposit resources
        local goldDeposited = self.carryingGold
        local lumberDeposited = self.carryingLumber
        self.carryingGold = 0
        self.carryingLumber = 0
        
        -- Continue harvesting if we have a valid target
        if self.targetMine and not self.targetMine.depleted then
            self:goToMine(self.targetMine)
        elseif self.targetTreeX and self.map:isTileTree(self.targetTreeX, self.targetTreeY) then
            self:goToTree(self.targetTreeX, self.targetTreeY)
        else
            self.state = Peon.STATE_IDLE
            self.targetMine = nil
            self.targetTreeX = nil
            self.targetTreeY = nil
            self.flowField = nil
        end
        
        return goldDeposited, lumberDeposited
    end
    
    -- Get or create flow field to town hall
    if not self.flowField then
        local thGridX, thGridY = self.map:worldToGrid(townHall:getWorldCenter())
        self.flowField = FlowField.getField(thGridX, thGridY, self.map, buildings)
    end
    
    -- Get movement direction from flow field
    local moveDirX, moveDirY
    if self.flowField then
        moveDirX, moveDirY = self.flowField:getDirection(self.worldX, self.worldY, self.map)
    end
    
    -- Fall back to direct path if no flow field direction
    if not moveDirX or not moveDirY then
        local targetX, targetY = townHall:getWorldCenter()
        local dx = targetX - self.worldX
        local dy = targetY - self.worldY
        local dist = math.sqrt(dx * dx + dy * dy)
        if dist > 0.1 then
            moveDirX = dx / dist
            moveDirY = dy / dist
        else
            return 0, 0
        end
    end
    
    -- Movement
    local moveSpeed = self.speed * dt
    local moveX = moveDirX * moveSpeed
    local moveY = moveDirY * moveSpeed
    local newX = self.worldX + moveX
    local newY = self.worldY + moveY
    
    if self:canMoveTo(newX, newY, buildings) then
        self.worldX = newX
        self.worldY = newY
    else
        if self:canMoveTo(newX, self.worldY, buildings) then
            self.worldX = newX
        elseif self:canMoveTo(self.worldX, newY, buildings) then
            self.worldY = newY
        end
        -- If blocked, contact check will trigger next frame
    end
    
    return 0, 0
end

function Peon:finishBuilding()
    self.visible = true
    self.state = Peon.STATE_IDLE
    self.buildTargetX = nil
    self.buildTargetY = nil
    self.buildingType = nil
end

function Peon:draw()
    if not self.visible then return end
    
    local x, y = self:getScreenPos()
    
    if self.selected then
        love.graphics.setColor(0, 1, 0, 0.4)
        love.graphics.circle("fill", x, y, self.radius + 4)
        love.graphics.setColor(0, 1, 0, 0.8)
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", x, y, self.radius + 4)
    end
    
    if self.carryingGold > 0 then
        love.graphics.setColor(0.8, 0.65, 0.2, 1)
    elseif self.carryingLumber > 0 then
        love.graphics.setColor(0.5, 0.35, 0.2, 1)
    else
        love.graphics.setColor(0.3, 0.55, 0.3, 1)
    end
    love.graphics.circle("fill", x, y, self.radius)
    
    love.graphics.setColor(0.9, 0.75, 0.6, 1)
    love.graphics.circle("fill", x, y - 2, 7)
    
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.circle("fill", x - 3, y - 3, 2)
    love.graphics.circle("fill", x + 3, y - 3, 2)
    
    if self.carryingGold > 0 then
        love.graphics.setColor(1, 0.85, 0, 1)
        love.graphics.circle("fill", x + 8, y - 8, 5)
    elseif self.carryingLumber > 0 then
        love.graphics.setColor(0.6, 0.4, 0.2, 1)
        love.graphics.rectangle("fill", x + 4, y - 12, 8, 4)
    end
    
    love.graphics.setColor(1, 1, 1, 1)
end

function Peon:containsPoint(screenX, screenY)
    local x, y = self:getScreenPos()
    local dx = screenX - x
    local dy = screenY - y
    return (dx * dx + dy * dy) <= (self.radius + 4) * (self.radius + 4)
end

function Peon:isInBox(x1, y1, x2, y2)
    if not self.visible then return false end
    local sx, sy = self:getScreenPos()
    local minX, maxX = math.min(x1, x2), math.max(x1, x2)
    local minY, maxY = math.min(y1, y2), math.max(y1, y2)
    return sx >= minX and sx <= maxX and sy >= minY and sy <= maxY
end

function Peon:moveTo(worldX, worldY, flowField)
    self.targetX = worldX
    self.targetY = worldY
    self.targetMine = nil
    self.targetTreeX = nil
    self.targetTreeY = nil
    self.buildTargetX = nil
    self.buildTargetY = nil
    self.buildCallback = nil
    self.flowField = flowField
    self.state = Peon.STATE_MOVING
end

function Peon:goToMine(mine, flowField)
    self.targetMine = mine
    self.targetTreeX = nil
    self.targetTreeY = nil
    self.buildTargetX = nil
    self.buildTargetY = nil
    self.buildCallback = nil
    self.flowField = flowField
    -- Target the center - updateMoving will stop at the edge
    local cx, cy = mine:getWorldCenter()
    self.targetX = cx
    self.targetY = cy
    self.state = Peon.STATE_MOVING
end

function Peon:goToTree(gridX, gridY, flowField)
    self.targetTreeX = gridX
    self.targetTreeY = gridY
    self.targetMine = nil
    self.buildTargetX = nil
    self.buildTargetY = nil
    self.buildCallback = nil
    self.flowField = flowField
    if self.map then
        self.targetX, self.targetY = self.map:getTileWorldCenter(gridX, gridY)
    end
    self.state = Peon.STATE_MOVING
end

function Peon:goToBuild(gridX, gridY, buildingType, callback, flowField)
    self.buildTargetX = gridX
    self.buildTargetY = gridY
    self.buildingType = buildingType
    self.buildCallback = callback
    self.targetMine = nil
    self.targetTreeX = nil
    self.targetTreeY = nil
    self.flowField = flowField
    if self.map then
        self.targetX, self.targetY = self.map:gridToWorld(gridX, gridY)
        self.targetX = self.targetX + 16
        self.targetY = self.targetY + 16
    end
    self.state = Peon.STATE_MOVING
end

function Peon:getStateText()
    if self.state == Peon.STATE_RETURNING then
        if self.carryingGold > 0 then return "Carrying Gold"
        elseif self.carryingLumber > 0 then return "Carrying Lumber" end
    elseif self.state == Peon.STATE_CHOPPING then
        return "Chopping"
    elseif self.state == Peon.STATE_BUILDING then
        return "Building"
    end
    return self.state
end

function Peon:updateUI(resources, screenW, screenH, font, startBuildCallback)
    if self.selected and self.state ~= Peon.STATE_BUILDING then
        local panelX = screenW - 180
        local buttonY = 70 + 145
        
        local Farm = require("farm")
        local Barracks = require("barracks")
        
        if not self.buildFarmButton then
            self.buildFarmButton = Button.new({
                x = panelX + 10, y = buttonY, width = 150, height = 35,
                text = "Farm (250g 50l)", font = font,
                colors = {
                    normal = {0.3, 0.5, 0.35, 1}, hover = {0.4, 0.6, 0.45, 1},
                    pressed = {0.2, 0.4, 0.25, 1}, text = {1, 1, 1, 1}, border = {0.2, 0.4, 0.25, 1}
                },
                onClick = function()
                    if startBuildCallback then startBuildCallback(self, "farm") end
                end
            })
        end
        
        if not self.buildBarracksButton then
            self.buildBarracksButton = Button.new({
                x = panelX + 10, y = buttonY + 40, width = 150, height = 35,
                text = "Barracks (400g 100l)", font = font,
                colors = {
                    normal = {0.5, 0.35, 0.35, 1}, hover = {0.6, 0.45, 0.45, 1},
                    pressed = {0.4, 0.25, 0.25, 1}, text = {1, 1, 1, 1}, border = {0.4, 0.25, 0.25, 1}
                },
                onClick = function()
                    if startBuildCallback then startBuildCallback(self, "barracks") end
                end
            })
        end
        
        local canFarm = resources.gold >= Farm.COST_GOLD and resources.lumber >= Farm.COST_LUMBER
        local canBarracks = resources.gold >= Barracks.COST_GOLD and resources.lumber >= Barracks.COST_LUMBER
        
        self.buildFarmButton:setEnabled(canFarm and self.state == Peon.STATE_IDLE)
        self.buildBarracksButton:setEnabled(canBarracks and self.state == Peon.STATE_IDLE)
        self.buildFarmButton:update(0)
        self.buildBarracksButton:update(0)
    else
        self.buildFarmButton = nil
        self.buildBarracksButton = nil
    end
end

function Peon:drawUI()
    if self.selected and self.state ~= Peon.STATE_BUILDING then
        if self.buildFarmButton then self.buildFarmButton:draw() end
        if self.buildBarracksButton then self.buildBarracksButton:draw() end
    end
end

function Peon:mousepressed(x, y, button)
    if self.buildFarmButton then self.buildFarmButton:mousepressed(x, y, button) end
    if self.buildBarracksButton then self.buildBarracksButton:mousepressed(x, y, button) end
end

function Peon:mousereleased(x, y, button)
    if self.buildFarmButton then self.buildFarmButton:mousereleased(x, y, button) end
    if self.buildBarracksButton then self.buildBarracksButton:mousereleased(x, y, button) end
end

function Peon:drawOnMinimap(mapX, mapY, scale)
    if not self.visible then return end
    love.graphics.setColor(0.3, 0.8, 0.3, 1)
    local gridX, gridY = 1, 1
    if self.map then
        gridX, gridY = self.map:worldToGrid(self.worldX, self.worldY)
    end
    local x = mapX + (gridX - 0.5) * scale
    local y = mapY + (gridY - 0.5) * scale
    love.graphics.circle("fill", x, y, math.max(2, scale * 0.5))
end

return Peon
