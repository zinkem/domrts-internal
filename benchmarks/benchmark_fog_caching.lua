-- Fog edge caching benchmark
-- Run from main game with: love . --benchmark-fog
-- Tests map:draw() with and without edge caching

local Benchmark = {}

function Benchmark.run()
    print("\n=== FOG EDGE CACHING BENCHMARK ===")
    print("Branch: " .. (io.popen("git branch --show-current"):read("*l") or "unknown"))

    local Map = require("map")

    -- Create a test map (typical 64x64 game map)
    local map = Map.new({width = 64, height = 64})
    map.fogEnabled = true
    map.viewportX = 0
    map.viewportY = 0
    map.viewportW = 1280
    map.viewportH = 720

    -- Mock units to reveal some fog
    local mockUnits = {}
    for i = 1, 10 do
        table.insert(mockUnits, {
            team = 1,
            worldX = 200 + i * 80,
            worldY = 200 + i * 60,
            sightRadius = 5
        })
    end

    -- Mock buildings
    local mockBuildings = {}
    for i = 1, 3 do
        table.insert(mockBuildings, {
            team = 1,
            gridX = 5 + i * 8,
            gridY = 5 + i * 8,
            gridW = 3,
            gridH = 3,
            sightRadius = 6
        })
    end

    -- Initial reveal
    map:updateFog(mockUnits, mockBuildings, 1)

    local iterations = 200

    -- Check if fog caching is available
    local hasCaching = map.fogEdgeAlpha ~= nil
    print(string.format("Fog edge caching: %s", hasCaching and "ENABLED" or "NOT AVAILABLE"))
    print(string.format("Map size: %dx%d (fog grid: %dx%d)", map.width, map.height, map.fogWidth or 0, map.fogHeight or 0))

    -- Test 1: Steady state (no unit movement)
    print("\n--- Steady State (no fog changes) ---")
    local start = love.timer.getTime()
    for i = 1, iterations do
        map:draw()
    end
    local steadyState = (love.timer.getTime() - start) / iterations * 1000
    print(string.format("map:draw() time: %.3f ms/call", steadyState))

    -- Test 2: With fog updates (simulating unit movement)
    print("\n--- With Fog Updates (simulating gameplay) ---")
    start = love.timer.getTime()
    for i = 1, iterations do
        -- Move units slightly to trigger fog changes
        for _, unit in ipairs(mockUnits) do
            unit.worldX = unit.worldX + math.sin(i * 0.1) * 2
            unit.worldY = unit.worldY + math.cos(i * 0.1) * 2
        end
        map:updateFog(mockUnits, mockBuildings, 1)
        map:draw()
    end
    local withUpdates = (love.timer.getTime() - start) / iterations * 1000
    print(string.format("updateFog + draw time: %.3f ms/call", withUpdates))

    if hasCaching and map.fogChangedCells then
        print(string.format("Cached edge alphas: %d cells",
            map.fogEdgeAlpha and #map.fogEdgeAlpha * (map.fogEdgeAlpha[1] and #map.fogEdgeAlpha[1] or 0) or 0))
    end

    print("\n=================================\n")
    love.event.quit()
end

return Benchmark
