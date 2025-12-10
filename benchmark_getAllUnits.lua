--[[
    Benchmark: Measure getAllUnits/getAllBuildings call overhead

    Run with Love2D - results printed to console then exits
]]

local Benchmark = {}

-- Mock data to simulate game state
local peons = {}
local footmen = {}
local archers = {}
local knights = {}
local flyingScouts = {}
local ballistas = {}
local kamikazes = {}

local farms = {}
local barracks = {}
local townHalls = {}
local goldMines = {}
local lumberMills = {}
local blacksmiths = {}
local scoutTowers = {}
local archeryRanges = {}
local stables = {}
local siegeWorkshops = {}
local townHall = {}

-- Populate with test data
local function setupTestData(numUnits, numBuildings)
    peons, footmen, archers, knights = {}, {}, {}, {}
    flyingScouts, ballistas, kamikazes = {}, {}, {}
    farms, barracks, lumberMills, blacksmiths = {}, {}, {}, {}
    scoutTowers, archeryRanges, stables, siegeWorkshops = {}, {}, {}, {}
    townHalls, goldMines = {}, {}

    local unitsPerType = math.floor(numUnits / 7)
    for i = 1, unitsPerType do
        table.insert(peons, {visible = true})
        table.insert(footmen, {})
        table.insert(archers, {})
        table.insert(knights, {})
        table.insert(flyingScouts, {})
        table.insert(ballistas, {})
        table.insert(kamikazes, {})
    end

    local bldPerType = math.floor(numBuildings / 10)
    for i = 1, math.max(1, bldPerType) do
        table.insert(farms, {})
        table.insert(barracks, {})
        table.insert(lumberMills, {})
        table.insert(blacksmiths, {})
        table.insert(scoutTowers, {})
        table.insert(archeryRanges, {})
        table.insert(stables, {})
        table.insert(siegeWorkshops, {})
    end
    table.insert(townHalls, {})
    table.insert(goldMines, {})
    townHall = {}
end

-- The actual functions from gameplay.lua
local function getAllBuildings()
    local buildings = {townHall}
    for _, m in ipairs(goldMines) do table.insert(buildings, m) end
    for _, f in ipairs(farms) do table.insert(buildings, f) end
    for _, b in ipairs(barracks) do table.insert(buildings, b) end
    for _, b in ipairs(lumberMills) do table.insert(buildings, b) end
    for _, b in ipairs(blacksmiths) do table.insert(buildings, b) end
    for _, b in ipairs(scoutTowers) do table.insert(buildings, b) end
    for _, b in ipairs(archeryRanges) do table.insert(buildings, b) end
    for _, b in ipairs(stables) do table.insert(buildings, b) end
    for _, b in ipairs(siegeWorkshops) do table.insert(buildings, b) end
    for _, b in ipairs(townHalls) do table.insert(buildings, b) end
    return buildings
end

local function getAllUnits()
    local units = {}
    for _, p in ipairs(peons) do if p.visible then table.insert(units, p) end end
    for _, f in ipairs(footmen) do table.insert(units, f) end
    for _, a in ipairs(archers) do table.insert(units, a) end
    for _, k in ipairs(knights) do table.insert(units, k) end
    for _, f in ipairs(flyingScouts) do table.insert(units, f) end
    for _, b in ipairs(ballistas) do table.insert(units, b) end
    for _, k in ipairs(kamikazes) do table.insert(units, k) end
    return units
end

-- Simulate OLD update pattern (before optimization)
-- 8 calls total: 2668-69, 2675, 2971-72, separateUnits(298-99), 3041
local function simulateOldFrame()
    getAllUnits(); getAllBuildings()   -- fog update (2668-69)
    getAllBuildings()                   -- redundant (2675)
    getAllUnits(); getAllBuildings()   -- combat (2971-72)
    getAllUnits(); getAllBuildings()   -- separateUnits (298-99)
    getAllUnits()                       -- pushUnitOutOfBuildings (3041)
end

-- Simulate NEW update pattern (after optimization)
-- 6 calls total: 2668-69, 2971-72, separateUnits(298-99)
local function simulateNewFrame()
    getAllUnits(); getAllBuildings()   -- fog update (2668-69)
    getAllUnits(); getAllBuildings()   -- combat (2971-72)
    getAllUnits(); getAllBuildings()   -- separateUnits (298-99)
    -- pushUnitOutOfBuildings reuses separateUnits result
end

function Benchmark.run()
    print("=" .. string.rep("=", 60))
    print("getAllUnits/getAllBuildings Frame Simulation Benchmark")
    print("=" .. string.rep("=", 60))
    print()

    local scenarios = {
        {units = 20, buildings = 10, name = "Early game"},
        {units = 50, buildings = 20, name = "Mid game"},
        {units = 100, buildings = 30, name = "Late game"},
        {units = 200, buildings = 50, name = "Stress test"},
    }

    local frames = 10000

    for _, s in ipairs(scenarios) do
        setupTestData(s.units, s.buildings)

        print(s.name .. " (" .. s.units .. " units, " .. s.buildings .. " buildings)")
        print(string.rep("-", 50))

        -- Warmup
        for i = 1, 100 do simulateOldFrame() end
        for i = 1, 100 do simulateNewFrame() end

        collectgarbage("collect")

        -- OLD timing
        local startOld = love.timer.getTime()
        for i = 1, frames do
            simulateOldFrame()
        end
        local oldTime = love.timer.getTime() - startOld

        collectgarbage("collect")

        -- NEW timing
        local startNew = love.timer.getTime()
        for i = 1, frames do
            simulateNewFrame()
        end
        local newTime = love.timer.getTime() - startNew

        local saved = oldTime - newTime
        local pctImprovement = (saved / oldTime) * 100

        print(string.format("  OLD (8 calls): %.4f sec", oldTime))
        print(string.format("  NEW (6 calls): %.4f sec", newTime))
        print(string.format("  Saved: %.4f sec (%.1f%% faster)", saved, pctImprovement))
        print(string.format("  Per frame: %.2f µs saved", (saved / frames) * 1000000))
        print()
    end

    print("Summary: Removing 2 redundant calls per frame")
    print("  - Removed duplicate getAllBuildings() at line 2675")
    print("  - Removed duplicate getAllUnits() at line 3041")
    print()

    love.event.quit()
end

return Benchmark
