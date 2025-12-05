--[[
    Peon
    Worker unit that can move and harvest gold
]]

local Peon = {}
Peon.__index = Peon

-- States
Peon.STATE_IDLE = "Idle"
Peon.STATE_MOVING = "Moving"
Peon.STATE_HARVESTING = "Harvesting"
Peon.STATE_RETURNING = "Returning"

function Peon.new(params)
    local self = setmetatable({}, Peon)
    
    self.x = params.x or 0
    self.y = params.y or 0
    self.width = 24
    self.height = 24
    self.speed = 100
    self.selected = false
    self.type = "peon"
    self.name = "Peon"
    
    -- State machine
    self.state = Peon.STATE_IDLE
    
    -- Movement
    self.targetX = nil
    self.targetY = nil
    self.arrivalThreshold = 8
    
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

function Peon:update(dt, townHall)
    local goldDeposited = 0
    
    if self.state == Peon.STATE_MOVING then
        goldDeposited = self:updateMoving(dt)
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
        return 0
    end
    
    local dx = self.targetX - self.x
    local dy = self.targetY - self.y
    local dist = math.sqrt(dx * dx + dy * dy)
    
    if dist <= self.arrivalThreshold then
        self.x = self.targetX
        self.y = self.targetY
        
        -- Check if we arrived at a mine
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
        return 0
    end
    
    local moveX = (dx / dist) * self.speed * dt
    local moveY = (dy / dist) * self.speed * dt
    
    self.x = self.x + moveX
    self.y = self.y + moveY
    
    return 0
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
    local targetX = townHall:getCenterX()
    local targetY = townHall:getCenterY()
    
    local dx = targetX - self.x
    local dy = targetY - self.y
    local dist = math.sqrt(dx * dx + dy * dy)
    
    if dist <= townHall.width / 2 + 15 then
        -- Arrived at town hall, deposit gold
        local deposited = self.carryingGold
        self.carryingGold = 0
        
        -- Return to mine if it still has gold
        if self.targetMine and not self.targetMine.depleted then
            self:goToMine(self.targetMine)
        else
            self.state = Peon.STATE_IDLE
            self.targetMine = nil
        end
        
        return deposited
    end
    
    local moveX = (dx / dist) * self.speed * dt
    local moveY = (dy / dist) * self.speed * dt
    
    self.x = self.x + moveX
    self.y = self.y + moveY
    
    return 0
end

function Peon:draw()
    if not self.visible then
        return
    end
    
    -- Draw selection circle
    if self.selected then
        love.graphics.setColor(0, 1, 0, 0.4)
        love.graphics.circle("fill", self.x, self.y + 2, self.width / 2 + 4)
        love.graphics.setColor(0, 1, 0, 0.8)
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", self.x, self.y + 2, self.width / 2 + 4)
    end
    
    -- Draw peon body
    if self.carryingGold > 0 then
        love.graphics.setColor(0.8, 0.65, 0.2, 1) -- Gold tint when carrying
    else
        love.graphics.setColor(0.3, 0.55, 0.3, 1) -- Normal green
    end
    love.graphics.rectangle("fill", self.x - self.width / 2, self.y - self.height / 2, self.width, self.height, 4)
    
    -- Draw face
    love.graphics.setColor(0.9, 0.75, 0.6, 1)
    love.graphics.circle("fill", self.x, self.y - 4, 8)
    
    -- Draw eyes
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.circle("fill", self.x - 3, self.y - 5, 2)
    love.graphics.circle("fill", self.x + 3, self.y - 5, 2)
    
    -- Draw gold icon if carrying
    if self.carryingGold > 0 then
        love.graphics.setColor(1, 0.85, 0, 1)
        love.graphics.circle("fill", self.x + 10, self.y - 10, 5)
        love.graphics.setColor(0.8, 0.65, 0, 1)
        love.graphics.setLineWidth(1)
        love.graphics.circle("line", self.x + 10, self.y - 10, 5)
    end
    
    love.graphics.setColor(1, 1, 1, 1)
end

function Peon:containsPoint(px, py)
    local halfW = self.width / 2 + 4
    local halfH = self.height / 2 + 4
    return px >= self.x - halfW and px <= self.x + halfW and
           py >= self.y - halfH and py <= self.y + halfH
end

function Peon:moveTo(x, y)
    self.targetX = x
    self.targetY = y
    self.targetMine = nil
    self.state = Peon.STATE_MOVING
end

function Peon:goToMine(mine)
    self.targetMine = mine
    self.targetX = mine:getCenterX()
    self.targetY = mine:getCenterY()
    self.state = Peon.STATE_MOVING
end

function Peon:getStateText()
    if self.state == Peon.STATE_RETURNING and self.carryingGold > 0 then
        return "Carrying Gold"
    end
    return self.state
end

return Peon
