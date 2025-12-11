--[[
    Benchmark: Building collision - Quadtree vs linear search

    Compares the performance of:
    - OLD: O(peons × buildings) checking all buildings per canMoveTo()
    - NEW: Quadtree spatial query for nearby buildings only

    Run with: love . --benchmark-building-collision
]]

local Quadtree = require("quadtree")

local Benchmark = {}

-- Mock building accessor functions
local function getBuildingX(b) return b.centerX end
local function getBuildingY(b) return b.centerY end

-- Create mock buildings with random positions
local function createMockBuildings(count, worldSize)
    local buildings = {}
    for i = 1, count do
        local gridX = math.random(1, worldSize / 32 - 3)
        local gridY = math.random(1, worldSize / 32 - 3)
        local size = math.random(1, 3)  -- 1x1 to 3x3 buildings
        local pixelSize = size * 32
        local wx = (gridX - 1) * 32
        local wy = (gridY - 1) * 32
        table.insert(buildings, {
            gridX = gridX,
            gridY = gridY,
            gridSize = size,
            pixelSize = pixelSize,
            centerX = wx + pixelSize / 2,
            centerY = wy + pixelSize / 2,
            getWorldBounds = function(self)
                return wx, wy, wx + pixelSize, wy + pixelSize
            end
        })
    end
    return buildings
end

-- Create mock peons with random positions
local function createMockPeons(count, worldSize)
    local peons = {}
    for i = 1, count do
        table.insert(peons, {
            worldX = math.random() * worldSize,
            worldY = math.random() * worldSize,
            radius = 14,
            targetMine = nil,
        })
    end
    return peons
end

-- Mock getBuildingPenetration (simplified)
local function getBuildingPenetration(peonX, peonY, peonRadius, building)
    local bx1, by1, bx2, by2 = building:getWorldBounds()
    local closestX = math.max(bx1, math.min(peonX, bx2))
    local closestY = math.max(by1, math.min(peonY, by2))
    local dx = peonX - closestX
    local dy = peonY - closestY
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist < peonRadius then
        return peonRadius - dist
    end
    return 0
end

-- OLD: Check ALL buildings
local function canMoveToOld(peonX, peonY, newX, newY, peonRadius, buildings, targetMine)
    for _, b in ipairs(buildings) do
        if targetMine and b == targetMine then
            goto continue
        end
        local currentPen = getBuildingPenetration(peonX, peonY, peonRadius, b)
        local newPen = getBuildingPenetration(newX, newY, peonRadius, b)
        if newPen > 0 then
            if currentPen > 0 then
                if newPen >= currentPen then
                    return false
                end
            else
                return false
            end
        end
        ::continue::
    end
    return true
end

-- NEW: Use quadtree for nearby buildings
local BUILDING_QUERY_RADIUS = 14 + 48 + 16  -- peon radius + max building half-size + margin
local queryResults = {}

local function canMoveToQuadtree(peonX, peonY, newX, newY, peonRadius, buildings, targetMine, qt)
    -- Clear reusable table
    for i = 1, #queryResults do queryResults[i] = nil end

    -- Query nearby buildings
    local nearbyBuildings = qt:query(newX, newY, BUILDING_QUERY_RADIUS, queryResults, getBuildingX, getBuildingY)

    for _, b in ipairs(nearbyBuildings) do
        if targetMine and b == targetMine then
            goto continue
        end
        local currentPen = getBuildingPenetration(peonX, peonY, peonRadius, b)
        local newPen = getBuildingPenetration(newX, newY, peonRadius, b)
        if newPen > 0 then
            if currentPen > 0 then
                if newPen >= currentPen then
                    return false
                end
            else
                return false
            end
        end
        ::continue::
    end
    return true
end

-- Simulate peon movement (8 direction checks per peon)
local function simulateFrameOld(peons, buildings)
    local directions = {
        {1, 0}, {-1, 0}, {0, 1}, {0, -1},
        {0.707, 0.707}, {-0.707, 0.707}, {0.707, -0.707}, {-0.707, -0.707}
    }
    local checks = 0
    for _, peon in ipairs(peons) do
        for _, dir in ipairs(directions) do
            local newX = peon.worldX + dir[1] * 2
            local newY = peon.worldY + dir[2] * 2
            canMoveToOld(peon.worldX, peon.worldY, newX, newY, peon.radius, buildings, peon.targetMine)
            checks = checks + #buildings
        end
    end
    return checks
end

local function simulateFrameQuadtree(peons, buildings, qt)
    local directions = {
        {1, 0}, {-1, 0}, {0, 1}, {0, -1},
        {0.707, 0.707}, {-0.707, 0.707}, {0.707, -0.707}, {-0.707, -0.707}
    }
    local checks = 0
    for _, peon in ipairs(peons) do
        for _, dir in ipairs(directions) do
            local newX = peon.worldX + dir[1] * 2
            local newY = peon.worldY + dir[2] * 2
            -- Clear and query
            for i = 1, #queryResults do queryResults[i] = nil end
            local nearby = qt:query(newX, newY, BUILDING_QUERY_RADIUS, queryResults, getBuildingX, getBuildingY)
            canMoveToQuadtree(peon.worldX, peon.worldY, newX, newY, peon.radius, buildings, peon.targetMine, qt)
            checks = checks + #nearby
        end
    end
    return checks
end

function Benchmark.run()
    print("\n" .. string.rep("=", 60))
    print("BENCHMARK: Building Collision - Quadtree vs Linear")
    print(string.rep("=", 60))

    local worldSize = 256 * 32  -- 256x256 tile map
    local scenarios = {
        {peons = 7, buildings = 10, name = "Early game (7 peons, 10 buildings)"},
        {peons = 20, buildings = 30, name = "Mid game (20 peons, 30 buildings)"},
        {peons = 40, buildings = 60, name = "Late game (40 peons, 60 buildings)"},
        {peons = 60, buildings = 100, name = "Stress test (60 peons, 100 buildings)"},
    }

    for _, scenario in ipairs(scenarios) do
        print(string.format("\n--- %s ---", scenario.name))

        local buildings = createMockBuildings(scenario.buildings, worldSize)
        local peons = createMockPeons(scenario.peons, worldSize)

        -- Build quadtree
        local qt = Quadtree.new(0, 0, worldSize, worldSize)
        for _, b in ipairs(buildings) do
            qt:insert(b, getBuildingX, getBuildingY)
        end

        local iterations = 100

        -- Benchmark OLD method
        local startOld = love.timer.getTime()
        local oldChecks = 0
        for i = 1, iterations do
            oldChecks = oldChecks + simulateFrameOld(peons, buildings)
        end
        local timeOld = love.timer.getTime() - startOld

        -- Benchmark NEW method
        local startNew = love.timer.getTime()
        local newChecks = 0
        for i = 1, iterations do
            newChecks = newChecks + simulateFrameQuadtree(peons, buildings, qt)
        end
        local timeNew = love.timer.getTime() - startNew

        local speedup = timeOld / timeNew
        local checksReduction = oldChecks / newChecks

        print(string.format("  OLD (linear):   %.4fs (%d collision checks)", timeOld, oldChecks))
        print(string.format("  NEW (quadtree): %.4fs (%d collision checks)", timeNew, newChecks))
        print(string.format("  Speedup: %.2fx faster", speedup))
        print(string.format("  Checks reduced: %.2fx fewer", checksReduction))
    end

    print("\n" .. string.rep("=", 60))
    print("Benchmark complete!")
    print(string.rep("=", 60) .. "\n")

    love.event.quit()
end

return Benchmark
