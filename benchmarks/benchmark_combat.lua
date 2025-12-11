--[[
    Benchmark: Quadtree vs O(n) combat targeting

    Compares the performance of:
    - OLD: O(n) linear scan checking all units for enemies (first match)
    - NEW (findAny): Quadtree early-exit search (matches old behavior)
    - NEW (findClosest): Quadtree full search for closest enemy

    Run with: love . --benchmark-combat
]]

local Quadtree = require("quadtree")

local Benchmark = {}

-- Accessor functions
local function getX(unit) return unit.worldX end
local function getY(unit) return unit.worldY end

-- Create mock units with random positions and teams
local function createMockUnits(count, worldSize, clustered)
    local units = {}

    if clustered then
        -- More realistic: teams clustered in different areas
        -- Team 1 on left side, Team 2 on right side
        local halfUnits = math.floor(count / 2)
        for i = 1, halfUnits do
            -- Team 1: left half of map, clustered
            table.insert(units, {
                worldX = math.random() * worldSize * 0.3 + worldSize * 0.1,
                worldY = math.random() * worldSize * 0.6 + worldSize * 0.2,
                radius = 14,
                hp = 100,
                team = 1,
                sightRange = 200,
            })
        end
        for i = 1, count - halfUnits do
            -- Team 2: right half of map, clustered
            table.insert(units, {
                worldX = math.random() * worldSize * 0.3 + worldSize * 0.6,
                worldY = math.random() * worldSize * 0.6 + worldSize * 0.2,
                radius = 14,
                hp = 100,
                team = 2,
                sightRange = 200,
            })
        end
    else
        -- Random distribution with alternating teams (original)
        for i = 1, count do
            table.insert(units, {
                worldX = math.random() * worldSize,
                worldY = math.random() * worldSize,
                radius = 14,
                hp = 100,
                team = (i % 2) + 1,
                sightRange = 200,
            })
        end
    end

    return units
end

-- OLD: O(n) linear scan - finds first enemy in range
local function findEnemyOld(unit, allUnits)
    local sightRange = unit.sightRange
    local myTeam = unit.team

    for _, other in ipairs(allUnits) do
        if other ~= unit and other.team ~= myTeam and other.hp > 0 then
            local dx = other.worldX - unit.worldX
            local dy = other.worldY - unit.worldY
            local dist = math.sqrt(dx * dx + dy * dy)
            if dist <= sightRange then
                return other
            end
        end
    end
    return nil
end

-- Shared filter state to avoid closure creation overhead
local filterUnit = nil
local filterTeam = nil

local function isEnemyFilter(other)
    return other ~= filterUnit and other.team ~= filterTeam and other.hp > 0
end

-- NEW (findAny): Quadtree early-exit - finds first enemy in range (matches old behavior)
local function findEnemyQuadtreeAny(unit, quadtree)
    filterUnit = unit
    filterTeam = unit.team
    return quadtree:findAny(unit.worldX, unit.worldY, unit.sightRange, getX, getY, isEnemyFilter)
end

-- NEW (findClosest): Quadtree full search - finds closest enemy in range
local function findEnemyQuadtreeClosest(unit, quadtree)
    filterUnit = unit
    filterTeam = unit.team
    return quadtree:findClosest(unit.worldX, unit.worldY, unit.sightRange, getX, getY, isEnemyFilter)
end

-- Simulate one frame of combat targeting for all units
local function simulateFrameOld(units)
    local targetsFound = 0
    for _, unit in ipairs(units) do
        if findEnemyOld(unit, units) then
            targetsFound = targetsFound + 1
        end
    end
    return targetsFound
end

local function simulateFrameQuadtreeAny(units, qt)
    local targetsFound = 0
    for _, unit in ipairs(units) do
        if findEnemyQuadtreeAny(unit, qt) then
            targetsFound = targetsFound + 1
        end
    end
    return targetsFound
end

local function simulateFrameQuadtreeClosest(units, qt)
    local targetsFound = 0
    for _, unit in ipairs(units) do
        if findEnemyQuadtreeClosest(unit, qt) then
            targetsFound = targetsFound + 1
        end
    end
    return targetsFound
end

-- Refresh quadtree once per frame (reuse tree structure)
local function refreshQuadtree(qt, units)
    qt:clear()
    for _, unit in ipairs(units) do
        qt:insert(unit, getX, getY)
    end
