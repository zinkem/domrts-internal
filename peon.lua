--[[
    Peon
    Worker unit that moves and harvests gold
    Size: 1x1 tile, free movement (not grid-aligned), circular collision
]]

local Peon = {}
Peon.__index = Peon

-- States
Peon.STATE_IDLE = "Idle"
Peon.STATE_MOVING = "Moving"
Peon.STATE_HARVESTING = "Harvesting"
Peon.STATE_RETURNING = "Returning"

Peon.RADIUS = 12  -- Circular collision radius

function Peon.new(params)
    local self = setmetatable({}, Peon)
    
    -- World position (pixels, not grid-aligned)
    self.worldX = params.worldX or 0
    self.worldY = params.worldY or 0
    
    -- Map reference
    self.map = params.map
    
    -- Collision
    self.radius = Peon.RADIUS
    
    self.speed = 120  -- Pixels per second
    self.selected = false
    self.type = "peon"
    self.name = "Peon"
    
    -- State machine
    self.state = Peon.STATE_IDLE
    
    -- Movement target (world pixels)
    self.targetX = nil
    self.targetY = nil
    
    -- Harvesting
    self.carryingGold = 0
    self.harvestAmount = 10
    self.harvestTime = 1.0
    self.harvestTimer = 0
    self.targetMine = nil
    self.targetTownHall = nil
    self.visible = true
    
    return self
end

function Peon:getScreenPos()
    if self.map then
        return self.map:worldToScreen(self.worldX, self.worldY)
    end
    return self.worldX, self.worldY
end

function Peon:update(dt, townHall)
    local goldDeposited = 0
    
    if self.state == Peon.STATE_MOVING then
        self:updateMoving(dt)
    elseif self.state == Peon.STATE_HARVESTING then
        self:updateHarvesting(dt)
    elseif self.state == Peon.STATE_RETURNING then
        goldDeposited = self:updateReturning(dt, townHall)
    end
    
    return goldDeposited
end

function Peon:updateMoving(dt)
    if not self.targetX or not self.targetY then
        self.state = Peon.STATE_IDLE
        return
    end
    
    local dx = self.targetX - self.worldX
    local dy = self.targetY - self.worldY
    local dist = math.sqrt(dx * dx + dy * dy)
    
    -- Check arrival
    local arriveThreshold = 8
    if self.targetMine then
        arriveThreshold = self.targetMine.pixelSize / 2 + self.radius
    end
    
    if dist <= arriveThreshold then
        if self.targetMine and not self.targetMine.depleted then
            self.state = Peon.STATE_HARVESTING
            self.harvestTimer = 0
            self.visible = false
        else
            self.state = Peon.STATE_IDLE
            self.targetX = nil
            self.targetY = nil
            self.targetMine = nil
        end
        return
    end
    
    -- Move toward target
    local moveX = (dx / dist) * self.speed * dt
    local moveY = (dy / dist) * self.speed * dt
    
    -- Check collision with trees
    local newX = self.worldX + moveX
    local newY = self.worldY + moveY
    
    if self.map and self.map:isWorldPosPassable(newX, newY) then
        self.worldX = newX
        self.worldY = newY
    else
        -- Try sliding along obstacles
        if self.map:isWorldPosPassable(newX, self.worldY) then
            self.worldX = newX
        elseif self.map:isWorldPosPassable(self.worldX, newY) then
            self.worldY = newY
        end
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

function Peon:updateReturning(dt, townHall)
    if not townHall then
        self.state = Peon.STATE_IDLE
        return 0
    end
    
    self.targetTownHall = townHall
    local targetX, targetY = townHall:getWorldCenter()
    
    local dx = targetX - self.worldX
    local dy = targetY - self.worldY
    local dist = math.sqrt(dx * dx + dy * dy)
    
    local arriveThreshold = townHall.pixelSize / 2 + self.radius
    
    if dist <= arriveThreshold then
        -- Deposit gold
        local deposited = self.carryingGold
        self.carryingGold = 0
        
        -- Return to mine
        if self.targetMine and not self.targetMine.depleted then
            self:goToMine(self.targetMine)
        else
            self.state = Peon.STATE_IDLE
            self.targetMine = nil
        end
        
        return deposited
    end
    
    -- Move toward town hall
    local moveX = (dx / dist) * self.speed * dt
    local moveY = (dy / dist) * self.speed * dt
    
    local newX = self.worldX + moveX
    local newY = self.worldY + moveY
    
    if self.map and self.map:isWorldPosPassable(newX, newY) then
        self.worldX = newX
        self.worldY = newY
    else
        if self.map:isWorldPosPassable(newX, self.worldY) then
            self.worldX = newX
        elseif self.map:isWorldPosPassable(self.worldX, newY) then
            self.worldY = newY
        end
    end
    
    return 0
end

function Peon:draw()
    if not self.visible then
        return
    end
    
    local x, y = self:getScreenPos()
    
    -- Selection circle
    if self.selected then
        love.graphics.setColor(0, 1, 0, 0.4)
        love.graphics.circle("fill", x, y, self.radius + 4)
        love.graphics.setColor(0, 1, 0, 0.8)
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", x, y, self.radius + 4)
    end
    
    -- Body
    if self.carryingGold > 0 then
        love.graphics.setColor(0.8, 0.65, 0.2, 1)
    else
        love.graphics.setColor(0.3, 0.55, 0.3, 1)
    end
    love.graphics.circle("fill", x, y, self.radius)
    
    -- Face
    love.graphics.setColor(0.9, 0.75, 0.6, 1)
    love.graphics.circle("fill", x, y - 2, 7)
    
    -- Eyes
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.circle("fill", x - 3, y - 3, 2)
    love.graphics.circle("fill", x + 3, y - 3, 2)
    
    -- Gold indicator
    if self.carryingGold > 0 then
        love.graphics.setColor(1, 0.85, 0, 1)
        love.graphics.circle("fill", x + 8, y - 8, 5)
    end
    
    love.graphics.setColor(1, 1, 1, 1)
end

-- Circular collision check (screen coordinates)
function Peon:containsPoint(screenX, screenY)
    local x, y = self:getScreenPos()
    local dx = screenX - x
    local dy = screenY - y
    return (dx * dx + dy * dy) <= (self.radius + 4) * (self.radius + 4)
end

function Peon:moveTo(worldX, worldY)
    self.targetX = worldX
    self.targetY = worldY
    self.targetMine = nil
    self.state = Peon.STATE_MOVING
end

function Peon:goToMine(mine)
    self.targetMine = mine
    local cx, cy = mine:getWorldCenter()
    self.targetX = cx
    self.targetY = cy
    self.state = Peon.STATE_MOVING
end

function Peon:getStateText()
    if self.state == Peon.STATE_RETURNING and self.carryingGold > 0 then
        return "Carrying Gold"
    end
    return self.state
end

-- UI Methods (no actions for peon)
function Peon:updateUI(resources, screenW, screenH, font)
end

function Peon:drawUI()
end

function Peon:mousepressed(x, y, button)
end

function Peon:mousereleased(x, y, button)
end

-- Minimap drawing
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
