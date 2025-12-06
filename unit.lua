--[[
    Unit Base Class
    Shared functionality for all mobile units
    Includes: movement, combat stats, health bar, attack logic
]]

local Pathfinding = require("pathfinding")

-- Team colors module
local Teams
pcall(function() Teams = require("teams") end)

-- Visual effects (optional)
local Effects
pcall(function() Effects = require("effects") end)

local Unit = {}
Unit.__index = Unit

-- Default stats (overridden by subclasses)
Unit.RADIUS = 14
Unit.SPEED = 60

function Unit.new(params)
    local self = setmetatable({}, Unit)
    
    self.worldX = params.worldX or 0
    self.worldY = params.worldY or 0
    self.map = params.map
    self.radius = Unit.RADIUS
    self.speed = Unit.SPEED
    self.selected = false
    self.type = "unit"
    self.name = "Unit"
    self.state = "Idle"
    
    -- Team ownership
    self.team = params.team or (Teams and Teams.PLAYER or 1)
    self.owner = params.owner or nil
    
    -- Combat stats (defaults - subclasses override these)
    self.maxHp = params.maxHp or 3
    self.hp = self.maxHp
    self.damage = params.damage or 1
    self.attackSpeed = params.attackSpeed or 1.0  -- Attacks per second
    self.attackCooldown = 0
    self.sightRadius = params.sightRadius or 2  -- Tiles
    self.attackTarget = nil
    self.isAttacking = false
    
    -- Movement
    self.targetX = nil
    self.targetY = nil
    self.path = nil
    self.currentWaypoint = 1
    
    -- Visual
    self.flashTimer = 0
    
    return self
end

function Unit:getScreenPos()
    if self.map then
        return self.map:worldToScreen(self.worldX, self.worldY)
    end
    return self.worldX, self.worldY
end

function Unit:containsPoint(screenX, screenY)
    local x, y = self:getScreenPos()
    local dx = screenX - x
    local dy = screenY - y
    return (dx * dx + dy * dy) <= (self.radius + 4) * (self.radius + 4)
end

function Unit:isInBox(x1, y1, x2, y2)
    local sx, sy = self:getScreenPos()
    local minX, maxX = math.min(x1, x2), math.max(x1, x2)
    local minY, maxY = math.min(y1, y2), math.max(y1, y2)
    return sx >= minX and sx <= maxX and sy >= minY and sy <= maxY
end

-- Combat Methods --

function Unit:setAttackTarget(target)
    self.attackTarget = target
    self.state = "Attacking"
    self.path = nil
end

function Unit:getAttackRange()
    return self.radius + 20  -- Melee range
end

function Unit:getSightRangePixels()
    return self.sightRadius * 32  -- Convert tiles to pixels
end

function Unit:distanceTo(target)
    local tx, ty
    if target.getWorldCenter then
        tx, ty = target:getWorldCenter()
    else
        tx, ty = target.worldX, target.worldY
    end
    local dx = tx - self.worldX
    local dy = ty - self.worldY
    return math.sqrt(dx * dx + dy * dy)
end

function Unit:updateAttacking(dt, buildings, allUnits, allBuildings)
    -- Check if target is dead or gone
    if not self.attackTarget or (self.attackTarget.isDead and self.attackTarget:isDead()) then
        self.attackTarget = nil
        self.state = "Idle"
        -- Try to find new target
        self:checkForEnemies(allUnits, allBuildings)
        return
    end
    
    local target = self.attackTarget
    local dist = self:distanceTo(target)
    local attackRange = self:getAttackRange()
    
    if dist <= attackRange then
        -- In range - attack if cooldown ready
        if self.attackCooldown <= 0 then
            -- Perform attack
            if target.takeDamage then
                target:takeDamage(self.damage)
                self.attackCooldown = 1.0 / self.attackSpeed
                
                -- Visual effects
                if Effects then
                    local tx = target.worldX or (target.getWorldCenter and select(1, target:getWorldCenter()))
                    local ty = target.worldY or (target.getWorldCenter and select(2, target:getWorldCenter()))
                    if tx and ty then
                        Effects.blood(tx, ty)
                    end
                end
            end
        end
    else
        -- Move toward target
        local tx, ty
        if target.getWorldCenter then
            tx, ty = target:getWorldCenter()
        else
            tx, ty = target.worldX, target.worldY
        end
        
        -- Compute path if needed
        if not self.path then
            self.targetX = tx
            self.targetY = ty
            self.path = Pathfinding.findPath(self.worldX, self.worldY, tx, ty, buildings, self.map, self.radius)
            self.currentWaypoint = 1
        end
        
        -- Move along path
        if self.path then
            local dirX, dirY = Pathfinding.getDirection(self.worldX, self.worldY, self.path, self.currentWaypoint)
            if dirX then
                -- Check if reached waypoint
                if Pathfinding.reachedWaypoint(self.worldX, self.worldY, self.path, self.currentWaypoint, 12) then
                    self.currentWaypoint = self.currentWaypoint + 1
                end
                
                local moveSpeed = self.speed * dt
                local newX = self.worldX + dirX * moveSpeed
                local newY = self.worldY + dirY * moveSpeed
                
                -- Simple collision check
                if self.map and self.map:isWorldPosPassable(newX, newY) then
                    self.worldX = newX
                    self.worldY = newY
                end
            end
        end
    end