end

-- Build fresh quadtree each frame (allocate new)
local function buildFreshQuadtree(units, worldSize)
    local qt = Quadtree.new(0, 0, worldSize, worldSize)
    for _, unit in ipairs(units) do
        qt:insert(unit, getX, getY)
    end
    return qt
end

local function runScenario(name, units, frames, worldSize, clustered)
    print(name .. (clustered and " [CLUSTERED]" or " [MIXED]"))
    print(string.rep("-", 60))

    -- Create units
    math.randomseed(12345)
    local unitList = createMockUnits(units, worldSize, clustered)

    -- Create persistent quadtree
    local qt = Quadtree.new(0, 0, worldSize, worldSize)

    -- Warmup
    for i = 1, 10 do
        local warmupUnits = createMockUnits(units, worldSize, clustered)
        simulateFrameOld(warmupUnits)
        local warmupQt = Quadtree.new(0, 0, worldSize, worldSize)
        refreshQuadtree(warmupQt, warmupUnits)
        simulateFrameQuadtreeAny(warmupUnits, warmupQt)
    end

    collectgarbage("collect")

    -- Benchmark OLD (linear scan)
    local startOld = love.timer.getTime()
    for i = 1, frames do
        simulateFrameOld(unitList)
    end
    local oldTime = love.timer.getTime() - startOld

    collectgarbage("collect")

    -- Benchmark: clear() + reinsert (reuse tree)
    local startClear = love.timer.getTime()
    for i = 1, frames do
        refreshQuadtree(qt, unitList)
        simulateFrameQuadtreeAny(unitList, qt)
    end
    local clearTime = love.timer.getTime() - startClear

    collectgarbage("collect")

    -- Benchmark: new() each frame (fresh tree)
    local startFresh = love.timer.getTime()
    for i = 1, frames do
        local freshQt = buildFreshQuadtree(unitList, worldSize)
        simulateFrameQuadtreeAny(unitList, freshQt)
    end
    local freshTime = love.timer.getTime() - startFresh

    -- Results
    local oldMs = (oldTime / frames) * 1000
    local clearMs = (clearTime / frames) * 1000
    local freshMs = (freshTime / frames) * 1000

    print(string.format("  O(n) linear:   %.3f ms/frame", oldMs))
    print(string.format("  QT clear():    %.3f ms/frame", clearMs))
    print(string.format("  QT new():      %.3f ms/frame", freshMs))

    -- Compare clear vs new
    if clearTime < freshTime then
        print(string.format("  clear() is %.1fx faster than new()", freshTime / clearTime))
    else
        print(string.format("  new() is %.1fx faster than clear()", clearTime / freshTime))
    end
    print()
end

-- Benchmark per-unit separation (getUnitSeparation pattern)
local function runSeparationTest(units, frames, worldSize)
    print(string.format("\n=== Per-unit separation test with %d units ===", units))
    print(string.rep("-", 60))

    math.randomseed(12345)
    local unitList = createMockUnits(units, worldSize, true)  -- clustered

    -- Simulate getUnitSeparation behavior
    local separationDist = 14 * 2.5  -- radius * 2.5

    -- OLD: O(n) linear scan per unit
    collectgarbage("collect")
    local startOld = love.timer.getTime()
    for frame = 1, frames do
        for _, unit in ipairs(unitList) do
            local sepX, sepY = 0, 0
            for _, other in ipairs(unitList) do
                if other ~= unit then
                    local dx = unit.worldX - other.worldX
                    local dy = unit.worldY - other.worldY
                    local dist = math.sqrt(dx * dx + dy * dy)
                    if dist < separationDist and dist > 0.1 then
                        local force = (separationDist - dist) / separationDist
                        sepX = sepX + (dx / dist) * force
                        sepY = sepY + (dy / dist) * force
                    end
                end
            end
        end
    end
    local oldTime = love.timer.getTime() - startOld

    -- NEW: Quadtree query per unit (with table reuse)
    collectgarbage("collect")
    local qt = Quadtree.new(0, 0, worldSize, worldSize)
    local queryResults = {}

    local startNew = love.timer.getTime()
    for frame = 1, frames do
        -- Refresh quadtree once per frame
        qt:clear()
        for _, unit in ipairs(unitList) do
            qt:insert(unit, getX, getY)
        end

        -- Each unit queries nearby
        for _, unit in ipairs(unitList) do
            -- Clear reusable table
            for i = 1, #queryResults do queryResults[i] = nil end

            local nearby = qt:query(unit.worldX, unit.worldY, separationDist, queryResults, getX, getY)
            local sepX, sepY = 0, 0
            for _, other in ipairs(nearby) do
                if other ~= unit then
                    local dx = unit.worldX - other.worldX
                    local dy = unit.worldY - other.worldY
                    local dist = math.sqrt(dx * dx + dy * dy)
                    if dist < separationDist and dist > 0.1 then
                        local force = (separationDist - dist) / separationDist
                        sepX = sepX + (dx / dist) * force
                        sepY = sepY + (dy / dist) * force
                    end
                end
            end
        end
    end
    local newTime = love.timer.getTime() - startNew

    local oldMs = (oldTime / frames) * 1000
    local newMs = (newTime / frames) * 1000

    print(string.format("  O(n²) linear:  %.3f ms/frame", oldMs))
    print(string.format("  Quadtree:      %.3f ms/frame", newMs))
    if newTime < oldTime then
        print(string.format("  Quadtree is %.1fx faster", oldTime / newTime))
    else
        print(string.format("  Linear is %.1fx faster", newTime / oldTime))
    end
