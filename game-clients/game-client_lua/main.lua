sock = require("sock")
love = require("love")
bitser = require("bitser")
socket = require("socket")
flags = ""
function searchbystring(t, target)
    for i = 1, #t do
        if t[i].id == target then
            return i
        end
    end
end

if jit then jit.on() end
function serialize(tbl, indent)
    indent = indent or ""
    local nextIndent = indent .. "  "
    local lines = { "{\n" }
    for k, v in pairs(tbl) do
        local keyStr
        if type(k) == "string" then
            local num = tonumber(k)
            if num then
                keyStr = string.format("[%d]", num)
            else
                keyStr = string.format("[\"%s\"]", k)
            end
        else
            keyStr = string.format("[%s]", tostring(k))
        end
        local value
        if type(v) == "table" then
            value = serialize(v, nextIndent)
        elseif type(v) == "string" then
            value = string.format("%q", v)
        else
            value = tostring(v)
        end
        table.insert(lines, string.format("%s%s = %s,\n", nextIndent, keyStr, value))
    end
    table.insert(lines, indent .. "}")
    return table.concat(lines)
end

function unserialize(s)
    local func = load("return " .. s, "unserialize", "t", {})
    if func then
        local ok, result = pcall(func)
        if ok then
            return result
        end
    end
    return nil
end

world = love.physics.newWorld(0, 0, 1920, 1080)
client_side_bodys = {}
server_data = {}
player_index = nil
print("client starting")
function connecttoserver(serverip, port)
    client = sock.newClient(serverip, port)
    client:setBandwidthLimit(2097152, 2097152)

    client:on("connect", function()
        client:send("message", "no name")
        print("Connected to server")
    end)
    client:on("your_id", function(id)
        player_index = id
        print("Received my connection ID from server:", player_index)
    end)
    client:on("disconnect", function()
        print("Disconnected from server")
    end)
    first_connect = true
    client:on("server_data", function(data)
        server_data = unserialize(data)
        roundinprogress = server_data[3].roundinprogress
        in_lobby = server_data[3].in_lobby
        if first_connect then
            first_connect = false
            for i = 1, #server_data[1].planets do
                client_side_bodys[i] = love.physics.newBody(world, server_data[1].planets[i].x,
                    server_data[1].planets[i].y,
                    "dynamic")
            end
        end
    end)

    client:on("choose_card", function(data)
        choosecard = data
    end)
    client:setSerialization(bitser.dumps, bitser.loads)
    client:connect()
end

function rotate_point(px, py, angle)
    local cosA = math.cos(angle)
    local sinA = math.sin(angle)
    return px * cosA - py * sinA, px * sinA + py * cosA
end

function compute_centroid(model)
    local x1, y1 = model[1], model[2]
    local x2, y2 = model[3], model[4]
    local x3, y3 = model[5], model[6]
    return (x1 + x2 + x3) / 3, (y1 + y2 + y3) / 3
end

function get_transformed_model(model, angle, cx, cy)
    local transformed = {}
    local cx0, cy0 = compute_centroid(model)

    for i = 1, #model, 2 do
        local x = model[i] - cx0
        local y = model[i + 1] - cy0
        local rx, ry = rotate_point(x, y, angle)
        table.insert(transformed, rx + cx)
        table.insert(transformed, ry + cy)
    end

    return transformed
end

function draw_planet(id, system_data)
    local planet = system_data.planets[id]
    client_side_bodys[id]:setPosition(planet.x, planet.y)
    if not planet then return end
    love.graphics.setColor(planet.color.r, planet.color.g, planet.color.b)
    love.graphics.circle("fill", client_side_bodys[id]:getX(), client_side_bodys[id]:getY(), planet.radius)
end

function draw_player(i)
    local player = server_data[2][i]
    if not player then return end
    local angle = player.angle or 0
    local x = player.position.x
    local y = player.position.y
    love.graphics.print(player.health, x, y - 17)
    love.graphics.print(player.ammo_in_mag, x, y - 30)
    love.graphics.print(player.nickname, x, y - 43)
    local triangle = get_transformed_model(player_model, angle, x, y)

    love.graphics.setColor(255, 255, 255)
    love.graphics.polygon("fill", triangle)
end

function draw_bullets(i)
    local bullet = server_data[4][i]
    if not bullet then return end
    local angle = bullet.angle or 0
    local x = bullet.position.x
    local y = bullet.position.y

    local triangle = get_transformed_model(bullet_model, angle, x, y)

    love.graphics.setColor(255, 0, 0)
    love.graphics.polygon("fill", triangle)
end

if flags == "debug" then
    debug_text = love.graphics.newText(love.graphics.getFont(), "")
end

player_data_last = {}
player_data = {
    keys = {
        up = false,
        down = false,
        left = false,
        right = false,
        space = false,
        r = false,
        lalt = false
    }
}






function roundupdate()
    if server_data then
        system_data = server_data[1]
        if love.keyboard.isDown("w") then player_data.keys.up = true else player_data.keys.up = false end
        if love.keyboard.isDown("d") then player_data.keys.right = true else player_data.keys.right = false end
        if love.keyboard.isDown("a") then player_data.keys.left = true else player_data.keys.left = false end
        if love.keyboard.isDown("s") then player_data.keys.down = true else player_data.keys.down = false end
        if love.keyboard.isDown("space") then player_data.keys.space = true else player_data.keys.space = false end
        if love.keyboard.isDown("r") then player_data.keys.r = true else player_data.keys.r = false end
        if love.keyboard.isDown("lalt") then player_data.keys.lalt = true else player_data.keys.lalt = false end
        if love.keyboard.isDown("escape") then
            client:disconnect(200)
            love.event.quit()
        end
        client:send("player_data", player_data)
    end
