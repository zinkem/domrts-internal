--[[
    Peon
    Worker unit that moves, harvests gold, and builds structures
    Size: 1x1 tile, free movement (not grid-aligned), circular collision
    
    ENHANCED: Now includes visual effects, outlines, and animations
]]

local Button = require("button")
local Pathfinding = require("pathfinding")
local Requirements = require("requirements")

-- Team colors module
local Teams
pcall(function() Teams = require("teams") end)

-- Visual enhancement modules (optional - graceful fallback if missing)
local Effects, DrawUtils
pcall(function() Effects = require("effects") end)
pcall(function() DrawUtils = require("draw_utils") end)

local Peon = {}
Peon.__index = Peon

-- States
Peon.STATE_IDLE = "Idle"
Peon.STATE_MOVING = "Moving"
Peon.STATE_HARVESTING = "Harvesting"
Peon.STATE_RETURNING = "Returning"
Peon.STATE_CHOPPING = "Chopping"
Peon.STATE_BUILDING = "Building"
Peon.STATE_ATTACKING = "Attacking"

Peon.RADIUS = 14  -- Fits inside 1 tile (32x32 pixels)

function Peon.new(params)
    local self = setmetatable({}, Peon)
    
    self.worldX = params.worldX or 0
    self.worldY = params.worldY or 0
    self.map = params.map
    self.radius = Peon.RADIUS
    self.speed = 60
    self.selected = false
    self.type = "peon"
    self.name = "Peon"
    self.state = Peon.STATE_IDLE
    
    -- Team ownership
    self.team = params.team or (Teams and Teams.PLAYER or 1)
    self.owner = params.owner or nil  -- Reference to Player object
    
    -- Combat stats
    self.maxHp = 4
    self.hp = self.maxHp
    self.damage = 1
    self.attackSpeed = 1.0  -- Attacks per second
    self.attackCooldown = 0
    self.sightRadius = 5  -- Tiles
    self.attackTarget = nil
    self.isAttacking = false
    
    self.targetX = nil
    self.targetY = nil
    self.path = nil  -- List of waypoints {x, y}
    self.currentWaypoint = 1
    
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
    self.returnToStumpX = nil  -- For returning to stump when no adjacent tree
    self.returnToStumpY = nil
    self.goIdleAtTarget = nil  -- Flag to go idle when reaching movement target
    
    -- Animation
    self.animTimer = 0
    
    -- Visual effects tracking
    self.lastWorldX = self.worldX
    self.lastWorldY = self.worldY
    self.dustTimer = 0          -- Cooldown for dust particles
    self.chopEffectTimer = 0    -- Cooldown for wood chip effects
    self.idleSeed = math.random() * 100  -- Unique seed for idle animation
    
    -- Building
    self.buildTargetX = nil
    self.buildTargetY = nil
    self.buildingType = nil
    self.buildCallback = nil
    self.buildCostGold = 0
    self.buildCostLumber = 0
    self.buildEntryX = nil  -- Position when entering building site
    self.buildEntryY = nil
    
    -- Notification callback (set by gameplay)
    self.onNotify = nil
    
    -- UI - Build buttons
    self.buildButtons = {}
    self.buildMenuPage = 1  -- For scrolling through buildings
    self.lastPageKey = nil  -- Track page to avoid recreating buttons
    
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
        -- Skip collision check for target mine (peon needs to walk into it)
        if self.targetMine and b == self.targetMine then
            goto continue
        end
        
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
        
        ::continue::
    end
    
    return true
end

-- Compute path to target using line-of-sight pathfinding
function Peon:computePath(targetX, targetY, buildings)
    -- Filter out target mine so pathfinding goes TO it, not around it
    local filteredBuildings = buildings
    if self.targetMine and buildings then
        filteredBuildings = {}
        for _, b in ipairs(buildings) do
            if b ~= self.targetMine then
                table.insert(filteredBuildings, b)
            end
        end
    end
    return Pathfinding.findPath(self.worldX, self.worldY, targetX, targetY, filteredBuildings, self.map, self.radius)
end

-- Advance to next waypoint if we've reached current one AND can see the next one
function Peon:updateWaypoint(buildings)
    if Pathfinding.reachedWaypoint(self.worldX, self.worldY, self.path, self.currentWaypoint, 12) then
        local nextWp = self.currentWaypoint + 1
        if nextWp <= #self.path then
            local nextTarget = self.path[nextWp]
            -- Filter out target mine for line-of-sight check
            local filteredBuildings = buildings
            if self.targetMine and buildings then
                filteredBuildings = {}
                for _, b in ipairs(buildings) do
                    if b ~= self.targetMine then
                        table.insert(filteredBuildings, b)
                    end
                end
            end
            -- Only advance if we have clear line of sight to next waypoint
            if Pathfinding.canSee(self.worldX, self.worldY, nextTarget.x, nextTarget.y, filteredBuildings, self.map, self.radius) then
                self.currentWaypoint = nextWp
            end
        else
            self.currentWaypoint = nextWp
        end
    end
end

-- Try to move at full speed in the given direction
-- If blocked, find alternative directions that maintain full speed
function Peon:tryMove(dirX, dirY, moveSpeed, buildings)
    local moveX = dirX * moveSpeed
    local moveY = dirY * moveSpeed
    local newX = self.worldX + moveX
    local newY = self.worldY + moveY
    
    -- First try direct movement
    if self:canMoveTo(newX, newY, buildings) then
        self.worldX = newX
        self.worldY = newY
        return true
    end
    
    -- Blocked - try sliding along walls at FULL SPEED
    -- Test 8 alternative directions, pick best one that's closest to intended direction
    local alternatives = {
        {dx = 1, dy = 0},
        {dx = -1, dy = 0},
        {dx = 0, dy = 1},
        {dx = 0, dy = -1},
        {dx = 0.707, dy = 0.707},
        {dx = -0.707, dy = 0.707},
        {dx = 0.707, dy = -0.707},
        {dx = -0.707, dy = -0.707},
    }
    
    -- Sort by how aligned they are with intended direction (dot product)
    table.sort(alternatives, function(a, b)
        local dotA = a.dx * dirX + a.dy * dirY
        local dotB = b.dx * dirX + b.dy * dirY
        return dotA > dotB
    end)
    
    -- Try each alternative at full speed
    for _, alt in ipairs(alternatives) do
        local dot = alt.dx * dirX + alt.dy * dirY
        -- Only use alternatives that are at least somewhat aligned (dot > 0)
        if dot > 0.1 then
            local altX = self.worldX + alt.dx * moveSpeed
            local altY = self.worldY + alt.dy * moveSpeed
            if self:canMoveTo(altX, altY, buildings) then
                self.worldX = altX
                self.worldY = altY
                return true
            end
        end
    end
    
    -- Still stuck - try smaller movements in the intended direction
    for fraction = 0.75, 0.25, -0.25 do
        local smallX = self.worldX + moveX * fraction
        local smallY = self.worldY + moveY * fraction
        if self:canMoveTo(smallX, smallY, buildings) then
            self.worldX = smallX
            self.worldY = smallY
            return true
        end
    end
    
    return false  -- Completely stuck
