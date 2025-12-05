function love.conf(t)
    t.identity = "love2d_game"
    t.version = "11.4"
    t.console = false
    
    t.window.title = "Love2D Game"
    t.window.width = 1280
    t.window.height = 720
    t.window.resizable = false
    t.window.vsync = 1
    t.window.msaa = 4
end
