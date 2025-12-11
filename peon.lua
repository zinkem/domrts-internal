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
local Effects, DrawUtils, SpriteCache
pcall(function() Effects = require("effects") end)
pcall(function() DrawUtils = require("draw_utils") end)
pcall(function() SpriteCache = require("sprite_cache") end)

-- Peon sprite cache (initialized in Peon.prerenderSprites)
local PeonSpriteCache = nil

local Peon = {}
Peon.__index = Peon

-- Accessor functions for quadtree queries
local function getUnitX(unit) return unit.worldX end
local function getUnitY(unit) return unit.worldY end

-- Reusable table for quadtree queries (avoids allocation per query)
local separationQueryResults = {}

-- States
Peon.STATE_IDLE = "Idle"
Peon.STATE_MOVING = "Moving"
Peon.STATE_HARVESTING = "Harvesting"
Peon.STATE_RETURNING = "Returning"
Peon.STATE_CHOPPING = "Chopping"
Peon.STATE_BUILDING = "Building"
Peon.STATE_GATHER_MOVING = "GatherMoving"  -- Move toward destination, auto-gather nearby resources

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
    
    -- Combat stats
    self.maxHp = params.maxHp or 30
    self.hp = self.maxHp
    self.damage = params.damage or 2
    self.attackSpeed = 0.8
    self.attackCooldown = 0
    self.attackTarget = nil
    self.flashTimer = 0
    
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
    
    -- Sight radius for gather-move (tiles)
    self.sightRadius = 5
    
    -- Gather-move destination
    self.gatherMoveDestX = nil
    self.gatherMoveDestY = nil
    
    -- Reference to resources (set by gameplay for gather-move)
    self.resourcesRef = nil
    self.goldMinesRef = nil
    self.allUnitsRef = nil  -- Reference to all units (fallback for collision/separation)
    self.unitQuadtreeRef = nil  -- Reference to unit quadtree (for O(log n) collision lookups)
    
    -- Notification callback (set by gameplay)
    self.onNotify = nil
    
    -- UI - Build buttons
    self.buildButtons = {}
    self.buildMenuPage = 1  -- For scrolling through buildings
    self.lastPageKey = nil  -- Track page to avoid recreating buttons
    
    return self
end

-- Animation frame counts for sprite cache
local PEON_ANIM_FRAMES = {
    idle = 4,     -- Gentle breathing cycle
    walk = 6,     -- Walk cycle
    chop = 8,     -- Chopping cycle (faster)
    harvest = 6,  -- Mining animation
}

-- Carry states for sprite cache
local PEON_CARRY_STATES = {"none", "gold", "lumber"}

