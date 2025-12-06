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
    self.sightRadius = params.sightRadius or 5  -- Tiles - decent vision range
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
    return self.radius + 4  -- Tight melee range (about 18 pixels)
end

function Unit:getSightRangePixels()
    return self.sightRadius * 32  -- Convert tiles to pixels
end

-- Get separation force from nearby units (pushes units apart when overlapping)
-- This is the standard industry approach (Starcraft, Warcraft)
function Unit:getUnitSeparation(allUnits)
    local sepX, sepY = 0, 0
    local separationDist = self.radius * 2.5  -- Start separating when within ~2.5 radii
    
    if not allUnits then return 0, 0 end
    
    for _, other in ipairs(allUnits) do
        if other ~= self and other.worldX and other.worldY then
            local dx = self.worldX - other.worldX
            local dy = self.worldY - other.worldY
            local dist = math.sqrt(dx * dx + dy * dy)
            local minDist = self.radius + (other.radius or 14)
            
            if dist < separationDist and dist > 0.1 then
                -- Push away from other unit proportional to how close we are
                local force = (separationDist - dist) / separationDist
                sepX = sepX + (dx / dist) * force
                sepY = sepY + (dy / dist) * force
            elseif dist < 0.1 then
                -- Exactly overlapping, push in random direction
                local angle = math.random() * math.pi * 2
                sepX = sepX + math.cos(angle)
                sepY = sepY + math.sin(angle)
            end
        end
    end
    
    -- Normalize if too strong
    local len = math.sqrt(sepX * sepX + sepY * sepY)
    if len > 1 then
        sepX = sepX / len
        sepY = sepY / len
    end
    
    return sepX, sepY
end

-- Simple movement along path - paths are pre-validated by A*
-- Only checks terrain as a safety net
function Unit:moveToward(targetX, targetY, dt, allUnits)
    local dx = targetX - self.worldX
    local dy = targetY - self.worldY
    local dist = math.sqrt(dx * dx + dy * dy)
    
    if dist < 1 then return end
    
    local dirX = dx / dist
    local dirY = dy / dist
    
    -- Apply unit-unit separation
    local sepX, sepY = self:getUnitSeparation(allUnits)
    local sepStrength = 0.3
    
    dirX = dirX + sepX * sepStrength
    dirY = dirY + sepY * sepStrength
    
    -- Re-normalize
    local len = math.sqrt(dirX * dirX + dirY * dirY)
    if len > 0.1 then
        dirX = dirX / len
        dirY = dirY / len
    end
    
    local moveSpeed = self.speed * dt
    local newX = self.worldX + dirX * moveSpeed
    local newY = self.worldY + dirY * moveSpeed
    
    -- Safety check - don't walk into trees
    if self.map and self.map:isWorldPosPassable(newX, newY) then
        self.worldX = newX
        self.worldY = newY
    elseif self.map then
        -- Try axis-aligned movement as fallback
        if self.map:isWorldPosPassable(newX, self.worldY) then
            self.worldX = newX
        elseif self.map:isWorldPosPassable(self.worldX, newY) then
            self.worldY = newY
        end
    else
        self.worldX = newX
        self.worldY = newY
    end
end