end

-- Benchmark varying tree configuration
local function runDepthTest(units, frames, worldSize)
    print(string.format("\n=== Depth/Capacity test with %d units (clustered) ===", units))
    print(string.rep("-", 60))

    math.randomseed(12345)
    local unitList = createMockUnits(units, worldSize, true)

    local configs = {
        {maxObjects = 4, maxDepth = 4, name = "depth=4, cap=4"},
        {maxObjects = 4, maxDepth = 6, name = "depth=6, cap=4"},
        {maxObjects = 4, maxDepth = 8, name = "depth=8, cap=4"},
        {maxObjects = 4, maxDepth = 10, name = "depth=10, cap=4"},
        {maxObjects = 8, maxDepth = 8, name = "depth=8, cap=8"},
        {maxObjects = 16, maxDepth = 8, name = "depth=8, cap=16"},
    }

    for _, cfg in ipairs(configs) do
        collectgarbage("collect")

        local qt = Quadtree.new(0, 0, worldSize, worldSize, 0, cfg)

        local start = love.timer.getTime()
        for i = 1, frames do
            qt:clear()
            for _, unit in ipairs(unitList) do
                qt:insert(unit, getX, getY)
            end
            simulateFrameQuadtreeAny(unitList, qt)
        end
        local elapsed = love.timer.getTime() - start

        print(string.format("  %-20s %.3f ms/frame", cfg.name, (elapsed / frames) * 1000))
    end
end

function Benchmark.run()
    print("=" .. string.rep("=", 70))
    print("Quadtree vs O(n) Combat Targeting Benchmark")
    print("=" .. string.rep("=", 70))
    print()
    print("MIXED: Units randomly placed, teams alternate (enemies nearby)")
    print("CLUSTERED: Teams grouped in separate areas (realistic gameplay)")
    print()

    local worldSize = 64 * 32  -- 2048 pixels

    local scenarios = {
        {units = 100, frames = 1000, name = "Late game (100 units)"},
        {units = 200, frames = 500, name = "Stress test (200 units)"},
        {units = 500, frames = 200, name = "Extreme (500 units)"},
        {units = 1000, frames = 100, name = "Target scale (1000 units)"},
    }

    for _, s in ipairs(scenarios) do
        runScenario(s.name, s.units, s.frames, worldSize, false)  -- Mixed
        runScenario(s.name, s.units, s.frames, worldSize, true)   -- Clustered
    end

    print("=" .. string.rep("=", 70))
    print("Analysis:")
    print("  - MIXED: Enemies everywhere, linear scan finds one immediately")
    print("  - CLUSTERED: Must search further, quadtree spatial filtering helps")
    print("  - Quadtree refresh O(n) is amortized across all queries")

    -- Test varying depth/capacity
    runDepthTest(500, 200, worldSize)
    runDepthTest(1000, 100, worldSize)

    -- Test per-unit separation (getUnitSeparation pattern)
    runSeparationTest(100, 500, worldSize)
    runSeparationTest(200, 200, worldSize)
    runSeparationTest(500, 100, worldSize)

    print()
    love.event.quit()
end

return Benchmark