-- Draw peon body at origin (0,0) with given animation parameters
-- Used by both live drawing and sprite cache prerendering
local function drawPeonBodyAtOrigin(params)
    local x, y = 0, 0
    local breathe = params.breathe or 0
    local armSwing = params.armSwing or 0
    local state = params.state or "idle"
    local carry = params.carry or "none"
    local axeAngle = params.axeAngle or 0

    -- Feet
    love.graphics.setColor(0.4, 0.3, 0.2, 1)
    love.graphics.ellipse("fill", x - 5, y + 7, 5, 3)
    love.graphics.ellipse("fill", x + 5, y + 7, 5, 3)

    -- Legs
    love.graphics.setColor(0.5, 0.35, 0.25, 1)
    love.graphics.rectangle("fill", x - 6, y + 2, 5, 7, 1)
    love.graphics.rectangle("fill", x + 1, y + 2, 5, 7, 1)

    -- Body (work shirt) - with breathing
    love.graphics.setColor(0.55, 0.45, 0.35, 1)
    love.graphics.rectangle("fill", x - 8 - breathe * 0.5, y - 6, 16 + breathe, 12, 2)

    -- Belt
    love.graphics.setColor(0.35, 0.25, 0.15, 1)
    love.graphics.rectangle("fill", x - 8, y + 1, 16, 3)
    love.graphics.setColor(0.6, 0.5, 0.2, 1)
    love.graphics.rectangle("fill", x - 2, y + 1, 4, 3)  -- Buckle

    -- Arms - with slight swing when walking
    love.graphics.setColor(0.55, 0.45, 0.35, 1)
    love.graphics.rectangle("fill", x - 11, y - 4 + armSwing, 5, 10, 1)
    love.graphics.rectangle("fill", x + 6, y - 4 - armSwing, 5, 10, 1)

    -- Hands (skin tone)
    love.graphics.setColor(0.85, 0.7, 0.55, 1)
    love.graphics.circle("fill", x - 9, y + 4 + armSwing, 3)
    love.graphics.circle("fill", x + 9, y + 4 - armSwing, 3)

    -- Head
    love.graphics.setColor(0.85, 0.7, 0.55, 1)
    love.graphics.ellipse("fill", x, y - 10, 6, 7)

    -- Hood/cap
    love.graphics.setColor(0.5, 0.4, 0.3, 1)
    love.graphics.arc("fill", x, y - 10, 7, math.pi, 2 * math.pi)
    love.graphics.rectangle("fill", x - 7, y - 12, 14, 4, 1)

    -- Face details
    love.graphics.setColor(0.15, 0.1, 0.05, 1)
    love.graphics.circle("fill", x - 2, y - 11, 1.5)  -- Left eye
    love.graphics.circle("fill", x + 2, y - 11, 1.5)  -- Right eye
    love.graphics.setColor(0.7, 0.5, 0.4, 1)
    love.graphics.ellipse("fill", x, y - 8, 2, 1.5)  -- Nose

    -- Tool based on state/carrying
    local showAxe = state == "chop" or carry == "lumber"
    local showPickaxe = state == "harvest" or carry == "gold"

    if showAxe then
        -- Axe with swing animation when chopping
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
    elseif showPickaxe then
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
    if carry == "gold" then
        -- Gold sack with shimmer
        love.graphics.setColor(0.65, 0.5, 0.12, 1)
        love.graphics.ellipse("fill", x, y - 2, 7, 6)
        love.graphics.setColor(0.9, 0.75, 0.15, 1)
        love.graphics.circle("fill", x - 2, y - 3, 3)
        love.graphics.circle("fill", x + 2, y - 1, 2.5)
        -- Gold shine
        love.graphics.setColor(1, 0.95, 0.5, 0.7)
        love.graphics.circle("fill", x - 3, y - 4, 1.5)
    elseif carry == "lumber" then
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