function Unit:distanceTo(target)
    local tx, ty
    
    -- For buildings, calculate distance to nearest edge, not center
    if target.getWorldBounds then
        local bx1, by1, bx2, by2 = target:getWorldBounds()
        -- Find closest point on building bounds to unit
        local closestX = math.max(bx1, math.min(self.worldX, bx2))
        local closestY = math.max(by1, math.min(self.worldY, by2))
        local dx = closestX - self.worldX
        local dy = closestY - self.worldY
        return math.sqrt(dx * dx + dy * dy)
    elseif target.getWorldCenter then
        tx, ty = target:getWorldCenter()
    else
        tx, ty = target.worldX, target.worldY
    end
    
    -- Calculate center-to-center distance
    local dx = tx - self.worldX
    local dy = ty - self.worldY
    local centerDist = math.sqrt(dx * dx + dy * dy)
    
    -- Subtract target's radius to get edge-to-center distance
    local targetRadius = target.radius or 0
    return math.max(0, centerDist - targetRadius)
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
        -- In range - stop moving and attack if cooldown ready
        self.path = nil
        self.targetX = nil
        self.targetY = nil
        
        if self.attackCooldown <= 0 then
            -- Perform attack
            if target.takeDamage then
                target:takeDamage(self.damage)
                self.attackCooldown = 1.0 / self.attackSpeed
                self.lastAttackHit = true  -- Flag for animation
                
                -- Visual effects
                if Effects then
                    -- Damage flash on target
                    Effects.damageFlash(target)
                    
                    -- Blood particles
                    local tx = target.worldX or (target.getWorldCenter and select(1, target:getWorldCenter()))
                    local ty = target.worldY or (target.getWorldCenter and select(2, target:getWorldCenter()))
                    if tx and ty then
                        Effects.blood(tx, ty)
                    end
                end
            end
        end
    else
        -- Not in range - move toward target
        local tx, ty
        if target.getWorldCenter then
            tx, ty = target:getWorldCenter()
        else
            tx, ty = target.worldX, target.worldY
        end
        
        -- Compute path if needed (or if target moved significantly)
        local needNewPath = not self.path
        if self.targetX and self.targetY then
            local targetMoved = math.abs(tx - self.targetX) > 32 or math.abs(ty - self.targetY) > 32
            if targetMoved then needNewPath = true end
        end
        
        if needNewPath then
            self.targetX = tx
            self.targetY = ty
            self.path = Pathfinding.findPath(self.worldX, self.worldY, tx, ty, self.radius)
            self.currentWaypoint = 1
        end
        
        -- Move along path
        if self.path and self.currentWaypoint <= #self.path then
            local wp = self.path[self.currentWaypoint]
            
            -- Check if reached waypoint
            if Pathfinding.reachedWaypoint(self.worldX, self.worldY, self.path, self.currentWaypoint, 8) then
                self.currentWaypoint = self.currentWaypoint + 1
            end
            
            if self.currentWaypoint <= #self.path then
                wp = self.path[self.currentWaypoint]
                self:moveToward(wp.x, wp.y, dt, allUnits)
            end
        else
            -- No path or reached end - move directly toward target
            self:moveToward(tx, ty, dt, allUnits)
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
    
    -- Stuck detection - track position history
    self.stuckTimer = (self.stuckTimer or 0) + dt
    if self.stuckTimer >= 0.5 then
        self.stuckTimer = 0
        
        -- Store position history (keep last 4 samples = 2 seconds)
        self.posHistory = self.posHistory or {}
        table.insert(self.posHistory, {x = self.worldX, y = self.worldY})
        if #self.posHistory > 4 then
            table.remove(self.posHistory, 1)
        end
        
        -- Check if stuck (not moving but should be)
        if #self.posHistory >= 4 and (self.state == "Moving" or self.state == "Attacking" or self.state == "AttackMoving") then
            local oldPos = self.posHistory[1]
            local dx = self.worldX - oldPos.x
            local dy = self.worldY - oldPos.y
            local movedDist = math.sqrt(dx * dx + dy * dy)
            
            -- If moved less than 5 pixels in 2 seconds while trying to move, we're stuck
            if movedDist < 5 then
                -- Just clear path to force recalculation - don't nudge randomly
                self.path = nil
                self.posHistory = {}
                
                -- If attacking and stuck, just stop - we're probably as close as we can get
                if self.state == "Attacking" and self.attackTarget then
                    -- Stay in attacking state, let attack logic handle it
                end
            end
        end
    end
    
    if self.state == "Attacking" then
        self:updateAttacking(dt, buildings, allUnits, allBuildings)
    elseif self.state == "Moving" then
        self:updateMoving(dt, buildings, allUnits)
    elseif self.state == "AttackMoving" then
        self:updateAttackMoving(dt, buildings, allUnits, allBuildings)
    elseif self.state == "Idle" then
        -- Auto-acquire targets
        self:checkForEnemies(allUnits, allBuildings)
    end
