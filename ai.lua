--[[
    AI Controller - Personality System
    
    BLINKY (Red) - Aggressive grunt rush
    Build Order: Farm -> Barracks -> Farm -> 4 Footmen -> Attack
]]

local Teams
pcall(function() Teams = require("teams") end)

local AI = {}
AI.__index = AI

-- Costs for all buildings/units
AI.COSTS = {
    peon = { gold = 75, lumber = 0 },
    farm = { gold = 250, lumber = 100 },
    barracks = { gold = 500, lumber = 200 },
    footman = { gold = 135, lumber = 0 },
}

-- Population constants
AI.BASE_POP = 4
AI.POP_PER_FARM = 4

-- Personality definitions (build orders)
AI.PERSONALITIES = {
    -- BLINKY: Aggressive 2-grunt rush
    -- Start: 1000g, 400L, pop 7/8 (base 4 + 1 farm)
    -- Rush with just 2 footmen for speed!
    blinky = {
        name = "Blinky",
        buildOrder = {
            {type = "barracks"},   -- 500g, 200L
            {type = "footman"},    -- 135g (can train while barracks finishes... wait no, need barracks done)
            {type = "footman"},    -- 135g
            {type = "attack"},     -- GO NOW with 2!
            {type = "farm"},       -- Then expand
            {type = "footman"},    
            {type = "footman"},    
            {type = "attack"},     -- Second wave
        },
        lumberRatio = 7,
        attackWaveSize = 2,  -- Only need 2 to attack!
        attackCooldown = 20,
    },
    
    -- PASSIVE: Tutorial AI - builds units but never attacks
    passive = {
        name = "Passive",
        buildOrder = {
            {type = "barracks"},
            {type = "farm"},
            {type = "footman"},
            {type = "footman"},
            {type = "farm"},
            {type = "footman"},
            {type = "footman"},
            -- No attack command - just keeps building
        },
        lumberRatio = 7,
        attackWaveSize = 99,  -- Will never reach this
        attackCooldown = 9999,
        passive = true,  -- Flag to disable aggression
    },
}

function AI.new(params)
    local self = setmetatable({}, AI)

    self.team = params.team or (Teams and Teams.ENEMY or 2)
    self.townHall = params.townHall
    self.map = params.map

    -- Resources (AI has its own economy)
    self.gold = params.startGold or 1000
    self.lumber = params.startLumber or 400

    -- Unit/building tracking
    self.peons = {}
    self.footmen = {}
    self.farms = {}
    self.barracksBuildings = {}

    -- Peon assignment tracking
    self.totalPeonsSpawned = params.startingPeons or 7
    self.peonsOnGold = 6  -- Starting assignment
    self.peonsOnLumber = 1

    -- Building state tracking
    self.isBuildingFarm = false
    self.isBuildingBarracks = false

    -- Timers
    self.thinkTimer = 0
    self.thinkInterval = 0.5
    self.gameTime = 0

    -- Load personality
    local personalityName = params.personality or "blinky"
    self.personality = AI.PERSONALITIES[personalityName]
    self.buildOrderIndex = 1
    self.buildOrderComplete = false

    -- Attack tracking
    self.lastAttackTime = 0

    return self
end

function AI:canAfford(gold, lumber)
    return self.gold >= gold and self.lumber >= lumber
end

function AI:spend(gold, lumber)
    self.gold = self.gold - gold
    self.lumber = self.lumber - lumber
end

function AI:addGold(amount)
    self.gold = self.gold + amount
end

function AI:addLumber(amount)
    self.lumber = self.lumber + amount
end

function AI:getPopulation()
    local currentPop = #self.peons + #self.footmen
    local maxPop = AI.BASE_POP + #self.farms * AI.POP_PER_FARM
    return currentPop, maxPop
end

function AI:isSupplyCapped()
    local current, max = self:getPopulation()
    return current >= max
end

-- Find closest mine to a position
function AI:findClosestMine(worldX, worldY, goldMines)
    local closestMine = nil
    local closestDist = math.huge
    
    for _, mine in ipairs(goldMines) do
        if not mine.depleted then
            local mx, my = mine:getWorldCenter()
            local dx = mx - worldX
            local dy = my - worldY
            local dist = dx * dx + dy * dy
            if dist < closestDist then
                closestDist = dist
                closestMine = mine
            end
        end
    end
    
    return closestMine
end

-- Find a tree near the townhall
function AI:findNearbyTree()
    if not self.townHall or not self.map then return nil, nil end
    
    local thX, thY = self.townHall:getWorldCenter()
    local gridX, gridY = self.map:worldToGrid(thX, thY)
    
    for radius = 3, 15 do
        for dx = -radius, radius do
            for dy = -radius, radius do
                if math.abs(dx) == radius or math.abs(dy) == radius then
                    local checkX = gridX + dx
                    local checkY = gridY + dy
                    if self.map:isTileTree(checkX, checkY) then
                        return checkX, checkY
                    end
                end
            end
        end
    end
    
    return nil, nil
end