-- Prerender all peon sprite frames to canvases
-- Call once during game load
function Peon.prerenderSprites()
    if not SpriteCache then
        print("SpriteCache not available, skipping peon prerendering")
        return
    end

    print("Prerendering peon sprites...")

    -- Canvas size: 64x64 with origin at center-bottom
    PeonSpriteCache = SpriteCache.new(64, 64, {
        originX = 32,
        originY = 54  -- Leave room for jump animation
    })

    -- Prerender idle animation (breathing)
    local idleFrames = {}
    for i = 0, PEON_ANIM_FRAMES.idle - 1 do
        table.insert(idleFrames, i)
    end

    PeonSpriteCache:prerender("idle", function(params)
        local phase = params.frame / PEON_ANIM_FRAMES.idle * math.pi * 2
        local breathe = math.sin(phase) * 0.5
        drawPeonBodyAtOrigin({
            state = "idle",
            carry = params.carry,
            breathe = breathe,
            armSwing = 0,
            axeAngle = 0
        })
    end, {
        carry = PEON_CARRY_STATES,
        frame = idleFrames
    })

    -- Prerender walk animation
    local walkFrames = {}
    for i = 0, PEON_ANIM_FRAMES.walk - 1 do
        table.insert(walkFrames, i)
    end

    PeonSpriteCache:prerender("walk", function(params)
        local phase = params.frame / PEON_ANIM_FRAMES.walk * math.pi * 2
        local armSwing = math.sin(phase) * 2
        drawPeonBodyAtOrigin({
            state = "walk",
            carry = params.carry,
            breathe = 0,
            armSwing = armSwing,
            axeAngle = 0
        })
    end, {
        carry = PEON_CARRY_STATES,
        frame = walkFrames
    })

    -- Prerender chop animation
    local chopFrames = {}
    for i = 0, PEON_ANIM_FRAMES.chop - 1 do
        table.insert(chopFrames, i)
    end

    PeonSpriteCache:prerender("chop", function(params)
        local phase = params.frame / PEON_ANIM_FRAMES.chop * math.pi * 2
        local axeAngle = math.sin(phase) * 0.4
        drawPeonBodyAtOrigin({
            state = "chop",
            carry = "none",  -- Don't carry while chopping
            breathe = 0,
            armSwing = 0,
            axeAngle = axeAngle
        })
    end, {
        carry = {"none"},  -- Only one carry state when chopping
        frame = chopFrames
    })

    -- Prerender harvest (mining) animation
    local harvestFrames = {}
    for i = 0, PEON_ANIM_FRAMES.harvest - 1 do
        table.insert(harvestFrames, i)
    end

    PeonSpriteCache:prerender("harvest", function(params)
        local phase = params.frame / PEON_ANIM_FRAMES.harvest * math.pi * 2
        local armSwing = math.sin(phase) * 1.5
        drawPeonBodyAtOrigin({
            state = "harvest",
            carry = "none",  -- Don't carry while harvesting
            breathe = 0,
            armSwing = armSwing,
            axeAngle = 0
        })
    end, {
        carry = {"none"},
        frame = harvestFrames
    })

    local stats = PeonSpriteCache:getStats()
    print(string.format("  Prerendered %d peon sprite canvases (%.2f MB VRAM)",
        stats.canvasCount, stats.memoryMB))
end

-- Get current visual state and animation frame for sprite cache lookup
function Peon:getVisualState()
    local state, frameCount, animSpeed

    -- Determine visual state based on peon state
    if self.state == Peon.STATE_CHOPPING then
        state = "chop"
        frameCount = PEON_ANIM_FRAMES.chop
        animSpeed = 12  -- Fast chop animation
    elseif self.state == Peon.STATE_HARVESTING then
        state = "harvest"
        frameCount = PEON_ANIM_FRAMES.harvest
        animSpeed = 8
    elseif self.state == Peon.STATE_MOVING or self.state == Peon.STATE_RETURNING or self.state == Peon.STATE_GATHER_MOVING then
        state = "walk"
        frameCount = PEON_ANIM_FRAMES.walk
        animSpeed = 10  -- Walk bob speed
    else
        state = "idle"
        frameCount = PEON_ANIM_FRAMES.idle
        animSpeed = 1.5  -- Slow breathing
    end

    -- Determine carry state
    local carry
    if self.carryingGold > 0 then
        carry = "gold"
    elseif self.carryingLumber > 0 then
        carry = "lumber"
    else
        carry = "none"
    end

    -- For chop/harvest, override carry to none (tools shown instead)
    if state == "chop" or state == "harvest" then
        carry = "none"
    end

    -- Calculate animation frame (quantize continuous animTimer to discrete frames)
    local phase = self.animTimer * animSpeed
    local frame = math.floor(phase % frameCount)

    -- Calculate vertical offset for bounce effects (not cached, applied during draw)
    local yOffset = 0
    if state == "chop" then
        yOffset = math.abs(math.sin(self.animTimer * 12)) * 6
    elseif state == "walk" then
        yOffset = math.abs(math.sin(self.animTimer * 10)) * 2
    elseif state == "idle" then
        if DrawUtils then
            yOffset = DrawUtils.getIdleBob(self.idleSeed, 0.8)
        else
            yOffset = math.sin(self.animTimer * 1.5 + self.idleSeed) * 1.2
        end
    end

    return state, carry, frame, yOffset
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