end

-- Get direction to move towards current waypoint
function Peon:getMoveDirection(targetX, targetY, buildings)
    -- Update waypoint progression
    self:updateWaypoint(buildings)
    
    -- Get direction from pathfinding
    local dirX, dirY = Pathfinding.getDirection(self.worldX, self.worldY, self.path, self.currentWaypoint)
    if dirX then
        return dirX, dirY
    end
    
    -- No path or reached end - move directly towards target
    local dx = targetX - self.worldX
    local dy = targetY - self.worldY
    local dist = math.sqrt(dx * dx + dy * dy)
    
    if dist > 1 then
        return dx / dist, dy / dist
    end
    
    return nil, nil
end

function Peon:update(dt, buildings, townHall, goldMine, resources, allUnits, allBuildings)
    -- Update animation timer
    self.animTimer = self.animTimer + dt
    
    -- Update flash timer
    if self.flashTimer and self.flashTimer > 0 then
        self.flashTimer = self.flashTimer - dt
        if self.flashTimer <= 0 then
            self.damageFlash = false
        end
    end
    
    -- Update attack cooldown
    if self.attackCooldown > 0 then
        self.attackCooldown = self.attackCooldown - dt
    end
    
    -- Track movement for dust effects
    local moved = false
    local moveDistSq = (self.worldX - self.lastWorldX)^2 + (self.worldY - self.lastWorldY)^2
    if moveDistSq > 4 then  -- Moved more than 2 pixels
        moved = true
    end
    
    -- Dust effect cooldown
    self.dustTimer = math.max(0, self.dustTimer - dt)
    self.chopEffectTimer = math.max(0, self.chopEffectTimer - dt)
    
    -- Spawn dust when walking
    if moved and self.dustTimer <= 0 and Effects then
        Effects.footstep(self.worldX, self.worldY + 10)
        self.dustTimer = 0.15  -- Cooldown between dust puffs
    end
    
    -- Remember position for next frame
    self.lastWorldX = self.worldX
    self.lastWorldY = self.worldY
    
    -- Auto-acquire targets if idle and enemies nearby
    if self.state == Peon.STATE_IDLE and allUnits then
        self:checkForEnemies(allUnits, allBuildings)
    end
    
    if self.state == Peon.STATE_MOVING then
        self:updateMoving(dt, buildings, goldMine)
    elseif self.state == Peon.STATE_HARVESTING then
        self:updateHarvesting(dt, resources)
    elseif self.state == Peon.STATE_RETURNING then
        self:updateReturning(dt, buildings, townHall, resources)
    elseif self.state == Peon.STATE_CHOPPING then
        self:updateChopping(dt, resources)
    elseif self.state == Peon.STATE_BUILDING then
        -- Building update is handled by gameplay.lua
    elseif self.state == Peon.STATE_ATTACKING then
        self:updateAttacking(dt, buildings, allUnits, allBuildings)
    end
end

function Peon:updateMoving(dt, buildings, goldMine)
    if not self.targetX or not self.targetY then
        self.state = Peon.STATE_IDLE
        return
    end
    
    -- Check if we should stop for a mine (use self.targetMine, not the parameter)
    if self.targetMine then
        if self:isTouchingBuilding(self.targetMine, 4) then
            self.visible = false
            self.state = Peon.STATE_HARVESTING
            self.harvestTimer = 0
            return
        end
    end
    
    -- Check if we should stop for a tree (chop any adjacent tree when in chop mode)
    if self.targetTreeX and self.targetTreeY then
        local currentGridX, currentGridY = self.map:worldToGrid(self.worldX, self.worldY)
        
        -- Check if we're adjacent to ANY tree (not just target)
        local directions = {{0,0}, {-1,0}, {1,0}, {0,-1}, {0,1}, {-1,-1}, {1,-1}, {-1,1}, {1,1}}
        for _, dir in ipairs(directions) do
            local checkX = currentGridX + dir[1]
            local checkY = currentGridY + dir[2]
            if self.map:isTileTree(checkX, checkY) then
                -- Found an adjacent tree, chop it!
                self.targetTreeX = checkX
                self.targetTreeY = checkY
                self.state = Peon.STATE_CHOPPING
                self.choppingTimer = 0
                return
            end
        end
    end
    
    -- Check if we should start building
    if self.buildTargetX and self.buildTargetY and self.buildCallback then
        local buildWorldX, buildWorldY = self.map:gridToWorld(self.buildTargetX, self.buildTargetY)
        local dx = (buildWorldX + 16) - self.worldX
        local dy = (buildWorldY + 16) - self.worldY
        local dist = math.sqrt(dx * dx + dy * dy)
        if dist < 40 then
            -- Check if we can afford the building now
            if self.resourceCheck then
                local canAfford, gold, lumber = self.resourceCheck()
                if not canAfford then
                    -- Not enough resources - go idle and notify
                    if self.onNotify then
                        self.onNotify("Not enough resources! Need " .. self.buildCostGold .. "g " .. self.buildCostLumber .. "L")
                    end
                    self.state = Peon.STATE_IDLE
                    self.buildTargetX = nil
                    self.buildTargetY = nil
                    self.buildingType = nil
                    self.buildCallback = nil
                    self.buildCostGold = 0
                    self.buildCostLumber = 0
                    return
                end
                -- Deduct resources now
                self.deductResources(self.buildCostGold, self.buildCostLumber)
            end
            
            self.buildEntryX = self.worldX
            self.buildEntryY = self.worldY
            self.visible = false
            self.state = Peon.STATE_BUILDING
            if self.buildCallback then
                self.buildCallback(self.buildTargetX, self.buildTargetY, self.buildingType, self)
            end
            return
        end
    end
    
    -- Normal movement towards target
    local dx = self.targetX - self.worldX
    local dy = self.targetY - self.worldY
    local dist = math.sqrt(dx * dx + dy * dy)
    
    if dist <= 8 then
        self.state = Peon.STATE_IDLE
        self.targetX = nil
        self.targetY = nil
        self.path = nil
        self.goIdleAtTarget = nil
        return
    end
    
    -- Make sure we have a path
    if not self.path then
        self.path = self:computePath(self.targetX, self.targetY, buildings)
        self.currentWaypoint = 1
    end
    
    local moveDirX, moveDirY = self:getMoveDirection(self.targetX, self.targetY, buildings)
    
    if not moveDirX or not moveDirY then
        return
    end
    
    local moveSpeed = self.speed * dt
    self:tryMove(moveDirX, moveDirY, moveSpeed, buildings)