-- Get available peon for building
function AI:getIdlePeon()
    -- First prefer truly idle peons
    for _, peon in ipairs(self.peons) do
        if peon.state == "Idle" and not peon:isDead() then
            return peon
        end
    end
    
    -- Second, find a peon not carrying resources
    for _, peon in ipairs(self.peons) do
        if not peon:isDead() and 
           (peon.carryingGold or 0) == 0 and 
           (peon.carryingLumber or 0) == 0 and
           peon.state ~= "Building" then
            return peon
        end
    end
    
    return nil
end

-- Find valid building location near townhall
function AI:findBuildLocation(buildingSize)
    if not self.townHall or not self.map then return nil, nil end
    
    -- Initialize pending locations if needed
    if not self.pendingBuildLocations then
        self.pendingBuildLocations = {}
    end
    
    local thGridX = self.townHall.gridX
    local thGridY = self.townHall.gridY
    
    for radius = 4, 12 do
        for dx = -radius, radius do
            for dy = -radius, radius do
                if math.abs(dx) >= 4 or math.abs(dy) >= 4 then
                    local checkX = thGridX + dx
                    local checkY = thGridY + dy
                    
                    local clear = true
                    
                    -- Check map passability
                    for bx = 0, buildingSize - 1 do
                        for by = 0, buildingSize - 1 do
                            if not self.map:isTilePassable(checkX + bx, checkY + by) then
                                clear = false
                                break
                            end
                        end
                        if not clear then break end
                    end
                    
                    -- Check pending build locations
                    if clear then
                        for _, pending in ipairs(self.pendingBuildLocations) do
                            -- Check if areas overlap
                            local overlapX = checkX < pending.x + pending.size and checkX + buildingSize > pending.x
                            local overlapY = checkY < pending.y + pending.size and checkY + buildingSize > pending.y
                            if overlapX and overlapY then
                                clear = false
                                break
                            end
                        end
                    end
                    
                    if clear then
                        -- Reserve this location
                        table.insert(self.pendingBuildLocations, {
                            x = checkX, y = checkY, size = buildingSize
                        })
                        return checkX, checkY
                    end
                end
            end
        end
    end
    
    return nil, nil
end

-- Clear pending location when building completes or is cancelled
function AI:clearPendingLocation(gridX, gridY)
    if not self.pendingBuildLocations then return end
    for i = #self.pendingBuildLocations, 1, -1 do
        local p = self.pendingBuildLocations[i]
        if p.x == gridX and p.y == gridY then
            table.remove(self.pendingBuildLocations, i)
            return
        end
    end
end

function AI:syncUnits(gameplayPeons, gameplayFootmen, gameplayFarms, gameplayBarracks)
    -- Sync peons
    self.peons = {}
    self.peonsOnGold = 0
    self.peonsOnLumber = 0
    
    for _, peon in ipairs(gameplayPeons) do
        if peon.team == self.team and not (peon.isDead and peon:isDead()) then
            table.insert(self.peons, peon)
            -- Count by activity
            if peon.targetMine then
                self.peonsOnGold = self.peonsOnGold + 1
            elseif peon.targetTreeX then
                self.peonsOnLumber = self.peonsOnLumber + 1
            end
        end
    end
    
    -- Sync footmen
    self.footmen = {}
    for _, footman in ipairs(gameplayFootmen) do
        if footman.team == self.team and not (footman.isDead and footman:isDead()) then
            table.insert(self.footmen, footman)
        end
    end
    
    -- Sync farms (only completed ones count for pop)
    self.farms = {}
    self.isBuildingFarm = false
    for _, farm in ipairs(gameplayFarms) do
        if farm.team == self.team then
            if farm.completed then
                table.insert(self.farms, farm)
            else
                self.isBuildingFarm = true
            end
        end
    end
    
    -- Sync barracks
    self.barracksBuildings = {}
    self.isBuildingBarracks = false
    for _, barrack in ipairs(gameplayBarracks) do
        if barrack.team == self.team then
            if barrack.completed then
                table.insert(self.barracksBuildings, barrack)
            else
                self.isBuildingBarracks = true
            end
        end
    end
end

-- Main update
function AI:update(dt, goldMines, playerTownHall, createBuildingCallback, gameplayPeons, gameplayFootmen, gameplayFarms, gameplayBarracks)
    self.thinkTimer = self.thinkTimer + dt
    self.gameTime = self.gameTime + dt

    if self.thinkTimer < self.thinkInterval then
        return
    end
    self.thinkTimer = 0

    -- Don't do anything if townhall is dead
    if not self.townHall or (self.townHall.isDead and self.townHall:isDead()) then
        return
    end
    
    -- Sync with gameplay state
    self:syncUnits(gameplayPeons, gameplayFootmen, gameplayFarms, gameplayBarracks)
    
    -- Execute build order
    self:executeBuildOrder(goldMines, playerTownHall, createBuildingCallback)
end