-- Check if peon should ignore collisions with other units
-- Only true when actively mining with gold (harvesting inside mine or returning gold to town hall)
function Peon:shouldIgnoreUnitCollisions()
    -- Inside the mine harvesting
    if self.state == Peon.STATE_HARVESTING and self.targetMine then
        return true
    end
    -- Returning gold to town hall as part of mining job
    if self.state == Peon.STATE_RETURNING and self.carryingGold > 0 and self.targetMine then
        return true
    end
    return false
end

-- Get separation force from nearby units (pushes units apart when overlapping)
-- Same approach as Unit class - standard RTS behavior
-- Uses quadtree for O(log n) neighbor lookup when available
function Peon:getUnitSeparation()
    -- Skip separation when actively mining with gold
    if self:shouldIgnoreUnitCollisions() then
        return 0, 0
    end

    local sepX, sepY = 0, 0
    local separationDist = self.radius * 2.5  -- Start separating when within ~2.5 radii

    -- Use quadtree query if available, otherwise fall back to linear scan
    local nearbyUnits
    if self.unitQuadtreeRef then
        -- Clear and reuse the results table to avoid allocation
        for i = 1, #separationQueryResults do
            separationQueryResults[i] = nil
        end
        nearbyUnits = self.unitQuadtreeRef:query(self.worldX, self.worldY, separationDist, separationQueryResults, getUnitX, getUnitY)
    else
        nearbyUnits = self.allUnitsRef
    end

    if not nearbyUnits then return 0, 0 end

    for _, other in ipairs(nearbyUnits) do
        if other ~= self and other.worldX and other.worldY then
            -- Skip invisible units (inside buildings)
            if other.visible == false then
                goto continue
            end

            -- Skip other units that are also ignoring collisions (other mining peons with gold)
            if other.shouldIgnoreUnitCollisions and other:shouldIgnoreUnitCollisions() then
                goto continue
            end

            local dx = self.worldX - other.worldX
            local dy = self.worldY - other.worldY
            local dist = math.sqrt(dx * dx + dy * dy)

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

            ::continue::
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

-- Building collision query radius: peon radius + max building half-size (3x3 tiles = 48 pixels)
local BUILDING_QUERY_RADIUS = 14 + 48 + 16  -- Extra margin for safety

-- Accessor functions for building quadtree queries
local function getBuildingQX(b)
    if b.getWorldBounds then
        local bx1, _, bx2, _ = b:getWorldBounds()
        return (bx1 + bx2) / 2
    end
    return b.gridX and b.gridX * 32 + 16 or 0
end
local function getBuildingQY(b)
    if b.getWorldBounds then
        local _, by1, _, by2 = b:getWorldBounds()
        return (by1 + by2) / 2
    end
    return b.gridY and b.gridY * 32 + 16 or 0
end

-- Reusable table for building queries (avoids allocation)
local buildingQueryResults = {}

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

    -- Use quadtree for spatial lookup if available
    local nearbyBuildings
    if self.buildingQuadtreeRef then
        -- Clear reusable table
        for i = 1, #buildingQueryResults do buildingQueryResults[i] = nil end
        -- Query buildings near the target position
        nearbyBuildings = self.buildingQuadtreeRef:query(newX, newY, BUILDING_QUERY_RADIUS, buildingQueryResults, getBuildingQX, getBuildingQY)
    else
        -- Fallback to checking all buildings
        nearbyBuildings = buildings
    end

    for _, b in ipairs(nearbyBuildings) do
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
    if not self.path then return end
    
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
    -- Apply unit separation force (same as Unit class)
    local sepX, sepY = self:getUnitSeparation()
    local sepStrength = 0.3
    
    -- Apply separation to direction
    dirX = dirX + sepX * sepStrength
    dirY = dirY + sepY * sepStrength
    
    -- Re-normalize direction
    local len = math.sqrt(dirX * dirX + dirY * dirY)
    if len > 0.1 then
        dirX = dirX / len
        dirY = dirY / len
    end
    
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