end

function Peon:updateHarvesting(dt, resources)
    self.harvestTimer = self.harvestTimer + dt
    
    if self.harvestTimer >= self.harvestTime then
        -- Actually extract gold from the mine
        local goldExtracted = self.harvestAmount
        if self.targetMine and self.targetMine.extractGold then
            goldExtracted = self.targetMine:extractGold(self.harvestAmount)
        end
        
        self.carryingGold = goldExtracted
        self.visible = true
        self.state = Peon.STATE_RETURNING
        
        -- If mine is depleted, clear target
        if self.targetMine and self.targetMine.depleted then
            self.targetMine = nil
        end
    end
end

function Peon:updateReturning(dt, buildings, townHall, resources)
    -- If no town hall, drop gold and go idle
    if not townHall or (townHall.isDead and townHall:isDead()) then
        self.carryingGold = 0
        self.carryingLumber = 0
        self.state = Peon.STATE_IDLE
        self.targetMine = nil
        self.targetTreeX = nil
        self.targetTreeY = nil
        return
    end
    
    if self:isTouchingBuilding(townHall, 4) then
        if self.carryingGold > 0 then
            -- Use callback if available, otherwise direct access
            if self.addResources then
                self.addResources(self.carryingGold, 0)
            else
                resources.gold = resources.gold + self.carryingGold
            end
            self.carryingGold = 0
            
            -- Check if mine is still valid
            if self.targetMine and not self.targetMine.depleted then
                local cx, cy = self.targetMine:getWorldCenter()
                self.targetX = cx
                self.targetY = cy
                self.path = nil  -- Clear path for new target
                self.currentWaypoint = 1
                self.state = Peon.STATE_MOVING
            else
                -- Mine depleted or gone, go idle
                self.targetMine = nil
                self.state = Peon.STATE_IDLE
            end
        elseif self.carryingLumber > 0 then
            -- Use callback if available, otherwise direct access
            if self.addResources then
                self.addResources(0, self.carryingLumber)
            else
                resources.lumber = resources.lumber + self.carryingLumber
            end
            self.carryingLumber = 0
            if self.targetTreeX and self.targetTreeY then
                -- Have a target tree (original or adjacent), go chop it
                if self.map:isTileTree(self.targetTreeX, self.targetTreeY) then
                    self.targetX, self.targetY = self.map:getTileWorldCenter(self.targetTreeX, self.targetTreeY)
                    self.path = nil  -- Clear path for new target
                    self.currentWaypoint = 1
                    self.state = Peon.STATE_MOVING
                else
                    -- Tree disappeared somehow, go idle
                    self.targetTreeX = nil
                    self.targetTreeY = nil
                    self.state = Peon.STATE_IDLE
                end
            elseif self.returnToStumpX and self.returnToStumpY then
                -- No adjacent tree found, return to stump then go idle
                self.targetX, self.targetY = self.map:getTileWorldCenter(self.returnToStumpX, self.returnToStumpY)
                self.path = nil  -- Clear path for new target
                self.currentWaypoint = 1
                self.goIdleAtTarget = true  -- Flag to go idle when reaching target
                self.returnToStumpX = nil
                self.returnToStumpY = nil
                self.state = Peon.STATE_MOVING
            else
                self.state = Peon.STATE_IDLE
            end
        end
        return
    end
    
    local targetX, targetY = townHall:getWorldCenter()
    local dx = targetX - self.worldX
    local dy = targetY - self.worldY
    local dist = math.sqrt(dx * dx + dy * dy)
    
    if dist > 0.1 then
        local moveDirX = dx / dist
        local moveDirY = dy / dist
        local moveSpeed = self.speed * dt
        self:tryMove(moveDirX, moveDirY, moveSpeed, buildings)
    end
end

-- Find an adjacent tree that is accessible (has a passable tile next to it)
function Peon:findAdjacentAccessibleTree(stumpX, stumpY)
    local directions = {
        {-1, 0}, {1, 0}, {0, -1}, {0, 1},  -- Cardinal
        {-1, -1}, {1, -1}, {-1, 1}, {1, 1}  -- Diagonal
    }
    
    -- Check all tiles adjacent to the stump for trees
    for _, dir in ipairs(directions) do
        local treeX = stumpX + dir[1]
        local treeY = stumpY + dir[2]
        
        if self.map:isTileTree(treeX, treeY) then
            -- Check if this tree has at least one passable tile adjacent to it
            -- (so the peon can stand there to chop)
            for _, checkDir in ipairs(directions) do
                local standX = treeX + checkDir[1]
                local standY = treeY + checkDir[2]
                if self.map:isTilePassable(standX, standY) then
                    -- Found an accessible tree
                    return treeX, treeY
                end
            end
        end
    end
    
    return nil, nil
end