end

serverip1 = nil
server_data = {}
love.window.setFullscreen(true)
function love.update(dt)
    if client then
        client:update()
        roundupdate()
    end
end

player_model = {
    15, 0,
    -8, 6,
    -8, -6
}
bullet_model = {
    4, 0,
    -3, 2,
    -3, -2
};
text_box = ""
textbox2 = ""
ip1 = nil
port1 = nil
highlighted_card = nil
function love.keypressed(key)
    if client then
        if in_lobby then
            if key == "backspace" then
                text_box = text_box:sub(1, -2)
            elseif key == "return" then
                client:send("name", text_box)
                text_box = "name sent"
            elseif key == "space" then
                text_box = text_box .. " "
            else
                text_box = text_box .. key
            end
        else
            if key == "1" then
                highlighted_card = 1
            elseif key == "2" then
                highlighted_card = 2
            elseif key == "3" then
                highlighted_card = 3
            elseif key == "4" then
                if choosecard then
                    client:send("choosen_card", highlighted_card)
                    highlighted_card = nil
                    love.graphics.clear(0, 0, 0)
                    choosecard = nil
                end
            end
        end
    else
        if key == "backspace" then
            textbox2 = textbox2:sub(1, -2)
        elseif key == "return" then
            if ip1 == nil then
                ip1 = textbox2
                textbox2 = ""
                socket.sleep(0.5)
            else
                port1 = textbox2
                connecttoserver(ip1, tonumber(port1))
            end
        elseif key == "space" then
            textbox2 = textbox2 .. " "
        else
            textbox2 = textbox2 .. key
        end
    end
end

print("what is the server ip that you want to connect to?\n")
function love.draw()
    if client then
        if in_lobby then
            love.graphics.print("in lobby " .. text_box, 10, 10)
            for i = 1, #server_data[2] do
                player = server_data[2][i]
                if player.nickname then
                    love.graphics.print(player.name .. "    " .. player.nickname, 800, i * 20)
                end
            end
        else
            if roundinprogress then
                if server_data and server_data[1] then
                    for i = 1, #server_data[1].planets do
                        draw_planet(i, server_data[1])
                    end
                    love.graphics.setColor(system_data.sun.color.r, system_data.sun.color.g, system_data.sun.color.b)
                    love.graphics.circle("fill", system_data.sun.x, system_data.sun.y, system_data.sun.radius)
                    love.graphics.setColor(100, 100, 100)
                    for i = 1, #server_data[2] do
                        if server_data[2][i].health > 0 then
                            draw_player(i)
                        end
                    end
                    if server_data[4] then
                        for i = 1, #server_data[4] do
                            draw_bullets(i)
                        end
                    end
                end
            elseif not roundinprogress then
                love.graphics.clear(0, 0, 0, 255)
                love.graphics.setColor(0, 0, 0)
                love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
                if choosecard ~= nil then
                    love.graphics.setColor(255, 255, 255)
                    love.graphics.printf("Choose a card:", 0, love.graphics.getHeight() / 2 - 50,
                        love.graphics.getWidth(),
                        "center")
                    for i, card in ipairs(choosecard) do
                        if highlighted_card == i then
                            love.graphics.setColor(255, 0, 0)     -- Highlight color
                        else
                            love.graphics.setColor(255, 255, 255) -- Default color
                        end
                        love.graphics.printf(card.name .. ": " .. card.description, 0,
                            love.graphics.getHeight() / 2 + (i - 1) * 30, love.graphics.getWidth(), "center")
                    end
                else
                    love.graphics.setColor(255, 255, 255)
                    love.graphics.printf("Waiting for someone to choose a card...", 0, love.graphics.getHeight() / 2 - 50,
                        love.graphics.getWidth(), "center")
                end
            end
        end
        if flags == "debug" then
            if server_data[2] then
                love.graphics.print(serialize(server_data[2]), 0, 0)
            end
        end
        love.graphics.setColor(255, 255, 255)
        love.graphics.print(client:getRoundTripTime(), 0, 1060)
        if love.keyboard.isDown("f") then
            if server_data[2] then
                self_data = server_data[2][player_index]
                if self_data and self_data.cards then
                    for i = 1, #self_data.cards do
                        card = self_data.cards[i]
                        love.graphics.print(card.name .. "  " .. card.description, 0, i * 15)
                    end
                end
                love.graphics.print("max health " .. self_data.max_health, 1780, 15)
                love.graphics.print("spray " .. self_data.spray, 1780, 30)
                love.graphics.print("mag size " .. self_data.mag_size, 1780, 45)
                love.graphics.print("damage " .. self_data.damage, 1780, 60)
                love.graphics.print("move speed " .. self_data.move_speed, 1780, 75)
                love.graphics.print("reload speed " .. self_data.reload_speed, 1780, 105)
                love.graphics.print("fire rate " .. self_data.fire_rate, 1780, 120)
                love.graphics.print("bullet speed " .. self_data.bullet_speed, 1780, 135)
                love.graphics.print("projectile gravity " .. self_data.projectile_gravity, 1780, 150)
            end
        end
    else
        if ip1 == nil then
            love.graphics.print("please enter a ip " .. textbox2, 1920 / 2, 1080 / 2)
        else
            love.graphics.print("please enter a port " .. textbox2, 1920 / 2, 1080 / 2)
        end
    end
end