function AI:executeBuildOrder(goldMines, playerTownHall, createBuildingCallback)
    if self.buildOrderComplete then
        -- After build order, just keep attacking
        if self.gameTime - self.lastAttackTime > self.personality.attackCooldown then
            if self:tryAttack(playerTownHall) then
                self.lastAttackTime = self.gameTime
            end
        end
        return
    end
    
    if self.buildOrderIndex > #self.personality.buildOrder then
        self.buildOrderComplete = true
        return
    end
    
    local currentItem = self.personality.buildOrder[self.buildOrderIndex]
    local success = false
    
    if currentItem.type == "farm" then
        success = self:tryBuildFarm(createBuildingCallback)
    elseif currentItem.type == "barracks" then
        success = self:tryBuildBarracks(createBuildingCallback)
    elseif currentItem.type == "peon" then
        success = self:tryBuildPeon(goldMines)
    elseif currentItem.type == "footman" then
        success = self:tryTrainFootman()
    elseif currentItem.type == "attack" then
        success = self:tryAttack(playerTownHall)
        if success then
            self.lastAttackTime = self.gameTime
        end
    end
    
    if success then
        self.buildOrderIndex = self.buildOrderIndex + 1
    end
end

function AI:tryBuildPeon(goldMines)
    if not self.townHall then return false end
    if self.townHall.isProducing then return false end

    local cost = AI.COSTS.peon
    if not self:canAfford(cost.gold, cost.lumber) then return false end

    if self:isSupplyCapped() then
        return false
    end

    self:spend(cost.gold, cost.lumber)
    self.townHall:startProduction()
    self.totalPeonsSpawned = self.totalPeonsSpawned + 1

    -- Log AI queue action
    if Game and Game.Replay then Game.Replay.log("QUEUE", "AI queued Peon at Town Hall") end

    return true
end

function AI:tryBuildFarm(createBuildingCallback)
    if self.isBuildingFarm then return false end  -- Already building one

    local cost = AI.COSTS.farm
    if not self:canAfford(cost.gold, cost.lumber) then return false end

    local peon = self:getIdlePeon()
    if not peon then return false end

    local gridX, gridY = self:findBuildLocation(2)
    if not gridX then return false end

    self:spend(cost.gold, cost.lumber)
    self.isBuildingFarm = true

    if createBuildingCallback then
        createBuildingCallback(peon, "farm", gridX, gridY, self.team)
    end

    return true
end

function AI:tryBuildBarracks(createBuildingCallback)
    if self.isBuildingBarracks then return false end
    if #self.barracksBuildings > 0 then return true end  -- Already have one

    local cost = AI.COSTS.barracks
    if not self:canAfford(cost.gold, cost.lumber) then return false end

    local peon = self:getIdlePeon()
    if not peon then return false end

    local gridX, gridY = self:findBuildLocation(3)
    if not gridX then return false end

    self:spend(cost.gold, cost.lumber)
    self.isBuildingBarracks = true

    if createBuildingCallback then
        createBuildingCallback(peon, "barracks", gridX, gridY, self.team)
    end

    return true
end

function AI:tryTrainFootman()
    if #self.barracksBuildings == 0 then return false end

    local barracks = self.barracksBuildings[1]
    if barracks.isProducing then return false end

    local cost = AI.COSTS.footman
    if not self:canAfford(cost.gold, cost.lumber) then return false end

    if self:isSupplyCapped() then return false end

    self:spend(cost.gold, cost.lumber)
    barracks:startProduction("footman")

    -- Log AI queue action
    if Game and Game.Replay then Game.Replay.log("QUEUE", "AI queued Footman at Barracks") end

    return true
end

function AI:tryAttack(playerTownHall)
    if not playerTownHall then return true end
    if playerTownHall.isDead and playerTownHall:isDead() then return true end

    -- Gather idle footmen
    local attackers = {}
    for _, footman in ipairs(self.footmen) do
        if footman.state == "Idle" and not footman:isDead() then
            table.insert(attackers, footman)
        end
    end

    if #attackers < self.personality.attackWaveSize then
        return false
    end

    -- Send them to attack!
    for _, footman in ipairs(attackers) do
        footman:setAttackTarget(playerTownHall)
    end

    return true
end

-- Called when a new peon spawns
function AI:onPeonSpawned(peon, goldMines)
    local peonNumber = self.totalPeonsSpawned
    local lumberRatio = self.personality.lumberRatio or 7

    if peonNumber % lumberRatio == 0 then
        local treeX, treeY = self:findNearbyTree()
        if treeX and peon.goToTree then
            peon:goToTree(treeX, treeY)
        else
            local mine = self:findClosestMine(peon.worldX, peon.worldY, goldMines)
            if mine and peon.goToMine then
                peon:goToMine(mine)
            end
        end
    else
        local mine = self:findClosestMine(peon.worldX, peon.worldY, goldMines)
        if mine and peon.goToMine then
            peon:goToMine(mine)
        end
    end
end

function AI:onResourceReturned(resourceType, amount)
    if resourceType == "gold" then
        self:addGold(amount)
    elseif resourceType == "lumber" then
        self:addLumber(amount)
    end
end

return AI