-- Find a tree near a world position that the peon can reach
-- Searches in expanding rings from the target position
function Peon:findNearestReachableTree(worldX, worldY)
    local gridX, gridY = self.map:worldToGrid(worldX, worldY)
    
    local directions = {
        {-1, 0}, {1, 0}, {0, -1}, {0, 1},
        {-1, -1}, {1, -1}, {-1, 1}, {1, 1}
    }
    
    -- Check if clicked tile itself is a tree with accessible neighbor
    if self.map:isTileTree(gridX, gridY) then
        for _, dir in ipairs(directions) do
            local standX = gridX + dir[1]
            local standY = gridY + dir[2]
            if self.map:isTilePassable(standX, standY) then
                return gridX, gridY
            end
        end
    end
    
    -- Search in expanding rings
    for radius = 1, 10 do
        for dx = -radius, radius do
            for dy = -radius, radius do
                if math.abs(dx) == radius or math.abs(dy) == radius then
                    local checkX = gridX + dx
                    local checkY = gridY + dy
                    
                    if self.map:isTileTree(checkX, checkY) then
                        -- Check if this tree has an accessible neighbor
                        for _, dir in ipairs(directions) do
                            local standX = checkX + dir[1]
                            local standY = checkY + dir[2]
                            if self.map:isTilePassable(standX, standY) then
                                return checkX, checkY
                            end
                        end
                    end
                end
            end
        end
    end
    
    return nil, nil
end

function Peon:updateChopping(dt, resources)
    self.choppingTimer = self.choppingTimer + dt
    
    -- Spawn wood chips during chopping animation
    if Effects and self.chopEffectTimer <= 0 then
        local treeWorldX, treeWorldY = self.map:getTileWorldCenter(self.targetTreeX, self.targetTreeY)
        Effects.woodChips(treeWorldX, treeWorldY - 5)
        self.chopEffectTimer = 0.4  -- Cooldown between chip bursts
    end
    
    if self.choppingTimer >= self.choppingTime then
        self.carryingLumber = self.choppingAmount
        
        -- Harvest the tree (decrements health, returns false if depleted)
        if self.map and self.targetTreeX and self.targetTreeY then
            local oldTreeX, oldTreeY = self.targetTreeX, self.targetTreeY
            local treeStillAlive = self.map:harvestTree(self.targetTreeX, self.targetTreeY)
            
            if not treeStillAlive then
                -- Tree is depleted, try to find an adjacent accessible tree
                local newTreeX, newTreeY = self:findAdjacentAccessibleTree(oldTreeX, oldTreeY)
                
                if newTreeX and newTreeY then
                    -- Found adjacent tree, continue harvesting it after returning lumber
                    self.targetTreeX = newTreeX
                    self.targetTreeY = newTreeY
                else
                    -- No adjacent tree, remember stump location to return to
                    self.returnToStumpX = oldTreeX
                    self.returnToStumpY = oldTreeY
                    self.targetTreeX = nil
                    self.targetTreeY = nil
                end
            end
        end
        
        self.state = Peon.STATE_RETURNING
    end
end

function Peon:finishBuilding(building)
    self.state = Peon.STATE_IDLE
    self.visible = true
    
    -- Try to spawn at building's spawn position if available
    if building and building.getSpawnPos then
        local spawnX, spawnY = building:getSpawnPos()
        self.worldX = spawnX
        self.worldY = spawnY
    elseif building and building.getWorldBounds then
        -- Spawn just outside the building
        local bx1, by1, bx2, by2 = building:getWorldBounds()
        self.worldX = bx2 + self.radius + 5
        self.worldY = (by1 + by2) / 2
    elseif self.buildEntryX and self.buildEntryY then
        -- Fallback to entry position
        self.worldX = self.buildEntryX
        self.worldY = self.buildEntryY
    end
    
    self.buildTargetX = nil
    self.buildTargetY = nil
    self.buildingType = nil
    self.buildCallback = nil
    self.buildEntryX = nil
    self.buildEntryY = nil
end

-- Combat Methods --

function Peon:setAttackTarget(target)
    self.attackTarget = target
    self.targetMine = nil
    self.targetTreeX = nil
    self.targetTreeY = nil
    self.carryingGold = 0
    self.carryingLumber = 0
    self.state = Peon.STATE_ATTACKING
    self.path = nil
end

function Peon:getAttackRange()
    return self.radius + 4  -- Tight melee range (about 18 pixels)
end

function Peon:getSightRangePixels()
    return self.sightRadius * 32  -- Convert tiles to pixels
end

function Peon:distanceTo(target)
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

function Peon:updateAttacking(dt, buildings, allUnits, allBuildings)
    -- Check if target is dead or gone
    if not self.attackTarget or (self.attackTarget.isDead and self.attackTarget:isDead()) then
        self.attackTarget = nil
        self.state = Peon.STATE_IDLE
        -- Try to find new target
        if allUnits then
            self:checkForEnemies(allUnits, allBuildings)
        end
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
                
                -- Visual/sound effects
                if Effects then
                    local tx, ty = target.worldX or target:getWorldCenter()
                    local targetY = target.worldY or select(2, target:getWorldCenter())
                    Effects.blood(tx or target.worldX, targetY or target.worldY)
                end
            end
        end
    else
        -- Move toward target
        local tx, ty
        if target.getWorldBounds then
            -- For buildings, move toward nearest edge
            local bx1, by1, bx2, by2 = target:getWorldBounds()
            tx = math.max(bx1, math.min(self.worldX, bx2))
            ty = math.max(by1, math.min(self.worldY, by2))
            -- Add small offset to be just outside the building
            local dx = self.worldX - tx
            local dy = self.worldY - ty
            local len = math.sqrt(dx * dx + dy * dy)
            if len > 0 then
                tx = tx + (dx / len) * 5
                ty = ty + (dy / len) * 5
            end
        elseif target.getWorldCenter then
            tx, ty = target:getWorldCenter()
        else
            tx, ty = target.worldX, target.worldY
        end
        
        -- Compute path if needed
        if not self.path then
            self.targetX = tx
            self.targetY = ty
            self.path = self:computePath(tx, ty, buildings)
            self.currentWaypoint = 1
        end
        
        -- Move along path
        if self.path then
            local dirX, dirY = self:getMoveDirection(tx, ty, buildings)
            if dirX then
                local moveSpeed = self.speed * dt
                self:tryMove(dirX, dirY, moveSpeed, buildings)
            end
        end
    end
end

function Peon:checkForEnemies(allUnits, allBuildings)
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

function Peon:takeDamage(amount)
    self.hp = self.hp - amount
    
    -- Flash effect (always set, even without DrawUtils)
    self.flashTimer = 0.15
    self.damageFlash = true  -- Extra flag for visible feedback
    
    -- Aggro back if not already attacking
    if self.state ~= Peon.STATE_ATTACKING then
        -- Will auto-acquire on next update
    end
end

function Peon:isDead()
    return self.hp <= 0
end

function Peon:drawHealthBar()
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