function Peon:update(dt, buildings, townHall, goldMine, resources)
    -- Update animation timer
    self.animTimer = self.animTimer + dt
    
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
    
    if self.state == Peon.STATE_MOVING then
        self:updateMoving(dt, buildings, goldMine)
    elseif self.state == Peon.STATE_GATHER_MOVING then
        self:updateGatherMoving(dt, buildings)
    elseif self.state == Peon.STATE_HARVESTING then
        self:updateHarvesting(dt, resources)
    elseif self.state == Peon.STATE_RETURNING then
        self:updateReturning(dt, buildings, townHall, resources)
    elseif self.state == Peon.STATE_CHOPPING then
        self:updateChopping(dt, resources)
    elseif self.state == Peon.STATE_BUILDING then
        -- Building update is handled by gameplay.lua
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
        self.carryingGold = self.harvestAmount
        self.visible = true
        self.state = Peon.STATE_RETURNING
    end
end

function Peon:updateReturning(dt, buildings, townHall, resources)
    -- Find nearest drop-off point
    -- For gold: town hall only
    -- For lumber: town hall or lumber mill (whichever is closer)
    local dropOffTarget = nil
    local dropOffDist = math.huge
    
    if self.carryingGold > 0 then
        -- Gold can only go to town hall
        if townHall then
            dropOffTarget = townHall
        end
    elseif self.carryingLumber > 0 then
        -- Lumber can go to town hall or lumber mill
        if townHall then
            local cx, cy = townHall:getWorldCenter()
            local dx, dy = cx - self.worldX, cy - self.worldY
            dropOffDist = dx*dx + dy*dy
            dropOffTarget = townHall
        end
        
        -- Check lumber mills for closer option
        if buildings then
            for _, b in ipairs(buildings) do
                if b.type == "lumbermill" and b.completed then
                    local cx, cy = b:getWorldCenter()
                    local dx, dy = cx - self.worldX, cy - self.worldY
                    local dist = dx*dx + dy*dy
                    if dist < dropOffDist then
                        dropOffDist = dist
                        dropOffTarget = b
                    end
                end
            end
        end
    end
    
    if not dropOffTarget then
        self.state = Peon.STATE_IDLE
        return
    end
    
    if self:isTouchingBuilding(dropOffTarget, 4) then
        if self.carryingGold > 0 then
            resources.gold = resources.gold + self.carryingGold
            self.carryingGold = 0
            if self.targetMine then
                local cx, cy = self.targetMine:getWorldCenter()
                self.targetX = cx
                self.targetY = cy
                self.path = nil  -- Clear path for new target
                self.currentWaypoint = 1
                self.state = Peon.STATE_MOVING
            else
                self.state = Peon.STATE_IDLE
            end
        elseif self.carryingLumber > 0 then
            resources.lumber = resources.lumber + self.carryingLumber
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
    
    local targetX, targetY = dropOffTarget:getWorldCenter()
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

