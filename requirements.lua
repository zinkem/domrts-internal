--[[
    Requirements System
    Tracks what buildings exist and gates construction/production
    Central place to check tech tree requirements
]]

local Requirements = {}

-- References to game state (set by gameplay.lua)
local gameState = {
    townHall = nil,
    barracks = {},
    farms = {},
    archeryRanges = {},
    stables = {},
    siegeWorkshops = {},
    lumberMills = {},
    blacksmiths = {},
    scoutTowers = {}
}

-- Town Hall tier tracking
-- 1 = Town Hall, 2 = Hold, 3 = Keep
function Requirements.getTownHallTier()
    if gameState.townHall then
        return gameState.townHall.tier or 1
    end
    return 0
end

function Requirements.isTownHall()
    return Requirements.getTownHallTier() >= 1
end

function Requirements.isHold()
    return Requirements.getTownHallTier() >= 2
end

function Requirements.isKeep()
    return Requirements.getTownHallTier() >= 3
end

-- Building existence checks (completed buildings only)
function Requirements.hasBarracks()
    for _, b in ipairs(gameState.barracks) do
        if b.completed then return true end
    end
    return false
end

function Requirements.hasArcheryRange()
    for _, b in ipairs(gameState.archeryRanges) do
        if b.completed then return true end
    end
    return false
end

function Requirements.hasStable()
    for _, b in ipairs(gameState.stables) do
        if b.completed then return true end
    end
    return false
end

function Requirements.hasSiegeWorkshop()
    for _, b in ipairs(gameState.siegeWorkshops) do
        if b.completed then return true end
    end
    return false
end

function Requirements.hasLumberMill()
    for _, b in ipairs(gameState.lumberMills) do
        if b.completed then return true end
    end
    return false
end

function Requirements.hasBlacksmith()
    for _, b in ipairs(gameState.blacksmiths) do
        if b.completed then return true end
    end
    return false
end

-- Check if a specific building type can be constructed
function Requirements.canBuild(buildingType)
    local checks = {
        farm = function() return true end,
        barracks = function() return true end,
        lumbermill = function() return true end,
        scouttower = function() return true end,
        archeryrange = function() return Requirements.hasBarracks() end,
        blacksmith = function() return Requirements.hasBarracks() end,
        stable = function() return Requirements.isHold() end,
        siegeworkshop = function() return Requirements.isKeep() end,
        townhall = function() return Requirements.isHold() end
    }
    
    local check = checks[buildingType]
    return check and check() or false
end

-- Get reason why building can't be built
function Requirements.getBuildRequirement(buildingType)
    local requirements = {
        archeryrange = "Requires Barracks",
        blacksmith = "Requires Barracks",
        stable = "Requires Hold",
        siegeworkshop = "Requires Keep",
        townhall = "Requires Hold"
    }
    return requirements[buildingType]
end

-- Town Hall upgrade requirements
function Requirements.canUpgradeToHold()
    return Requirements.getTownHallTier() == 1 and Requirements.hasBarracks()
end

function Requirements.canUpgradeToKeep()
    return Requirements.getTownHallTier() == 2
end

function Requirements.getHoldRequirement()
    if not Requirements.hasBarracks() then
        return "Requires Barracks"
    end
    return nil
end

-- Tower upgrade requirements
function Requirements.canUpgradeToArcherTower()
    return Requirements.hasLumberMill()
end

function Requirements.canUpgradeToCannonTower()
    return Requirements.hasBlacksmith()
end

-- Unit production requirements
function Requirements.canProduceKnight()
    return Requirements.hasStable()
end

function Requirements.canProducePaladin()
    -- Check if any stable has the paladin upgrade
    for _, stable in ipairs(gameState.stables) do
        if stable.completed and stable.hasPaladinUpgrade then
            return true
        end
    end
    return false
end

-- Paladin upgrade requirement
function Requirements.canUpgradeToPaladin()
    return Requirements.hasSiegeWorkshop()
end

-- Set game state references (called from gameplay.lua)
function Requirements.setGameState(state)
    gameState.townHall = state.townHall
    gameState.barracks = state.barracks or {}
    gameState.farms = state.farms or {}
    gameState.archeryRanges = state.archeryRanges or {}
    gameState.stables = state.stables or {}
    gameState.siegeWorkshops = state.siegeWorkshops or {}
    gameState.lumberMills = state.lumberMills or {}
    gameState.blacksmiths = state.blacksmiths or {}
    gameState.scoutTowers = state.scoutTowers or {}
end

-- Get all building lists for iteration
function Requirements.getGameState()
    return gameState
end

return Requirements