function Peon:draw()
    if not self.visible then return end
    
    -- Draw health bar if selected or damaged
    self:drawHealthBar()
    
    local x, y = self:getScreenPos()
    
    -- Animation offsets
    local jumpOffset = 0
    local idleBob = 0
    local walkBob = 0
    local breathe = 0
    
    -- State-based animations
    if self.state == Peon.STATE_CHOPPING then
        -- Jump up and down rapidly when chopping
        jumpOffset = math.abs(math.sin(self.animTimer * 12)) * 6
    elseif self.state == Peon.STATE_MOVING or self.state == Peon.STATE_RETURNING then
        -- Bouncy walk
        walkBob = math.abs(math.sin(self.animTimer * 10)) * 2
    elseif self.state == Peon.STATE_IDLE then
        -- Gentle breathing/shifting
        if DrawUtils then
            idleBob = DrawUtils.getIdleBob(self.idleSeed, 0.8)
        else
            idleBob = math.sin(self.animTimer * 1.5 + self.idleSeed) * 1.2
        end
    end
    
    -- Breathing animation (subtle chest expansion)
    breathe = math.sin(self.animTimer * 2 + self.idleSeed) * 0.5
    
    y = y - jumpOffset - walkBob - idleBob
    
    -- Selection circle (don't apply movement offsets)
    local baseY = y + jumpOffset + walkBob + idleBob
    if self.selected then
        local playerTeam = Teams and Teams.PLAYER or 1
        local selR, selG, selB = 0, 1, 0  -- Green for player
        if self.team ~= playerTeam then
            selR, selG, selB = 1, 0, 0  -- Red for enemy
        end
        if DrawUtils then
            -- DrawUtils expects green, so draw manually for enemies
            if self.team ~= playerTeam then
                love.graphics.setColor(selR, selG, selB, 0.4)
                love.graphics.circle("fill", x, baseY, self.radius + 4)
                love.graphics.setColor(selR, selG, selB, 0.8)
                love.graphics.setLineWidth(2)
                love.graphics.circle("line", x, baseY, self.radius + 4)
            else
                DrawUtils.drawSelection(x, baseY, self.radius + 2)
            end
        else
            love.graphics.setColor(selR, selG, selB, 0.4)
            love.graphics.circle("fill", x, baseY, self.radius + 4)
            love.graphics.setColor(selR, selG, selB, 0.8)
            love.graphics.setLineWidth(2)
            love.graphics.circle("line", x, baseY, self.radius + 4)
        end
    end
    
    -- Enhanced shadow (stays on ground)
    if DrawUtils then
        DrawUtils.drawShadow(x, baseY + 10, 11, 4, 0.4)
    else
        love.graphics.setColor(0, 0, 0, 0.35)
        love.graphics.ellipse("fill", x, baseY + 10, 11, 4)
    end
    
    -- Draw the peon body with outline
    local function drawBody()
        -- Get team colors (fallback to neutral brown if no Teams module)
        local teamColors = Teams and Teams.getColors(self.team) or nil
        local shirtColor = teamColors and teamColors.primary or {0.55, 0.45, 0.35, 1}
        local hoodColor = teamColors and teamColors.dark or {0.5, 0.4, 0.3, 1}
        local beltColor = {0.35, 0.25, 0.15, 1}  -- Belt stays neutral brown
        
        -- Feet
        love.graphics.setColor(0.4, 0.3, 0.2, 1)
        love.graphics.ellipse("fill", x - 5, y + 7, 5, 3)
        love.graphics.ellipse("fill", x + 5, y + 7, 5, 3)
        
        -- Legs
        love.graphics.setColor(0.5, 0.35, 0.25, 1)
        love.graphics.rectangle("fill", x - 6, y + 2, 5, 7, 1)
        love.graphics.rectangle("fill", x + 1, y + 2, 5, 7, 1)
        
        -- Body (work shirt) - TEAM COLOR - with breathing
        love.graphics.setColor(shirtColor)
        love.graphics.rectangle("fill", x - 8 - breathe * 0.5, y - 6, 16 + breathe, 12, 2)
        
        -- Belt
        love.graphics.setColor(beltColor)
        love.graphics.rectangle("fill", x - 8, y + 1, 16, 3)
        love.graphics.setColor(0.6, 0.5, 0.2, 1)
        love.graphics.rectangle("fill", x - 2, y + 1, 4, 3)  -- Buckle
        
        -- Arms - TEAM COLOR - with slight swing when walking
        local armSwing = 0
        if self.state == Peon.STATE_MOVING or self.state == Peon.STATE_RETURNING then
            armSwing = math.sin(self.animTimer * 10) * 2
        end
        love.graphics.setColor(shirtColor)
        love.graphics.rectangle("fill", x - 11, y - 4 + armSwing, 5, 10, 1)
        love.graphics.rectangle("fill", x + 6, y - 4 - armSwing, 5, 10, 1)
        
        -- Hands (skin tone)
        love.graphics.setColor(0.85, 0.7, 0.55, 1)
        love.graphics.circle("fill", x - 9, y + 4 + armSwing, 3)
        love.graphics.circle("fill", x + 9, y + 4 - armSwing, 3)
        
        -- Head
        love.graphics.setColor(0.85, 0.7, 0.55, 1)
        love.graphics.ellipse("fill", x, y - 10, 6, 7)
        
        -- Hood/cap - TEAM COLOR (darker shade)
        love.graphics.setColor(hoodColor)
        love.graphics.arc("fill", x, y - 10, 7, math.pi, 2 * math.pi)
        love.graphics.rectangle("fill", x - 7, y - 12, 14, 4, 1)
        
        -- Face details
        love.graphics.setColor(0.15, 0.1, 0.05, 1)
        love.graphics.circle("fill", x - 2, y - 11, 1.5)  -- Left eye
        love.graphics.circle("fill", x + 2, y - 11, 1.5)  -- Right eye
        love.graphics.setColor(0.7, 0.5, 0.4, 1)
        love.graphics.ellipse("fill", x, y - 8, 2, 1.5)  -- Nose
        
        -- Tool based on state/carrying
        if self.state == Peon.STATE_CHOPPING or self.carryingLumber > 0 then
            -- Axe with swing animation when chopping
            local axeAngle = 0
            if self.state == Peon.STATE_CHOPPING then
                axeAngle = math.sin(self.animTimer * 12) * 0.4
            end
            love.graphics.push()
            love.graphics.translate(x + 12, y)
            love.graphics.rotate(axeAngle)
            love.graphics.setColor(0.5, 0.35, 0.2, 1)
            love.graphics.rectangle("fill", -2, -8, 2, 14, 1)  -- Handle
            love.graphics.setColor(0.65, 0.65, 0.7, 1)
            love.graphics.polygon("fill", -3, -8, 4, -6, 4, -2, -3, -4)  -- Blade
            -- Blade highlight
            love.graphics.setColor(0.85, 0.85, 0.9, 0.6)
            love.graphics.line(-1, -7, 2, -5)
            love.graphics.pop()
        elseif self.state == Peon.STATE_HARVESTING or self.carryingGold > 0 then
            -- Pickaxe
            love.graphics.setColor(0.5, 0.35, 0.2, 1)
            love.graphics.rectangle("fill", x + 10, y - 6, 2, 12, 1)  -- Handle
            love.graphics.setColor(0.55, 0.55, 0.6, 1)
            love.graphics.polygon("fill", x + 8, y - 8, x + 18, y - 6, x + 14, y - 2)  -- Pick head
            -- Highlight
            love.graphics.setColor(0.75, 0.75, 0.8, 0.5)
            love.graphics.line(x + 10, y - 7, x + 15, y - 5)
        end
        
        -- Carried resources on back
        if self.carryingGold > 0 then
            -- Gold sack with shimmer
            love.graphics.setColor(0.65, 0.5, 0.12, 1)
            love.graphics.ellipse("fill", x, y - 2, 7, 6)
            love.graphics.setColor(0.9, 0.75, 0.15, 1)
            love.graphics.circle("fill", x - 2, y - 3, 3)
            love.graphics.circle("fill", x + 2, y - 1, 2.5)
            -- Gold shine
            love.graphics.setColor(1, 0.95, 0.5, 0.7)
            love.graphics.circle("fill", x - 3, y - 4, 1.5)
        elseif self.carryingLumber > 0 then
            -- Lumber bundle with wood grain hint
            love.graphics.setColor(0.5, 0.35, 0.18, 1)
            love.graphics.rectangle("fill", x - 4, y - 14, 3, 12, 1)
            love.graphics.setColor(0.55, 0.4, 0.2, 1)
            love.graphics.rectangle("fill", x - 1, y - 16, 3, 14, 1)
            love.graphics.setColor(0.5, 0.36, 0.19, 1)
            love.graphics.rectangle("fill", x + 2, y - 13, 3, 11, 1)
            -- Wood highlights
            love.graphics.setColor(0.65, 0.5, 0.3, 0.5)
            love.graphics.line(x - 3, y - 13, x - 3, y - 5)
            love.graphics.line(x, y - 15, x, y - 4)
        end
    end
    
    -- Draw outline then body (or with flash effect)
    if DrawUtils and Effects then
        -- Draw dark outline
        love.graphics.setColor(0.1, 0.08, 0.05, 0.7)
        local offsets = {{-1.5, 0}, {1.5, 0}, {0, -1.5}, {0, 1.5}}
        for _, off in ipairs(offsets) do
            love.graphics.push()
            love.graphics.translate(off[1], off[2])
            drawBody()
            love.graphics.pop()
        end
        
        -- Draw body with flash effect if damaged
        DrawUtils.applyFlash(self, drawBody)
    else
        -- Fallback: just draw body
        drawBody()
        
        -- Manual flash effect if damaged
        if self.flashTimer and self.flashTimer > 0 then
            local x, y = self:getScreenPos()
            love.graphics.setColor(1, 0.3, 0.3, 0.5)
            love.graphics.circle("fill", x, y, self.radius + 5)
        end
    end
    
    love.graphics.setLineWidth(1)
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

function Peon:moveTo(worldX, worldY)
    self.targetX = worldX
    self.targetY = worldY
    self.targetMine = nil
    self.targetTreeX = nil
    self.targetTreeY = nil
    self.returnToStumpX = nil
    self.returnToStumpY = nil
    self.goIdleAtTarget = nil
    self.buildTargetX = nil
    self.buildTargetY = nil
    self.buildCallback = nil
    self.buildCostGold = 0
    self.buildCostLumber = 0
    self.path = nil  -- Will be computed on first update
    self.currentWaypoint = 1
    self.state = Peon.STATE_MOVING
end

function Peon:goToMine(mine)
    self.targetMine = mine
    self.targetTreeX = nil
    self.targetTreeY = nil
    self.returnToStumpX = nil
    self.returnToStumpY = nil
    self.goIdleAtTarget = nil
    self.buildTargetX = nil
    self.buildTargetY = nil
    self.buildCallback = nil
    self.path = nil
    self.currentWaypoint = 1
    -- Target the center - updateMoving will stop at the edge
    local cx, cy = mine:getWorldCenter()
    self.targetX = cx
    self.targetY = cy
    self.state = Peon.STATE_MOVING
end

function Peon:goToTree(gridX, gridY)
    self.targetTreeX = gridX
    self.targetTreeY = gridY
    self.targetMine = nil
    self.returnToStumpX = nil
    self.returnToStumpY = nil
    self.goIdleAtTarget = nil
    self.buildTargetX = nil
    self.buildTargetY = nil
    self.buildCallback = nil
    self.path = nil
    self.currentWaypoint = 1
    if self.map then
        self.targetX, self.targetY = self.map:getTileWorldCenter(gridX, gridY)
    end
    self.state = Peon.STATE_MOVING
end

function Peon:goToBuild(gridX, gridY, buildingType, callback, costGold, costLumber)
    self.buildTargetX = gridX
    self.buildTargetY = gridY
    self.buildingType = buildingType
    self.buildCallback = callback
    self.buildCostGold = costGold or 0
    self.buildCostLumber = costLumber or 0
    self.targetMine = nil
    self.targetTreeX = nil
    self.targetTreeY = nil
    self.returnToStumpX = nil
    self.returnToStumpY = nil
    self.goIdleAtTarget = nil
    self.path = nil
    self.currentWaypoint = 1
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

-- Building definitions for UI
local function getBuildingDefs()
    local Farm = require("farm")
    local Barracks = require("barracks")
    local LumberMill = require("lumbermill")
    local Blacksmith = require("blacksmith")
    local ScoutTower = require("scouttower")
    local ArcheryRange = require("archeryrange")
    local Stable = require("stable")
    local SiegeWorkshop = require("siegeworkshop")
    local TownHall = require("townhall")
    
    return {
        -- Page 1: Basic buildings
        {
            type = "farm",
            name = "Farm",
            costGold = Farm.COST_GOLD,
            costLumber = Farm.COST_LUMBER,
            colors = {normal = {0.3, 0.5, 0.35, 1}, hover = {0.4, 0.6, 0.45, 1}, pressed = {0.2, 0.4, 0.25, 1}},
            canBuild = function() return true end
        },
        {
            type = "barracks",
            name = "Barracks",
            costGold = Barracks.COST_GOLD,
            costLumber = Barracks.COST_LUMBER,
            colors = {normal = {0.5, 0.35, 0.35, 1}, hover = {0.6, 0.45, 0.45, 1}, pressed = {0.4, 0.25, 0.25, 1}},
            canBuild = function() return true end
        },
        {
            type = "lumbermill",
            name = "Lumber Mill",
            costGold = LumberMill.COST_GOLD,
            costLumber = LumberMill.COST_LUMBER,
            colors = {normal = {0.45, 0.35, 0.25, 1}, hover = {0.55, 0.45, 0.35, 1}, pressed = {0.35, 0.25, 0.15, 1}},
            canBuild = function() return Requirements.canBuild("lumbermill") end
        },
        {
            type = "scouttower",
            name = "Scout Tower",
            costGold = ScoutTower.COST_GOLD,
            costLumber = ScoutTower.COST_LUMBER,
            colors = {normal = {0.4, 0.4, 0.45, 1}, hover = {0.5, 0.5, 0.55, 1}, pressed = {0.3, 0.3, 0.35, 1}},
            canBuild = function() return Requirements.canBuild("scouttower") end
        },
        -- Page 2: Advanced buildings
        {
            type = "blacksmith",
            name = "Blacksmith",
            costGold = Blacksmith.COST_GOLD,
            costLumber = Blacksmith.COST_LUMBER,
            colors = {normal = {0.4, 0.38, 0.42, 1}, hover = {0.5, 0.48, 0.52, 1}, pressed = {0.3, 0.28, 0.32, 1}},
            canBuild = function() return Requirements.canBuild("blacksmith") end,
            requirement = "Barracks"
        },
        {
            type = "archeryrange",
            name = "Archery Range",
            costGold = ArcheryRange.COST_GOLD,
            costLumber = ArcheryRange.COST_LUMBER,
            colors = {normal = {0.35, 0.45, 0.35, 1}, hover = {0.45, 0.55, 0.45, 1}, pressed = {0.25, 0.35, 0.25, 1}},
            canBuild = function() return Requirements.canBuild("archeryrange") end,
            requirement = "Barracks"
        },
        {
            type = "stable",
            name = "Stable",
            costGold = Stable.COST_GOLD,
            costLumber = Stable.COST_LUMBER,
            colors = {normal = {0.5, 0.4, 0.3, 1}, hover = {0.6, 0.5, 0.4, 1}, pressed = {0.4, 0.3, 0.2, 1}},
            canBuild = function() return Requirements.canBuild("stable") end,
            requirement = "Hold"
        },
        {
            type = "siegeworkshop",
            name = "Siege Workshop",
            costGold = SiegeWorkshop.COST_GOLD,
            costLumber = SiegeWorkshop.COST_LUMBER,
            colors = {normal = {0.45, 0.4, 0.35, 1}, hover = {0.55, 0.5, 0.45, 1}, pressed = {0.35, 0.3, 0.25, 1}},
            canBuild = function() return Requirements.canBuild("siegeworkshop") end,
            requirement = "Keep"
        },
        -- Page 3: Expansion
        {
            type = "townhall",
            name = "Town Hall",
            costGold = TownHall.COST_GOLD,
            costLumber = TownHall.COST_LUMBER,
            colors = {normal = {0.5, 0.4, 0.25, 1}, hover = {0.6, 0.5, 0.35, 1}, pressed = {0.4, 0.3, 0.15, 1}},
            canBuild = function() return Requirements.canBuild("townhall") end,
            requirement = "Hold"
        },
    }
end

function Peon:updateUI(resources, screenW, screenH, font, startBuildCallback)
    -- Don't show UI for enemy peons
    local playerTeam = Teams and Teams.PLAYER or 1
    if self.team ~= playerTeam then return end
    
    if self.selected and self.state ~= Peon.STATE_BUILDING then
        -- New bottom panel positioning
        local panelX = screenW - 288
        local panelY = screenH - 188
        local buttonY = panelY + 55
        local buttonW = 125
        local buttonH = 32
        local buttonSpacing = 36
        local maxButtonsPerPage = 4
        
        local buildingDefs = getBuildingDefs()
        
        -- Calculate pages
        local totalBuildings = #buildingDefs
        local totalPages = math.ceil(totalBuildings / maxButtonsPerPage)
        
        -- Clamp page
        if self.buildMenuPage > totalPages then self.buildMenuPage = totalPages end
        if self.buildMenuPage < 1 then self.buildMenuPage = 1 end
        
        -- Get buildings for current page
        local startIdx = (self.buildMenuPage - 1) * maxButtonsPerPage + 1
        local endIdx = math.min(startIdx + maxButtonsPerPage - 1, totalBuildings)
        
        -- Check if page changed - only recreate buttons if page changed
        local currentPageKey = self.buildMenuPage .. "_" .. startIdx .. "_" .. endIdx
        if self.lastPageKey ~= currentPageKey then
            self.lastPageKey = currentPageKey
            self.buildButtons = {}
            
            local buttonIdx = 0
            for i = startIdx, endIdx do
                local def = buildingDefs[i]
                local costText = string.format("%s (%d/%d)", def.name, def.costGold, def.costLumber)
                
                -- Two columns layout
                local col = buttonIdx % 2
                local row = math.floor(buttonIdx / 2)
                
                local btn = Button.new({
                    x = panelX + 12 + col * (buttonW + 8), 
                    y = buttonY + row * buttonSpacing, 
                    width = buttonW, 
                    height = buttonH,
                    text = costText, 
                    font = font,
                    colors = {
                        normal = def.colors.normal, 
                        hover = def.colors.hover,
                        pressed = def.colors.pressed, 
                        text = {0.95, 0.92, 0.85, 1}, 
                        border = {def.colors.normal[1] + 0.1, def.colors.normal[2] + 0.1, def.colors.normal[3] + 0.1, 1}
                    },
                    onClick = function()
                        if startBuildCallback then startBuildCallback(self, def.type) end
                    end
                })
                
                table.insert(self.buildButtons, {button = btn, def = def})
                buttonIdx = buttonIdx + 1
            end
        end
        
        -- Update button enabled state and positions (every frame)
        local buttonIdx = 0
        for _, btnData in ipairs(self.buildButtons) do
            local def = btnData.def
            local btn = btnData.button
            
            local canAfford = resources.gold >= def.costGold and resources.lumber >= def.costLumber
            local canGiveOrders = self.state == Peon.STATE_IDLE or self.state == Peon.STATE_MOVING
            local meetsReqs = def.canBuild()
            
            btn:setEnabled(canAfford and canGiveOrders and meetsReqs)
            
            -- Set disabled reason
            local reason = nil
            if not meetsReqs and def.requirement then
                reason = "Need " .. def.requirement
            elseif not canGiveOrders then
                reason = "Peon busy"
            elseif not canAfford then
                if resources.gold < def.costGold and resources.lumber < def.costLumber then
                    reason = "Need gold & lumber"
                elseif resources.gold < def.costGold then
                    reason = "Need gold"
                else
                    reason = "Need lumber"
                end
            end
            btn:setDisabledReason(reason)
            
            -- Two columns layout
            local col = buttonIdx % 2
            local row = math.floor(buttonIdx / 2)
            btn:setPosition(panelX + 12 + col * (buttonW + 8), buttonY + row * buttonSpacing)
            btn:update(0)
            buttonIdx = buttonIdx + 1
        end
        
        -- Page navigation buttons
        if totalPages > 1 then
            -- With 2 columns, 4 buttons = 2 rows
            local navY = buttonY + 2 * buttonSpacing + 5
            
            if not self.prevPageButton then
                self.prevPageButton = Button.new({
                    x = panelX + 12, y = navY, width = 60, height = 24,
                    text = "< Prev", font = font,
                    colors = {normal = {0.35, 0.32, 0.3, 1}, hover = {0.45, 0.42, 0.4, 1}, pressed = {0.25, 0.22, 0.2, 1}, text = {0.95,0.92,0.85,1}, border = {0.5,0.45,0.4,1}},
                    onClick = function()
                        self.buildMenuPage = self.buildMenuPage - 1
                        if self.buildMenuPage < 1 then self.buildMenuPage = totalPages end
                        self.lastPageKey = nil  -- Force button recreation
                    end
                })
            end
            
            if not self.nextPageButton then
                self.nextPageButton = Button.new({
                    x = panelX + 12 + 68, y = navY, width = 60, height = 24,
                    text = "Next >", font = font,
                    colors = {normal = {0.35, 0.32, 0.3, 1}, hover = {0.45, 0.42, 0.4, 1}, pressed = {0.25, 0.22, 0.2, 1}, text = {0.95,0.92,0.85,1}, border = {0.5,0.45,0.4,1}},
                    onClick = function()
                        self.buildMenuPage = self.buildMenuPage + 1
                        if self.buildMenuPage > totalPages then self.buildMenuPage = 1 end
                        self.lastPageKey = nil  -- Force button recreation
                    end
                })
            end
            
            -- Update positions
            self.prevPageButton:setPosition(panelX + 12, navY)
            self.nextPageButton:setPosition(panelX + 12 + 68, navY)
            self.prevPageButton:setEnabled(true)
            self.nextPageButton:setEnabled(true)
            self.prevPageButton:update(0)
            self.nextPageButton:update(0)
        else
            self.prevPageButton = nil
            self.nextPageButton = nil
        end
    else
        self.buildButtons = {}
        self.prevPageButton = nil
        self.nextPageButton = nil
        self.lastPageKey = nil
    end
end

function Peon:drawUI()
    -- Don't show UI for enemy peons
    local playerTeam = Teams and Teams.PLAYER or 1
    if self.team ~= playerTeam then return end
    
    if self.selected and self.state ~= Peon.STATE_BUILDING then
        for _, btnData in ipairs(self.buildButtons) do
            btnData.button:draw()
        end
        
        if self.prevPageButton then self.prevPageButton:draw() end
        if self.nextPageButton then self.nextPageButton:draw() end
        
        -- Page indicator
        if self.prevPageButton then
            local buildingDefs = getBuildingDefs()
            local totalPages = math.ceil(#buildingDefs / 4)
            local screenW = love.graphics.getWidth()
            local screenH = love.graphics.getHeight()
            local panelX = screenW - 288
            local panelY = screenH - 188
            love.graphics.setColor(0.7, 0.65, 0.55, 1)
            love.graphics.setFont(Game.fonts.small)
            love.graphics.print(string.format("%d/%d", self.buildMenuPage, totalPages), panelX + 150, panelY + 55 + 2 * 36 + 8)
            love.graphics.setColor(1, 1, 1, 1)
        end
    end
end

function Peon:mousepressed(x, y, button)
    for _, btnData in ipairs(self.buildButtons) do
        btnData.button:mousepressed(x, y, button)
    end
    if self.prevPageButton then self.prevPageButton:mousepressed(x, y, button) end
    if self.nextPageButton then self.nextPageButton:mousepressed(x, y, button) end
end

function Peon:mousereleased(x, y, button)
    for _, btnData in ipairs(self.buildButtons) do
        btnData.button:mousereleased(x, y, button)
    end
    if self.prevPageButton then self.prevPageButton:mousereleased(x, y, button) end
    if self.nextPageButton then self.nextPageButton:mousereleased(x, y, button) end
end

function Peon:drawOnMinimap(mapX, mapY, scale)
    if not self.visible then return end
    
    -- Use team color for minimap
    if Teams then
        Teams.setColor(self.team, "minimapUnit")
    else
        love.graphics.setColor(0.3, 0.8, 0.3, 1)  -- Fallback green
    end
    
    local gridX, gridY = 1, 1
    if self.map then
        gridX, gridY = self.map:worldToGrid(self.worldX, self.worldY)
    end
    local x = mapX + (gridX - 0.5) * scale
    local y = mapY + (gridY - 0.5) * scale
    love.graphics.circle("fill", x, y, math.max(2, scale * 0.5))
end

return Peon