function Peon:draw()
    if not self.visible then return end

    local x, y = self:getScreenPos()

    -- Get visual state and animation frame
    local state, carry, frame, yOffset = self:getVisualState()

    -- Apply vertical bounce offset
    y = y - yOffset

    -- Selection circle and shadow at base position (not affected by bounce)
    local baseY = y + yOffset
    if self.selected then
        if DrawUtils then
            DrawUtils.drawSelection(x, baseY, self.radius + 2)
        else
            love.graphics.setColor(0, 1, 0, 0.4)
            love.graphics.circle("fill", x, baseY, self.radius + 4)
            love.graphics.setColor(0, 1, 0, 0.8)
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

    -- Try to use cached canvas, fallback to live drawing
    local canvas = PeonSpriteCache and PeonSpriteCache:get(state, carry, frame)

    if canvas then
        -- Use cached sprite: 5 canvas blits instead of ~175 primitive draws
        -- Canvas origin is at (32, 54), so offset draw position accordingly
        local drawX = x - 32
        local drawY = y - 54

        -- Draw outline (4 offset blits)
        love.graphics.setColor(0.1, 0.08, 0.05, 0.7)
        local offsets = {{-1.5, 0}, {1.5, 0}, {0, -1.5}, {0, 1.5}}
        for _, off in ipairs(offsets) do
            love.graphics.draw(canvas, drawX + off[1], drawY + off[2])
        end

        -- Draw main sprite
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(canvas, drawX, drawY)

        -- Flash effect for damage (drawn live, not cached)
        if self.flashTimer and self.flashTimer > 0 then
            love.graphics.setBlendMode("add")
            love.graphics.setColor(1, 1, 1, 0.9)
            love.graphics.draw(canvas, drawX, drawY)
            love.graphics.setBlendMode("alpha")
        end
    else
        -- Fallback: live drawing when cache not available
        local breathe = math.sin(self.animTimer * 2 + self.idleSeed) * 0.5

        local function drawBody()
            -- Feet
            love.graphics.setColor(0.4, 0.3, 0.2, 1)
            love.graphics.ellipse("fill", x - 5, y + 7, 5, 3)
            love.graphics.ellipse("fill", x + 5, y + 7, 5, 3)

            -- Legs
            love.graphics.setColor(0.5, 0.35, 0.25, 1)
            love.graphics.rectangle("fill", x - 6, y + 2, 5, 7, 1)
            love.graphics.rectangle("fill", x + 1, y + 2, 5, 7, 1)

            -- Body (work shirt) - with breathing
            love.graphics.setColor(0.55, 0.45, 0.35, 1)
            love.graphics.rectangle("fill", x - 8 - breathe * 0.5, y - 6, 16 + breathe, 12, 2)

            -- Belt
            love.graphics.setColor(0.35, 0.25, 0.15, 1)
            love.graphics.rectangle("fill", x - 8, y + 1, 16, 3)
            love.graphics.setColor(0.6, 0.5, 0.2, 1)
            love.graphics.rectangle("fill", x - 2, y + 1, 4, 3)  -- Buckle

            -- Arms
            local armSwing = 0
            if self.state == Peon.STATE_MOVING or self.state == Peon.STATE_RETURNING or self.state == Peon.STATE_GATHER_MOVING then
                armSwing = math.sin(self.animTimer * 10) * 2
            end
            love.graphics.setColor(0.55, 0.45, 0.35, 1)
            love.graphics.rectangle("fill", x - 11, y - 4 + armSwing, 5, 10, 1)
            love.graphics.rectangle("fill", x + 6, y - 4 - armSwing, 5, 10, 1)

            -- Hands (skin tone)
            love.graphics.setColor(0.85, 0.7, 0.55, 1)
            love.graphics.circle("fill", x - 9, y + 4 + armSwing, 3)
            love.graphics.circle("fill", x + 9, y + 4 - armSwing, 3)

            -- Head
            love.graphics.setColor(0.85, 0.7, 0.55, 1)
            love.graphics.ellipse("fill", x, y - 10, 6, 7)

            -- Hood/cap
            love.graphics.setColor(0.5, 0.4, 0.3, 1)
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
                local axeAngle = 0
                if self.state == Peon.STATE_CHOPPING then
                    axeAngle = math.sin(self.animTimer * 12) * 0.4
                end
                love.graphics.push()
                love.graphics.translate(x + 12, y)
                love.graphics.rotate(axeAngle)
                love.graphics.setColor(0.5, 0.35, 0.2, 1)
                love.graphics.rectangle("fill", -2, -8, 2, 14, 1)
                love.graphics.setColor(0.65, 0.65, 0.7, 1)
                love.graphics.polygon("fill", -3, -8, 4, -6, 4, -2, -3, -4)
                love.graphics.setColor(0.85, 0.85, 0.9, 0.6)
                love.graphics.line(-1, -7, 2, -5)
                love.graphics.pop()
            elseif self.state == Peon.STATE_HARVESTING or self.carryingGold > 0 then
                love.graphics.setColor(0.5, 0.35, 0.2, 1)
                love.graphics.rectangle("fill", x + 10, y - 6, 2, 12, 1)
                love.graphics.setColor(0.55, 0.55, 0.6, 1)
                love.graphics.polygon("fill", x + 8, y - 8, x + 18, y - 6, x + 14, y - 2)
                love.graphics.setColor(0.75, 0.75, 0.8, 0.5)
                love.graphics.line(x + 10, y - 7, x + 15, y - 5)
            end

            -- Carried resources
            if self.carryingGold > 0 then
                love.graphics.setColor(0.65, 0.5, 0.12, 1)
                love.graphics.ellipse("fill", x, y - 2, 7, 6)
                love.graphics.setColor(0.9, 0.75, 0.15, 1)
                love.graphics.circle("fill", x - 2, y - 3, 3)
                love.graphics.circle("fill", x + 2, y - 1, 2.5)
                love.graphics.setColor(1, 0.95, 0.5, 0.7)
                love.graphics.circle("fill", x - 3, y - 4, 1.5)
            elseif self.carryingLumber > 0 then
                love.graphics.setColor(0.5, 0.35, 0.18, 1)
                love.graphics.rectangle("fill", x - 4, y - 14, 3, 12, 1)
                love.graphics.setColor(0.55, 0.4, 0.2, 1)
                love.graphics.rectangle("fill", x - 1, y - 16, 3, 14, 1)
                love.graphics.setColor(0.5, 0.36, 0.19, 1)
                love.graphics.rectangle("fill", x + 2, y - 13, 3, 11, 1)
                love.graphics.setColor(0.65, 0.5, 0.3, 0.5)
                love.graphics.line(x - 3, y - 13, x - 3, y - 5)
                love.graphics.line(x, y - 15, x, y - 4)
            end
        end

        -- Draw with outline
        if DrawUtils and Effects then
            love.graphics.setColor(0.1, 0.08, 0.05, 0.7)
            local offsets = {{-1.5, 0}, {1.5, 0}, {0, -1.5}, {0, 1.5}}
            for _, off in ipairs(offsets) do
                love.graphics.push()
                love.graphics.translate(off[1], off[2])
                drawBody()
                love.graphics.pop()
            end
            DrawUtils.applyFlash(self, drawBody)
        else
            drawBody()
        end
    end

    -- Draw health bar (always live)
    self:drawHealthBar()

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

