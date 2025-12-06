--[[
    Player Module
    Manages per-player state including resources, entities, and population
    
    Each player has their own:
    - Resources (gold, lumber)
    - Units (peons, footmen, etc.)
    - Buildings (townhall, farms, barracks, etc.)
    - Population tracking
]]

local Teams = require("teams")

local Player = {}
Player.__index = Player

-- Base population capacity before farms
Player.BASE_CAPACITY = 4
Player.FARM_CAPACITY_BONUS = 4

function Player.new(params)
    local self = setmetatable({}, Player)
    
    self.team = params.team or Teams.PLAYER
    self.isHuman = params.isHuman ~= false  -- Default true
    self.name = params.name or ("Player " .. self.team)
    
    -- Resources
    self.resources = {
        gold = params.startGold or 500,
        lumber = params.startLumber or 200,
    }
    
    -- Entity tables
    self.units = {
        peons = {},
        footmen = {},
        archers = {},
        knights = {},
        flyingScouts = {},
        ballistas = {},
        kamikazes = {},
    }
    
    self.buildings = {
        townHalls = {},      -- Includes main + additional
        farms = {},
        barracks = {},
        lumberMills = {},
        blacksmiths = {},
        scoutTowers = {},
        archeryRanges = {},
        stables = {},
        siegeWorkshops = {},
    }
    
    -- Gold mines are shared/neutral, not per-player
    
    -- Population
    self.currentPop = 0
    self.maxPop = Player.BASE_CAPACITY
    
    return self
end

-- Add a unit to this player
function Player:addUnit(unit)
    unit.team = self.team
    unit.owner = self
    
    local unitType = unit.type
    if unitType == "peon" then
        table.insert(self.units.peons, unit)
    elseif unitType == "footman" then
        table.insert(self.units.footmen, unit)
    elseif unitType == "archer" then
        table.insert(self.units.archers, unit)
    elseif unitType == "knight" then
        table.insert(self.units.knights, unit)
    elseif unitType == "flyingscout" then
        table.insert(self.units.flyingScouts, unit)
    elseif unitType == "ballista" then
        table.insert(self.units.ballistas, unit)
    elseif unitType == "kamikaze" then
        table.insert(self.units.kamikazes, unit)
    end
    
    self:recalculatePopulation()
end

-- Remove a unit from this player
function Player:removeUnit(unit)
    local unitType = unit.type
    local list = nil
    
    if unitType == "peon" then list = self.units.peons
    elseif unitType == "footman" then list = self.units.footmen
    elseif unitType == "archer" then list = self.units.archers
    elseif unitType == "knight" then list = self.units.knights
    elseif unitType == "flyingscout" then list = self.units.flyingScouts
    elseif unitType == "ballista" then list = self.units.ballistas
    elseif unitType == "kamikaze" then list = self.units.kamikazes
    end
    
    if list then
        for i, u in ipairs(list) do
            if u == unit then
                table.remove(list, i)
                break
            end
        end
    end
    
    self:recalculatePopulation()
end

-- Add a building to this player
function Player:addBuilding(building)
    building.team = self.team
    building.owner = self
    
    local buildingType = building.type
    if buildingType == "townhall" then
        table.insert(self.buildings.townHalls, building)
    elseif buildingType == "farm" then
        table.insert(self.buildings.farms, building)
    elseif buildingType == "barracks" then
        table.insert(self.buildings.barracks, building)
    elseif buildingType == "lumbermill" then
        table.insert(self.buildings.lumberMills, building)
    elseif buildingType == "blacksmith" then
        table.insert(self.buildings.blacksmiths, building)
    elseif buildingType == "scouttower" then
        table.insert(self.buildings.scoutTowers, building)
    elseif buildingType == "archeryrange" then
        table.insert(self.buildings.archeryRanges, building)
    elseif buildingType == "stable" then
        table.insert(self.buildings.stables, building)
    elseif buildingType == "siegeworkshop" then
        table.insert(self.buildings.siegeWorkshops, building)
    end
    
    self:recalculatePopulation()
end

-- Remove a building from this player
function Player:removeBuilding(building)
    local buildingType = building.type
    local list = nil
    
    if buildingType == "townhall" then list = self.buildings.townHalls
    elseif buildingType == "farm" then list = self.buildings.farms
    elseif buildingType == "barracks" then list = self.buildings.barracks
    elseif buildingType == "lumbermill" then list = self.buildings.lumberMills
    elseif buildingType == "blacksmith" then list = self.buildings.blacksmiths
    elseif buildingType == "scouttower" then list = self.buildings.scoutTowers
    elseif buildingType == "archeryrange" then list = self.buildings.archeryRanges
    elseif buildingType == "stable" then list = self.buildings.stables
    elseif buildingType == "siegeworkshop" then list = self.buildings.siegeWorkshops
    end
    
    if list then
        for i, b in ipairs(list) do
            if b == building then
                table.remove(list, i)
                break
            end
        end
    end
    
    self:recalculatePopulation()
end

-- Get main town hall (first one)
function Player:getMainTownHall()
    return self.buildings.townHalls[1]
end

-- Recalculate population
function Player:recalculatePopulation()
    -- Count all units
    self.currentPop = 0
    for _, list in pairs(self.units) do
        self.currentPop = self.currentPop + #list
    end
    
    -- Calculate max from farms
    self.maxPop = Player.BASE_CAPACITY
    for _, farm in ipairs(self.buildings.farms) do
        if farm.completed then
            self.maxPop = self.maxPop + Player.FARM_CAPACITY_BONUS
        end
    end
end

-- Check if player can afford something
function Player:canAfford(goldCost, lumberCost)
    return self.resources.gold >= goldCost and self.resources.lumber >= (lumberCost or 0)
end

-- Spend resources
function Player:spend(goldCost, lumberCost)
    if self:canAfford(goldCost, lumberCost) then
        self.resources.gold = self.resources.gold - goldCost
        self.resources.lumber = self.resources.lumber - (lumberCost or 0)
        return true
    end
    return false
end

-- Add resources
function Player:addGold(amount)
    self.resources.gold = self.resources.gold + amount
end

function Player:addLumber(amount)
    self.resources.lumber = self.resources.lumber + amount
end

-- Get all units (flat list)
function Player:getAllUnits()
    local all = {}
    for _, list in pairs(self.units) do
        for _, unit in ipairs(list) do
            if not unit.visible or unit.visible then  -- Include visible units (peons can be invisible in mines)
                table.insert(all, unit)
            end
        end
    end
    return all
end

-- Get all buildings (flat list)
function Player:getAllBuildings()
    local all = {}
    for _, list in pairs(self.buildings) do
        for _, building in ipairs(list) do
            table.insert(all, building)
        end
    end
    return all
end

-- Check if player has any building of type
function Player:hasBuilding(buildingType)
    local list = self.buildings[buildingType .. "s"] or self.buildings[buildingType]
    if list then
        for _, b in ipairs(list) do
            if b.completed then return true end
        end
    end
    return false
end

-- Check if player has any completed barracks
function Player:hasBarracks()
    for _, b in ipairs(self.buildings.barracks) do
        if b.completed then return true end
    end
    return false
end

-- Check if player has any completed lumber mill  
function Player:hasLumberMill()
    for _, b in ipairs(self.buildings.lumberMills) do
        if b.completed then return true end
    end
    return false
end

-- Check if player has blacksmith
function Player:hasBlacksmith()
    for _, b in ipairs(self.buildings.blacksmiths) do
        if b.completed then return true end
    end
    return false
end

return Player