end

function Unit:updateMoving(dt, buildings, allUnits)
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
        self.path = Pathfinding.findPath(self.worldX, self.worldY, self.targetX, self.targetY, self.radius)
        self.currentWaypoint = 1
    end
    
    -- Move along path
    if self.path and self.currentWaypoint <= #self.path then
        local wp = self.path[self.currentWaypoint]
        
        if Pathfinding.reachedWaypoint(self.worldX, self.worldY, self.path, self.currentWaypoint, 8) then
            self.currentWaypoint = self.currentWaypoint + 1
        end
        
        if self.currentWaypoint <= #self.path then
            wp = self.path[self.currentWaypoint]
            self:moveToward(wp.x, wp.y, dt, allUnits)
        end
    else
        -- No path or reached end - move directly toward target
        self:moveToward(self.targetX, self.targetY, dt, allUnits)
    end
end

function Unit:updateAttackMoving(dt, buildings, allUnits, allBuildings)
    -- Attack-move: move toward destination but attack any enemies in range
    
    -- First check for enemies in sight range
    local sightRange = self:getSightRangePixels()
    local myTeam = self.team
    local foundEnemy = nil
    
    -- Check units
    if allUnits then
        for _, unit in ipairs(allUnits) do
            if unit ~= self and unit.team and unit.team ~= myTeam and unit.hp and unit.hp > 0 then
                local dist = self:distanceTo(unit)
                if dist <= sightRange then
                    foundEnemy = unit
                    break
                end
            end
        end
    end
    
    -- Check buildings if no unit found
    if not foundEnemy and allBuildings then
        for _, building in ipairs(allBuildings) do
            if building.team and building.team ~= myTeam and building.hp and building.hp > 0 then
                local dist = self:distanceTo(building)
                if dist <= sightRange then
                    foundEnemy = building
                    break
                end
            end
        end
    end
    
    -- If enemy found, switch to attacking
    if foundEnemy then
        self:setAttackTarget(foundEnemy)
        return
    end
    
    -- Otherwise, continue moving to destination
    if not self.targetX or not self.targetY then
        self.state = "Idle"
        return
    end
    
    -- Check if reached destination
    local dx = self.targetX - self.worldX
    local dy = self.targetY - self.worldY
    local dist = math.sqrt(dx * dx + dy * dy)
    
    if dist < 10 then
        self.state = "Idle"
        self.targetX = nil
        self.targetY = nil
        self.path = nil
        self.attackMoveTarget = nil
        return
    end
    
    -- Move toward target
    if not self.path then
        self.path = Pathfinding.findPath(self.worldX, self.worldY, self.targetX, self.targetY, self.radius)
        self.currentWaypoint = 1
    end
    
    if self.path and self.currentWaypoint <= #self.path then
        local wp = self.path[self.currentWaypoint]
        
        if Pathfinding.reachedWaypoint(self.worldX, self.worldY, self.path, self.currentWaypoint, 8) then
            self.currentWaypoint = self.currentWaypoint + 1
        end
        
        if self.currentWaypoint <= #self.path then
            wp = self.path[self.currentWaypoint]
            self:moveToward(wp.x, wp.y, dt, allUnits)
        end
    else
        -- No path - move directly toward target
        self:moveToward(self.targetX, self.targetY, dt, allUnits)
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

function Unit:attackMoveTo(worldX, worldY)
    -- Move to target, but stay aggressive (attack enemies on the way)
    self.targetX = worldX
    self.targetY = worldY
    self.attackTarget = nil
    self.state = "AttackMoving"
    self.path = nil
    self.currentWaypoint = 1
    self.attackMoveTarget = {x = worldX, y = worldY}  -- Remember destination
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