end

function Unit:checkForEnemies(allUnits, allBuildings)
    local sightRange = self:getSightRangePixels()
    local myTeam = self.team
    
    -- Check units first
    if allUnits then
        for _, unit in ipairs(allUnits) do
            if unit ~= self and unit.team and unit.team ~= myTeam and unit.hp and unit.hp > 0 then
                local dist = self:distanceTo(unit)
                if dist <= sightRange then
                    self:setAttackTarget(unit)
                    return
                end
            end
        end
    end
    
    -- Check buildings
    if allBuildings then
        for _, building in ipairs(allBuildings) do
            if building.team and building.team ~= myTeam and building.hp and building.hp > 0 then
                local dist = self:distanceTo(building)
                if dist <= sightRange then
                    self:setAttackTarget(building)
                    return
                end
            end
        end
    end
end

function Unit:takeDamage(amount)
    self.hp = self.hp - amount
    self.flashTimer = 0.1
end

function Unit:isDead()
    return self.hp <= 0
end

function Unit:drawHealthBar()
    if not self.selected and self.hp >= self.maxHp then return end
    
    local x, y = self:getScreenPos()
    local barWidth = 24
    local barHeight = 4
    local segmentWidth = barWidth / self.maxHp
    local barX = x - barWidth / 2
    local barY = y - 28
    
    -- Background
    love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
    love.graphics.rectangle("fill", barX - 1, barY - 1, barWidth + 2, barHeight + 2)
    
    -- Health segments
    for i = 1, self.maxHp do
        local segX = barX + (i - 1) * segmentWidth
        if i <= self.hp then
            -- Filled segment - green to red based on health
            local healthPct = self.hp / self.maxHp
            love.graphics.setColor(1 - healthPct, healthPct, 0.2, 1)
        else
            -- Empty segment
            love.graphics.setColor(0.4, 0.1, 0.1, 0.6)
        end
        love.graphics.rectangle("fill", segX + 0.5, barY, segmentWidth - 1, barHeight)
    end
    
    -- Border
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", barX - 1, barY - 1, barWidth + 2, barHeight + 2)
end

function Unit:update(dt, buildings, allUnits, allBuildings)
    -- Update attack cooldown
    if self.attackCooldown > 0 then
        self.attackCooldown = self.attackCooldown - dt
    end
    
    -- Update flash timer
    if self.flashTimer and self.flashTimer > 0 then
        self.flashTimer = self.flashTimer - dt
    end
    
    if self.state == "Attacking" then
        self:updateAttacking(dt, buildings, allUnits, allBuildings)
    elseif self.state == "Moving" then
        self:updateMoving(dt, buildings)
    elseif self.state == "Idle" then
        -- Auto-acquire targets
        self:checkForEnemies(allUnits, allBuildings)
    end
end

function Unit:updateMoving(dt, buildings)
    if not self.targetX or not self.targetY then
        self.state = "Idle"
        return
    end
    
    -- Check if reached target
    local dx = self.targetX - self.worldX
    local dy = self.targetY - self.worldY
    local dist = math.sqrt(dx * dx + dy * dy)
    
    if dist < 5 then
        self.state = "Idle"
        self.targetX = nil
        self.targetY = nil
        self.path = nil
        return
    end
    
    -- Compute path if needed
    if not self.path then
        self.path = Pathfinding.findPath(self.worldX, self.worldY, self.targetX, self.targetY, buildings, self.map, self.radius)
        self.currentWaypoint = 1
    end
    
    -- Move along path
    if self.path then
        local dirX, dirY = Pathfinding.getDirection(self.worldX, self.worldY, self.path, self.currentWaypoint)
        if dirX then
            if Pathfinding.reachedWaypoint(self.worldX, self.worldY, self.path, self.currentWaypoint, 12) then
                self.currentWaypoint = self.currentWaypoint + 1
            end
            
            local moveSpeed = self.speed * dt
            local newX = self.worldX + dirX * moveSpeed
            local newY = self.worldY + dirY * moveSpeed
            
            if self.map and self.map:isWorldPosPassable(newX, newY) then
                self.worldX = newX
                self.worldY = newY
            end
        end
    end
end

function Unit:moveTo(worldX, worldY)
    self.targetX = worldX
    self.targetY = worldY
    self.attackTarget = nil
    self.state = "Moving"
    self.path = nil
    self.currentWaypoint = 1
end

function Unit:drawOnMinimap(mapX, mapY, scale)
    -- Use team color
    if Teams then
        Teams.setColor(self.team, "minimapUnit")
    else
        love.graphics.setColor(0.5, 0.5, 0.5, 1)
    end
    
    local mmX = mapX + self.worldX * scale
    local mmY = mapY + self.worldY * scale
    love.graphics.circle("fill", mmX, mmY, math.max(2, 3))
end

return Unit