-- Gather-move: move toward destination, auto-gather closest resource in sight
function Peon:gatherMoveTo(worldX, worldY, goldMines, resources)
    self.gatherMoveDestX = worldX
    self.gatherMoveDestY = worldY
    self.goldMinesRef = goldMines
    self.resourcesRef = resources
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
    self.path = nil
    self.currentWaypoint = 1
    self.state = Peon.STATE_GATHER_MOVING
end

-- Find closest resource (tree or mine) within sight radius
function Peon:findClosestResource()
    if not self.map then return nil, nil end
    
    local myGridX, myGridY = self.map:worldToGrid(self.worldX, self.worldY)
    local sightRange = self.sightRadius or 5
    local closestDist = math.huge
    local closestMine = nil
    local closestTreeX, closestTreeY = nil, nil
    
    -- Check for gold mines in sight
    if self.goldMinesRef then
        for _, mine in ipairs(self.goldMinesRef) do
            if not mine.depleted then
                local mx, my = mine:getWorldCenter()
                local mineGridX, mineGridY = self.map:worldToGrid(mx, my)
                local dx = mineGridX - myGridX
                local dy = mineGridY - myGridY
                local dist = math.sqrt(dx*dx + dy*dy)
                if dist <= sightRange and dist < closestDist then
                    closestDist = dist
                    closestMine = mine
                    closestTreeX, closestTreeY = nil, nil
                end
            end
        end
    end
    
    -- Check for trees in sight
    for dy = -sightRange, sightRange do
        for dx = -sightRange, sightRange do
            local dist = math.sqrt(dx*dx + dy*dy)
            if dist <= sightRange then
                local tx, ty = myGridX + dx, myGridY + dy
                if self.map:isTileTree(tx, ty) then
                    if dist < closestDist then
                        closestDist = dist
                        closestMine = nil
                        closestTreeX, closestTreeY = tx, ty
                    end
                end
            end
        end
    end
    
    return closestMine, closestTreeX, closestTreeY
