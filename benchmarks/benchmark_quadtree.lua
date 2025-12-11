--[[
    Benchmark: Quadtree vs O(n²) unit separation

    Compares the performance of:
    - OLD: O(n²) nested loop checking all unit pairs
    - NEW: Quadtree spatial partitioning for neighbor queries

    Run with: love . --benchmark-quadtree
]]

local Quadtree = require("quadtree")

local Benchmark = {}

-- Accessor functions
local function getX(unit) return unit.worldX end
local function getY(unit) return unit.worldY end

-- Create mock units with random positions
local function createMockUnits(count, worldSize)
    local units = {}
    for i = 1, count do
        table.insert(units, {
            worldX = math.random() * worldSize,
            worldY = math.random() * worldSize,
            radius = 8 + math.random() * 8,  -- 8-16 radius
            carryingGold = 0,
            targetMine = nil,
        })
    end
    return units
end

-- OLD: O(n²) separation - checks every pair
local function separateUnitsOld(units)
    for pass = 1, 3 do
        for i = 1, #units do
            for j = i + 1, #units do
                local a, b = units[i], units[j]

                if a.carryingGold > 0 or b.carryingGold > 0 then
                    goto continue
                end

                local dx = b.worldX - a.worldX
                local dy = b.worldY - a.worldY
                local distSq = dx * dx + dy * dy
                local minDist = a.radius + b.radius

                if distSq < minDist * minDist and distSq > 0.01 then
                    local dist = math.sqrt(distSq)
                    local overlap = (minDist - dist) / 2 + 0.5
                    local nx, ny = dx / dist, dy / dist
                    a.worldX = a.worldX - nx * overlap
                    a.worldY = a.worldY - ny * overlap
                    b.worldX = b.worldX + nx * overlap
                    b.worldY = b.worldY + ny * overlap
                end

                ::continue::
            end
        end
    end
end

-- NEW: Quadtree-based separation (persistent tree, one refresh per frame)
local MAX_SEPARATION_RADIUS = 32

local function separateUnitsQuadtree(units, worldSize, qt)
    -- Quadtree is refreshed once at start of frame, not per-pass
    for pass = 1, 3 do
        for _, a in ipairs(units) do
            if a.carryingGold > 0 then goto continue_a end

            local nearby = qt:query(a.worldX, a.worldY, MAX_SEPARATION_RADIUS, nil, getX, getY)

            for _, b in ipairs(nearby) do
                if a == b then goto continue_b end
                if b.carryingGold > 0 then goto continue_b end

                local dx = b.worldX - a.worldX
                local dy = b.worldY - a.worldY
                local distSq = dx * dx + dy * dy
                local minDist = a.radius + b.radius

                if distSq < minDist * minDist and distSq > 0.01 then
                    local dist = math.sqrt(distSq)
                    local overlap = (minDist - dist) / 2 + 0.5
                    local nx, ny = dx / dist, dy / dist
                    a.worldX = a.worldX - nx * overlap
                    a.worldY = a.worldY - ny * overlap
                    b.worldX = b.worldX + nx * overlap
                    b.worldY = b.worldY + ny * overlap
                end

                ::continue_b::
            end

            ::continue_a::
        end
    end
end

-- Refresh quadtree once per frame
local function refreshQuadtree(qt, units)
    qt:clear()
    for _, unit in ipairs(units) do
        qt:insert(unit, getX, getY)
    end
end

function Benchmark.run()
    print("=" .. string.rep("=", 65))
    print("Quadtree vs O(n²) Unit Separation Benchmark")
    print("=" .. string.rep("=", 65))
    print()

    local worldSize = 64 * 32  -- 2048 pixels

    local scenarios = {
        {units = 20, frames = 5000, name = "Early game (20 units)"},
        {units = 50, frames = 2000, name = "Mid game (50 units)"},
        {units = 100, frames = 1000, name = "Late game (100 units)"},
        {units = 200, frames = 500, name = "Stress test (200 units)"},
        {units = 500, frames = 200, name = "Extreme (500 units)"},
    }

    for _, s in ipairs(scenarios) do
        print(s.name)
        print(string.rep("-", 55))

        -- Create units (same seed for fair comparison)
        math.randomseed(12345)
        local unitsOld = createMockUnits(s.units, worldSize)

        math.randomseed(12345)
        local unitsNew = createMockUnits(s.units, worldSize)

        -- Create persistent quadtree for NEW approach
        local qt = Quadtree.new(0, 0, worldSize, worldSize)

        -- Warmup
        for i = 1, 10 do
            separateUnitsOld(createMockUnits(s.units, worldSize))
            local warmupUnits = createMockUnits(s.units, worldSize)
            local warmupQt = Quadtree.new(0, 0, worldSize, worldSize)
            refreshQuadtree(warmupQt, warmupUnits)
            separateUnitsQuadtree(warmupUnits, worldSize, warmupQt)
        end

        collectgarbage("collect")

        -- Benchmark OLD
        local startOld = love.timer.getTime()
        for i = 1, s.frames do
            separateUnitsOld(unitsOld)
        end
        local oldTime = love.timer.getTime() - startOld

        collectgarbage("collect")

        -- Benchmark NEW (one refresh per frame + separation)
        local startNew = love.timer.getTime()
        for i = 1, s.frames do
            refreshQuadtree(qt, unitsNew)  -- O(n) once per frame
            separateUnitsQuadtree(unitsNew, worldSize, qt)  -- queries only
        end
        local newTime = love.timer.getTime() - startNew

        -- Calculate comparisons (n² vs n log n)
        local pairChecksOld = s.units * (s.units - 1) / 2 * 3  -- 3 passes
        local theoreticalSpeedup = s.units / math.log(s.units)

        local actualSpeedup = oldTime / newTime
        local pctFaster = ((oldTime - newTime) / oldTime) * 100

        print(string.format("  O(n²) old:     %.4f sec (%d frames)", oldTime, s.frames))
        print(string.format("  Quadtree new:  %.4f sec (%d frames)", newTime, s.frames))

        if newTime < oldTime then
            print(string.format("  Result: %.1fx faster (%.1f%% improvement)", actualSpeedup, pctFaster))
        else
            print(string.format("  Result: %.1fx slower (quadtree overhead)", oldTime / newTime))
        end

        print(string.format("  Pair checks avoided: ~%d per frame", pairChecksOld / 3))
        print()
    end

    print("=" .. string.rep("=", 65))
    print("Analysis:")
    print("  - Quadtree excels when units are spread out (fewer neighbors)")
    print("  - O(n²) may win for small n due to quadtree overhead")
    print("  - Crossover point depends on unit density and distribution")
    print()

    love.event.quit()
end

return Benchmark
