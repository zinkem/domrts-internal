--[[
    AI Controller
    Manages enemy faction with build order queue
]]

local Teams
pcall(function() Teams = require("teams") end)

local AI = {}
AI.__index = AI

-- Build order action types
AI.ACTION_BUILD_PEON = "build_peon"
AI.ACTION_BUILD_FARM = "build_farm"
AI.ACTION_BUILD_BARRACKS = "build_barracks"
AI.ACTION_TRAIN_FOOTMAN = "train_footman"
AI.ACTION_ATTACK = "attack"

-- Costs
AI.COSTS = {
    peon = { gold = 75, lumber = 0 },
    farm = { gold = 250, lumber = 100 },
    barracks = { gold = 500, lumber = 200 },
    footman = { gold = 135, lumber = 0 },
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
    self.barracks = nil
    self.farms = {}
    
    -- Peon assignment counters
    self.totalPeonsSpawned = 0
    self.peonsOnLumber = 0
    
    -- Build order queue
    self.buildOrder = {}
    self.currentAction = nil
    self.actionState = "waiting"  -- waiting, in_progress
    
    -- Attack wave tracking
    self.footmenForAttack = {}
    self.attackWaveSize = 4
    
    -- Timers
    self.thinkTimer = 0
    self.thinkInterval = 0.5  -- Think every 0.5 seconds
    
    -- Initialize default build order
    self:initBuildOrder()
    
    return self
end

function AI:initBuildOrder()
    -- Initial build order
    self:queueAction(AI.ACTION_BUILD_PEON)
    self:queueAction(AI.ACTION_BUILD_FARM)
    self:queueAction(AI.ACTION_BUILD_PEON)
    self:queueAction(AI.ACTION_BUILD_BARRACKS)
    self:queueAction(AI.ACTION_BUILD_PEON)
    self:queueAction(AI.ACTION_BUILD_PEON)
    -- Train footmen
    for i = 1, 4 do
        self:queueAction(AI.ACTION_TRAIN_FOOTMAN)
    end
    self:queueAction(AI.ACTION_ATTACK)
    -- Continue building economy and army
    self:queueAction(AI.ACTION_BUILD_PEON)
    self:queueAction(AI.ACTION_BUILD_PEON)
    for i = 1, 4 do
        self:queueAction(AI.ACTION_TRAIN_FOOTMAN)
    end
    self:queueAction(AI.ACTION_ATTACK)
end

function AI:queueAction(actionType)
    table.insert(self.buildOrder, { type = actionType })
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
    
    -- Search in expanding rings for a tree
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

-- Get idle peon for building
function AI:getIdlePeon()
    for _, peon in ipairs(self.peons) do
        if peon.state == "Idle" and not peon:isDead() then
            return peon
        end
    end
    return nil
end

-- Find valid building location near townhall
function AI:findBuildLocation(buildingSize)
    if not self.townHall or not self.map then return nil, nil end
    
    local thGridX = self.townHall.gridX
    local thGridY = self.townHall.gridY
    
    -- Search for clear area near townhall
    for radius = 4, 12 do
        for dx = -radius, radius do
            for dy = -radius, radius do
                if math.abs(dx) >= 4 or math.abs(dy) >= 4 then
                    local checkX = thGridX + dx
                    local checkY = thGridY + dy
                    
                    -- Check if area is clear
                    local clear = true
                    for bx = 0, buildingSize - 1 do
                        for by = 0, buildingSize - 1 do
                            if not self.map:isTilePassable(checkX + bx, checkY + by) then
                                clear = false
                                break
                            end
                        end
                        if not clear then break end
                    end
                    
                    if clear then
                        return checkX, checkY
                    end
                end
            end
        end
    end
    
    return nil, nil
end

function AI:update(dt, goldMines, playerTownHall, createBuildingCallback, gameplayPeons, gameplayFootmen, gameplayFarms, gameplayBarracks)
    self.thinkTimer = self.thinkTimer + dt
    
    if self.thinkTimer < self.thinkInterval then
        return
    end
    self.thinkTimer = 0
    
    -- Sync our tracking lists with gameplay lists (filter by team)
    self:syncUnits(gameplayPeons, gameplayFootmen, gameplayFarms, gameplayBarracks)
    
    -- Process current action
    if #self.buildOrder > 0 and self.actionState == "waiting" then
        self:processNextAction(goldMines, playerTownHall, createBuildingCallback)
    end
    
    -- Keep queueing more actions if build order is low
    if #self.buildOrder < 5 then
        self:queueMoreActions()
    end
end

function AI:syncUnits(gameplayPeons, gameplayFootmen, gameplayFarms, gameplayBarracks)
    -- Sync peons
    self.peons = {}
    for _, peon in ipairs(gameplayPeons) do
        if peon.team == self.team then
            table.insert(self.peons, peon)
        end
    end
    
    -- Sync footmen
    self.footmen = {}
    for _, footman in ipairs(gameplayFootmen) do
        if footman.team == self.team then
            table.insert(self.footmen, footman)
        end
    end
    
    -- Sync farms
    self.farms = {}
    for _, farm in ipairs(gameplayFarms) do
        if farm.team == self.team then
            table.insert(self.farms, farm)
        end
    end
    
    -- Sync barracks
    self.barracks = nil
    for _, barrack in ipairs(gameplayBarracks) do
        if barrack.team == self.team and barrack.completed then
            self.barracks = barrack
            break
        end
    end
end

function AI:processNextAction(goldMines, playerTownHall, createBuildingCallback)
    local action = self.buildOrder[1]
    if not action then return end
    
    local success = false
    
    if action.type == AI.ACTION_BUILD_PEON then
        success = self:tryBuildPeon(goldMines)
    elseif action.type == AI.ACTION_BUILD_FARM then
        success = self:tryBuildFarm(createBuildingCallback)
    elseif action.type == AI.ACTION_BUILD_BARRACKS then
        success = self:tryBuildBarracks(createBuildingCallback)
    elseif action.type == AI.ACTION_TRAIN_FOOTMAN then
        success = self:tryTrainFootman()
    elseif action.type == AI.ACTION_ATTACK then
        success = self:tryAttack(playerTownHall)
    end
    
    if success then
        table.remove(self.buildOrder, 1)
    end
end

function AI:tryBuildPeon(goldMines)
    if not self.townHall then return false end
    if self.townHall.isProducing then return false end
    
    local cost = AI.COSTS.peon
    if not self:canAfford(cost.gold, cost.lumber) then return false end
    
    -- Check population
    local currentPop = #self.peons + #self.footmen
    local maxPop = 4 + #self.farms * 4  -- BASE_CAPACITY + farms
    if currentPop >= maxPop then return false end
    
    self:spend(cost.gold, cost.lumber)
    self.townHall:startProduction()
    self.totalPeonsSpawned = self.totalPeonsSpawned + 1
    
    return true
end

function AI:tryBuildFarm(createBuildingCallback)
    local cost = AI.COSTS.farm
    if not self:canAfford(cost.gold, cost.lumber) then return false end
    
    local peon = self:getIdlePeon()
    if not peon then return false end
    
    local gridX, gridY = self:findBuildLocation(2)  -- Farm is 2x2
    if not gridX then return false end
    
    self:spend(cost.gold, cost.lumber)
    
    -- Tell peon to build
    if createBuildingCallback then
        createBuildingCallback(peon, "farm", gridX, gridY, self.team)
    end
    
    return true
end

function AI:tryBuildBarracks(createBuildingCallback)
    -- Only build one barracks
    if self.barracks then return true end  -- Already have one, skip
    
    local cost = AI.COSTS.barracks
    if not self:canAfford(cost.gold, cost.lumber) then return false end
    
    local peon = self:getIdlePeon()
    if not peon then return false end
    
    local gridX, gridY = self:findBuildLocation(3)  -- Barracks is 3x3
    if not gridX then return false end
    
    self:spend(cost.gold, cost.lumber)
    
    if createBuildingCallback then
        createBuildingCallback(peon, "barracks", gridX, gridY, self.team)
    end
    
    return true
end

function AI:tryTrainFootman()
    if not self.barracks then return false end
    if self.barracks.isProducing then return false end
    
    local cost = AI.COSTS.footman
    if not self:canAfford(cost.gold, cost.lumber) then return false end
    
    -- Check population
    local currentPop = #self.peons + #self.footmen
    local maxPop = 4 + #self.farms * 4
    if currentPop >= maxPop then return false end
    
    self:spend(cost.gold, cost.lumber)
    self.barracks:startProduction("footman")
    
    return true
end

function AI:tryAttack(playerTownHall)
    if not playerTownHall then return true end  -- No target, skip
    
    -- Gather idle footmen for attack
    local attackers = {}
    for _, footman in ipairs(self.footmen) do
        if footman.state == "Idle" and not footman:isDead() then
            table.insert(attackers, footman)
        end
    end
    
    if #attackers < self.attackWaveSize then
        return false  -- Wait for more footmen
    end
    
    -- Send them to attack!
    for _, footman in ipairs(attackers) do
        footman:setAttackTarget(playerTownHall)
    end
    
    return true
end

function AI:queueMoreActions()
    -- Continuous economy: keep building peons
    self:queueAction(AI.ACTION_BUILD_PEON)
    self:queueAction(AI.ACTION_BUILD_PEON)
    
    -- Build more farms if needed
    local currentPop = #self.peons + #self.footmen
    local maxPop = 4 + #self.farms * 4
    if currentPop >= maxPop - 2 then
        self:queueAction(AI.ACTION_BUILD_FARM)
    end
    
    -- Train footmen and attack
    for i = 1, 4 do
        self:queueAction(AI.ACTION_TRAIN_FOOTMAN)
    end
    self:queueAction(AI.ACTION_ATTACK)
end

-- Called when a new peon spawns for the AI
function AI:onPeonSpawned(peon, goldMines)
    -- Decide if this peon goes to lumber or gold
    -- Every 6th peon goes to lumber
    local peonNumber = self.totalPeonsSpawned
    
    if peonNumber % 6 == 0 then
        -- Send to lumber
        local treeX, treeY = self:findNearbyTree()
        if treeX and peon.goToTree then
            peon:goToTree(treeX, treeY)
        end
    else
        -- Send to gold
        local mine = self:findClosestMine(peon.worldX, peon.worldY, goldMines)
        if mine and peon.goToMine then
            peon:goToMine(mine)
        end
    end
end

-- Called when AI peon returns resources
function AI:onResourceReturned(resourceType, amount)
    if resourceType == "gold" then
        self:addGold(amount)
    elseif resourceType == "lumber" then
        self:addLumber(amount)
    end
end

return AI