end

-- Update gather-move state
function Peon:updateGatherMoving(dt, buildings)
    -- First, check for nearby resources to gather
    local closestMine, treeX, treeY = self:findClosestResource()
    
    if closestMine then
        -- Found a mine, go gather from it
        self:goToMine(closestMine)
        return
    elseif treeX and treeY then
        -- Found a tree, go chop it
        self:goToTree(treeX, treeY)
        return
    end
    
    -- No resources in sight, continue moving toward destination
    if not self.targetX or not self.targetY then
        self.state = Peon.STATE_IDLE
        return
    end
    
    -- Check if we've reached the destination
    local dx = self.targetX - self.worldX
    local dy = self.targetY - self.worldY
    local dist = math.sqrt(dx * dx + dy * dy)
    
    if dist < 8 then
        -- Reached destination, go idle
        self.state = Peon.STATE_IDLE
        self.gatherMoveDestX = nil
        self.gatherMoveDestY = nil
        return
    end
    
    -- Move toward destination (reuse moving logic)
    self:moveTowardTarget(dt, buildings)
end

-- Helper: move toward current target (shared by moving and gather-moving)
function Peon:moveTowardTarget(dt, buildings)
    if not self.targetX or not self.targetY then return end
    
    local dx = self.targetX - self.worldX
    local dy = self.targetY - self.worldY
    local dist = math.sqrt(dx * dx + dy * dy)
    
    if dist > 1 then
        local dirX = dx / dist
        local dirY = dy / dist
        
        -- Apply unit separation force (same as Unit class)
        local sepX, sepY = self:getUnitSeparation()
        local sepStrength = 0.3
        
        dirX = dirX + sepX * sepStrength
        dirY = dirY + sepY * sepStrength
        
        -- Re-normalize direction
        local len = math.sqrt(dirX * dirX + dirY * dirY)
        if len > 0.1 then
            dirX = dirX / len
            dirY = dirY / len
        end
        
        local moveX = dirX * self.speed * dt
        local moveY = dirY * self.speed * dt
        
        local newX = self.worldX + moveX
        local newY = self.worldY + moveY
        
        -- Check building collisions
        local canMove = true
        if buildings then
            for _, building in ipairs(buildings) do
                if self:wouldCollideWithBuilding(newX, newY, building) then
                    canMove = false
                    break
                end
            end
        end
        
        if canMove then
            self.worldX = newX
            self.worldY = newY
        end
    end
end

function Peon:getStateText()
    if self.state == Peon.STATE_GATHER_MOVING then
        return "Gather Move"
    elseif self.state == Peon.STATE_RETURNING then
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
function Peon:updateUI(resources, screenW, screenH, font, startBuildCallback)
    -- UI now handled by command buttons in gameplay.lua
end

function Peon:drawUI()
    -- UI now handled by command buttons in gameplay.lua
end

function Peon:mousepressed(x, y, button)
    -- UI now handled by command buttons in gameplay.lua
end

function Peon:mousereleased(x, y, button)
    -- UI now handled by command buttons in gameplay.lua
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

function Peon:isDead()
    return self.hp <= 0
end

function Peon:takeDamage(amount)
    self.hp = self.hp - amount
    self.flashTimer = 0.1
    return self.hp <= 0
end

function Peon:drawHealthBar()
    if not self.selected and self.hp >= self.maxHp then return end
    
    local x, y = self:getScreenPos()
    local barWidth = 24
    local barHeight = 4
    local barY = y - self.radius - 8
    
    -- Background
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", x - barWidth/2 - 1, barY - 1, barWidth + 2, barHeight + 2)
    
    -- Health bar
    local healthPct = self.hp / self.maxHp
    local r = healthPct < 0.5 and 1 or (1 - healthPct) * 2
    local g = healthPct > 0.5 and 1 or healthPct * 2
    love.graphics.setColor(r, g, 0, 1)
    love.graphics.rectangle("fill", x - barWidth/2, barY, barWidth * healthPct, barHeight)
end

return Peon
