print("loading libs...")
enet = require("enet")
print("loaded enet")
sock = require("sock")
print("loaded sock")
socket = require("socket")
print("loaded socket")
bitser = require("bitser")
print("loaded bitser")
print("public server? y/n")
done1 = false
arg1 = nil
port = 8081
while not done1 do
	arg1 = io.read()
	if arg1 ~= nil then
		if arg1 == "y" then
			print("public server")
			public = true
			done1 = true
		elseif arg1 == "n" then
			print("private server")
			public = false
			done1 = true
		else
			print("option not valid must be y/n")
			arg1 = nil
		end
	end
end
done2 = false
arg2 = nil
print("port?")
while not done2 do
	arg2 = tonumber(io.read())
	if not arg2 or (arg2 ~= 8080 and arg2 ~= 8081 and (arg2 < 49152 or arg2 > 65535)) then
		print("port out of range must be 8080, 8081 or between 49152 and 65535")
		arg2 = nil
	else
		port = arg2
		done2 = true
	end
end

-- Create a UDP socket and connect to an external address to get the local IP
local function get_local_ip()
	local udp = socket.udp()
	-- Connect to a public IP, here Google DNS, doesn't send data but assigns local IP
	udp:settimeout(1)
	local success, err = udp:setpeername("8.8.8.8", 80)
	if not success then
		return nil, err
	end

	local ip = udp:getsockname()
	udp:close()
	if ip then
		return ip
	else
		return nil, "Could not get local IP"
	end
end

local ip, err = get_local_ip()

print("lab IP: " .. ip)




if public then
	local internal_ip = ip
	local internal_port = port
	local external_port = port
	local proto = "UDP"
	if jit.os == "Windows" then
		cmd = string.format(
			'upnpc-static.exe -a %s %s %s %s',
			internal_ip, internal_port, external_port, proto
		)
	elseif jit.os == "Linux" then
		cmd = string.format(
			'./upnpc-static -a %s %s %s %s',
			internal_ip, internal_port, external_port, proto
		)
	end




	os.execute(cmd)
end









server = sock.newServer("0.0.0.0", port)
server:setBandwidthLimit(2097152, 2097152)
server:setSerialization(bitser.dumps, bitser.loads)
server_side_player_data = {}
server:update()
print("Server started on " .. server:getAddress() .. ":" .. server:getPort())




function point_in_triangle(px, py, model)
	local x1, y1 = model[1], model[2]
	local x2, y2 = model[3], model[4]
	local x3, y3 = model[5], model[6]

	-- Vectors
	local v0x, v0y = x3 - x1, y3 - y1
	local v1x, v1y = x2 - x1, y2 - y1
	local v2x, v2y = px - x1, py - y1
	local minX = math.min(x1, x2, x3)
	local maxX = math.max(x1, x2, x3)
	local minY = math.min(y1, y2, y3)
	local maxY = math.max(y1, y2, y3)

	if px < minX or px > maxX or py < minY or py > maxY then
		return false
	end
	-- Dot products
	local dot00 = v0x * v0x + v0y * v0y
	local dot01 = v0x * v1x + v0y * v1y
	local dot02 = v0x * v2x + v0y * v2y
	local dot11 = v1x * v1x + v1y * v1y
	local dot12 = v1x * v2x + v1y * v2y

	-- Compute barycentric coordinates
	local denom = dot00 * dot11 - dot01 * dot01
	if denom == 0 then
		return false -- degenerate triangle
	end

	local invDenom = 1 / denom
	local u = (dot11 * dot02 - dot01 * dot12) * invDenom
	local v = (dot00 * dot12 - dot01 * dot02) * invDenom

	-- Inside if u>=0, v>=0, and u+v<=1 (edges count as inside)
	return u >= 0 and v >= 0 and (u + v) <= 1
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
		local n = #transformed
		transformed[n + 1] = rx + cx
		transformed[n + 2] = ry + cy
	end

	return transformed
end

-- gravityWell applied to a player table with position and velocity fields
-- x, y: gravity well position
-- power: strength of gravity well (hundreds or thousands)
-- epsilonRadius: soft limit to avoid singularity
function gravityWell(player, x, y, power, epsilonRadius, deltatime)
	local lx = x - player.position.x
	local ly = y - player.position.y
	local ldSq = lx * lx + ly * ly
	power = power or 100000
	epsilonRadius = epsilonRadius or 50
	local epsilon = epsilonRadius ^ 2

	if ldSq ~= 0 then
		-- Clamp ldSq so force does not increase past epsilonRadius
		local cappedLdSq = math.max(ldSq, epsilon)
		local ld = math.sqrt(cappedLdSq)
		local lfactor = (power * deltatime) / (cappedLdSq * ld)
		player.velocity.x = player.velocity.x + lx * lfactor
		player.velocity.y = player.velocity.y + ly * lfactor
	end
end

function reload(player)
	if player.reloading == false then
		player.reloading = true
		player.reload_time = socket.gettime()
	end
end

function searchbystring(t, target)
	for i = 1, #t do
		if t[i].id == target then
			return i
		end
	end
end

function searchbystring2(t, target)
	for i = 1, #t do
		if t[i] == target then
			return i
		end
	end
end

function firebullet(player)
	player.ammo_in_mag = player.ammo_in_mag - 1
	player.cooldown = socket.gettime()
	angle = math.deg(player.angle)
	spray = player.spray / 2
	angle = angle + math.random(spray * -1, spray)
	velocity = {}
	velocity.y = player.bullet_speed * math.sin(math.rad(angle))
	velocity.x = player.bullet_speed * math.cos(math.rad(angle))
	velocity.y = velocity.y + player.velocity.y
	velocity.x = velocity.x + player.velocity.x
	position = {}
	position.x = player.position.x
	position.y = player.position.y
	table.insert(bullets, { owner = player.name, velocity = velocity, angle = math.rad(angle), position = position })
end

function checkdeathplanet(player, body)
	dx = body.x - player.position.x
	dy = body.y - player.position.y
	distance = math.sqrt(dx * dx + dy * dy)
	if distance >= body.radius then
		return false
	else
		return true
	end
end

player_model = {
	16, 0,
	-8, 7,
	-8, -7
}
function checkdeathbullet(player, bullet, m)
	if bullet then
		if bullet.owner == player.name then
			return false
		elseif point_in_triangle(bullet.position.x, bullet.position.y, m) then
			return true
		else
			return false
		end
	end
end

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

deathed = {}

function nextround()
	bullets = {}
	print("Next round starting...")
	for i = 1, #server_side_player_data do
		if server_side_player_data[i] then
			server_side_player_data[i].health = server_side_player_data[i].max_health
			player = server_side_player_data[i]
			dis = { 0 }
			repeat
				dis = {}
				x = math.random(0, 1920)
				y = math.random(0, 1080)
				for i = 1, #system_data.planets do
					body = system_data.planets[i]
					dx = body.x - x
					dy = body.y - y
					dis[i] = math.sqrt(dx * dx + dy * dy)
				end
				dx = system_data.sun.x - x
				dy = system_data.sun.y - y
				table.insert(dis, math.sqrt(dx * dx + dy * dy))
				table.sort(dis)
			until dis[1] > 500
			player.health = player.max_health
			player.position.x = x
			player.position.y = y
			player.velocity.x = 0
			player.velocity.y = 0
			player.angle = 0
			player.ammo_in_mag = player.mag_size
		end
	end

	system_data = {
		sun = {
			x = 960,
			y = 540,
			radius = 35,
			color = { r = 255, g = 255, b = 0 },
			mass = 800
		},
		planets = {
			{
				radius = 15,
				distance = 200,
				orbit_speed = 0.002,
				color = { r = 0, g = 0, b = 255 },
				x = 0,
				y = 0,
				angle = 0,
				mass = 135
			},
			{
				radius = 15,
				distance = 360,
				orbit_speed = 0.0015,
				color = { r = 255, g = 0, b = 0 },
				x = 0,
				y = 0,
				angle = 0,
				mass = 100
			}
		}
	}
end

function round(dt)
	local wellX, wellY = system_data.sun.x, system_data.sun.y
	local wellPower = 53000
	local wellEpsilon = 90
	planet_wellEpsilon = 50
	planet_wellPower = 10000
	for i = 1, #system_data.planets do
		local planet = system_data.planets[i]
		planet.angle = (planet.angle + planet.orbit_speed) % (2 * math.pi)
		local x = system_data.sun.x + planet.distance * math.cos(planet.angle)
		local y = system_data.sun.y + planet.distance * math.sin(planet.angle)
		planet.x = x
		planet.y = y
	end
	for i = 1, #server_side_player_data do
		local player = server_side_player_data[i]
		if socket.gettime() - player.reload_time > player.reload_speed and player.reloading then
			player.reload_time = 0
			player.reloading = false
			player.ammo_in_mag = player.mag_size
		end
		gravityWell(player, wellX, wellY, wellPower, wellEpsilon, dt)
		for j = 1, #system_data.planets do
			local planet = system_data.planets[j]
			gravityWell(player, planet.x, planet.y, planet_wellPower, planet_wellEpsilon, dt)
		end
		if checkdeathplanet(player, system_data.sun) then
			player.health = player.health - 100
		end
		model2 = get_transformed_model(player_model, player.angle, player.position.x, player.position.y)
		for i = 1, #bullets do
			bullet = bullets[i]
			if checkdeathbullet(player, bullet, model2) then
				player.health = player.health - server_side_player_data[bullet.owner].damage
				table.remove(bullets, i)
			end
		end

		for j = 1, #system_data.planets do
			planet = system_data.planets[j]
			if checkdeathplanet(player, planet) then
				player.health = player.health - 25
			end
		end
		if player.health <= 0 then
			if not searchbystring2(deathed, player.name) then
				print("Player " .. player.name .. " has died.")
				deathed[i] = player.name
			end
		end
		player.position.x = player.position.x + player.velocity.x
		player.position.y = player.position.y + player.velocity.y
		player.velocity.x = player.velocity.x * 0.99 -- Friction
		player.velocity.y = player.velocity.y * 0.99 -- Friction
		player.position.x = player.position.x + player.velocity.x
		player.position.y = player.position.y + player.velocity.y

		-- Clamp to screen bounds with 10px margin
		local margin = 10
		if player.position.x < margin then player.position.x = margin end
		if player.position.x > 1920 - margin then player.position.x = 1920 - margin end
		if player.position.y < margin then player.position.y = margin end
		if player.position.y > 1080 - margin then player.position.y = 1080 - margin end
	end
	for i = 1, #system_data.planets do
		local planet = system_data.planets[i]
		for j = 1, #bullets do
			bullet = bullets[j]
			bul_own = server_side_player_data[bullet.owner]
			gravityWell(bullet, planet.x, planet.y, planet_wellPower * bul_own.projectile_gravity, planet_wellEpsilon, dt)
			gravityWell(bullet, wellX, wellY, wellPower * bul_own.projectile_gravity, wellEpsilon, dt)
			bullet.position.x = bullet.position.x + bullet.velocity.x
			bullet.position.y = bullet.position.y + bullet.velocity.y
		end
	end
	if #server_side_player_data > 1 then
		if #deathed >= #server_side_player_data - 1 then
			choosecard = {
				bool = true,
				sent = false,
				id = nil,
				stacks = {}
			}
			server_data[3] = { roundinprogress = false }
		end
	end
end

system_data = {
	sun = {
		x = 960,
		y = 540,
		radius = 35,
		color = { r = 255, g = 255, b = 0 },
		mass = 800
	},
	planets = {
		{
			radius = 15,
			distance = 200,
			orbit_speed = 0.002,
			color = { r = 0, g = 0, b = 255 },
			x = 0,
			y = 0,
			angle = 0,
			mass = 135
		},
		{
			radius = 15,
			distance = 360,
			orbit_speed = 0.0015,
			color = { r = 255, g = 0, b = 0 },
			x = 0,
			y = 0,
			angle = 0,
			mass = 100
		}
	}
}



for i = 1, #system_data.planets do
	local planet = system_data.planets[i]
	planet.angle = (planet.angle + planet.orbit_speed) % (2 * math.pi)
	local x = system_data.sun.x + planet.distance * math.cos(planet.angle)
	local y = system_data.sun.y + planet.distance * math.sin(planet.angle)
	planet.x = x
	planet.y = y
end









server:on("connect", function(_, client)
	print("Client " .. tostring(client["connection"]) .. " connected")
end)
server:on("message", function(message, client)
	print(tostring(message) .. " from " .. tostring(client["connection"]))
	dis = { 0 }
	repeat
		dis = {}
		x = math.random(0, 1920)
		y = math.random(0, 1080)
		for i = 1, #system_data.planets do
			body = system_data.planets[i]
			dx = body.x - x
			dy = body.y - y
			dis[i] = math.sqrt(dx * dx + dy * dy)
		end
		dx = system_data.sun.x - x
		dy = system_data.sun.y - y
		table.insert(dis, math.sqrt(dx * dx + dy * dy))
		table.sort(dis)
	until dis[1] > 500
	table.insert(server_side_player_data, {
		id = tostring(client["connection"]),
		name = #server_side_player_data + 1,
		position = { x = x, y = y },
		velocity = { x = 0, y = 0 },
		angle = 0,
		health = 100,
		mass = 1,
		cards = {},
		max_health = 100, --done
		spray = 10,       --done
		mag_size = 5,     --done
		damage = 25,      --done
		move_speed = 0.05, --done
		reload_speed = 3, --done
		fire_rate = 0.5,  --done
		bullet_speed = 3, --done
		projectile_gravity = 1, --done
		ammo_in_mag = 5,  --done
		cooldown = -100,  --done
		reloading = false, --done
		reload_time = 0,  --done
		nickname = message
	})
	print("player count " .. server:getClientCount())
	local myID = tostring(client["connection"])
	server:sendToPeer(server:getPeerByIndex(searchbystring(server_side_player_data, myID)), "your_id",
		searchbystring(server_side_player_data, myID))
end)


server:on("name", function(name, client)
	index3 = searchbystring(server_side_player_data, tostring(client["connection"]))
	server_side_player_data[index3].nickname = tostring(name)
end)
server:on("player_data", function(data, client)
	for i = 1, #server_side_player_data do
		if server_side_player_data[i] then
			if server_side_player_data[i].id == tostring(client["connection"]) then
				temp_id = i
				break
			end
		end
	end
	if not server_data[3].in_lobby then
		if data.keys.left then
			server_side_player_data[temp_id].angle = (server_side_player_data[temp_id].angle - 0.1) % (2 * math.pi)
		elseif data.keys.right then
			server_side_player_data[temp_id].angle = (server_side_player_data[temp_id].angle + 0.1) % (2 * math.pi)
		end
		if data.keys.up then
			server_side_player_data[temp_id].velocity.x = server_side_player_data[temp_id].velocity.x +
				math.cos(server_side_player_data[temp_id].angle) * server_side_player_data[temp_id].move_speed
			server_side_player_data[temp_id].velocity.y = server_side_player_data[temp_id].velocity.y +
				math.sin(server_side_player_data[temp_id].angle) * server_side_player_data[temp_id].move_speed
		end
		if data.keys.space then
			if not server_side_player_data[temp_id].reloading then
				if start - server_side_player_data[temp_id].cooldown > server_side_player_data[temp_id].fire_rate and server_side_player_data[temp_id].ammo_in_mag > 0 then
					if not searchbystring2(deathed, server_side_player_data[temp_id].name) then
						firebullet(server_side_player_data[temp_id])
					end
				elseif server_side_player_data[temp_id].ammo_in_mag == 0 then
					reload(server_side_player_data[temp_id])
				end
			end
		end
		if data.keys.r then
			reload(server_side_player_data[temp_id])
		end
	else
		if server_side_player_data[1].id == tostring(client["connection"]) then
			if data.keys.lalt then
				socket.sleep(0.4)
				server_data[3].roundinprogress = true
				server_data[3].in_lobby = false
			end
		end
	end
end)
server:on("disconnect", function(_, client)
	print("client " .. tostring(client) .. " Disconnected from server")
	print("player count " .. server:getClientCount())
	index2 = searchbystring(server_side_player_data, tostring(client["connection"]))
	server_side_player_data[index2] = nil
	choosecard.stacks[index2] = nil
end)
server:on("choosen_card", function(data, client)
	if choosecard.bool == true and choosecard.sent == true then
		index = searchbystring(server_side_player_data, tostring(client["connection"])) --gets the index of the clients player in server_side_player_data
		local player = server_side_player_data[index]
		if player then
			local card = choosecard.stacks[index][data]
			choosecard.stacks[index] = nil

			if card then
				print("Player " .. player.name .. " chose card: " .. card.name)
				local effect = loadstring(card.effect)
				setfenv(effect, { player = player })
				effect()
				print("Card effect applied to player " .. player.id)
				table.insert(server_side_player_data[index].cards, card)
			end
		end
	end
end)
--[[
template card
		{
			name = "",
			description =
			"",
			effect =
			"",
			chance =
		},

]]


bullets = {}
server_data = {}
cards = {
	{
		name = "Tank",
		description = "built like a brick wall. +50% health",
		effect = "player.max_health = player.max_health * 1.5 player.health = player.max_health",
		chance = 9
	},
	{
		name = "Damage",
		description = "hit like a truck, or at least a small car. +20% damage",
		effect = "player.damage = player.damage * 1.2",
		chance = 6
	},
	{
		name = "Speed Demon",
		description = "they cant hit what they cant catch. +50% move speed, –20% health, –10% reload time",
		effect =
		"player.move_speed = player.move_speed * 1.5 player.max_health = player.max_health * 0.8 player.reload_speed = player.reload_speed * 0.9",
		chance = 5
	},
	{
		name = "SMG",
		description =
		"get real close with this one just make sure they dont have a shotgun. +50% spray, +20 mag size, -90% fire rate, -60% damage",
		effect =
		"player.spray = player.spray * 1.5 player.mag_size = player.mag_size + 20 player.fire_rate = player.fire_rate * 0.1 player.damage = player.damage * 0.4",
		chance = 5
	},
	{
		name = "Glass cannon",
		description =
		"not a very tanky one but this one sure packs a punch. -90% health, +200% damage ",
		effect =
		"player.max_health = player.max_health * 0.1 player.damage = player.damage * 2",
		chance = 2
	},
	{
		name = "Sniper Instincts",
		description = "take your time, breathe, and make it count. +100% bullet speed, +50% damage, -30% fire rate",
		effect =
		"player.bullet_speed = player.bullet_speed * 2 player.damage = player.damage * 1.5 player.fire_rate = player.fire_rate * 1.3",
		chance = 4
	},
	{
		name = "Heavy Rounds",
		description =
		"slower shots, but they hit like freight trains. +75% damage, -50% bullet speed, +25% projectile gravity",
		effect =
		"player.damage = player.damage * 1.75 player.bullet_speed = player.bullet_speed * 0.5 player.projectile_gravity = player.projectile_gravity * 1.25",
		chance = 3
	},
	{
		name = "DEBUG",
		description =
		"DEEEEBUG",
		effect =
		"player.damage = player.damage*500 player.mag_size = player.mag_size*500 player.fire_rate = player.fire_rate * 0.00001 player.projectile_gravity = player.projectile_gravity * 5 player.spray = player.spray * 2",
		chance = 0.01
	}
}
lastTime = socket.gettime()
dt = 0.5
server_data[3] = { roundinprogress = false, in_lobby = true }
choosecard = {
	bool = false,
	sent = false,
	id = nil,
	stacks = {}
}

while true do
	server_data[4] = bullets
	start = socket.gettime()
	local dt = start - lastTime
	lastTime = start
	server_data[1] = system_data
	server_data[2] = server_side_player_data
	server:sendToAll("server_data", serialize(server_data))
	if server:getClientCount() == 0 then
		print("No clients connected, waiting for connections...")
		socket.sleep(1) -- Wait before next update if no clients
	else
		if server_data[3].in_lobby then
		else
			if choosecard.bool == false then
				round(dt)
			elseif choosecard.bool == true then
				if choosecard.sent == false then
					print("Choose card phase active")
					choosecard.stacks = {}
					for i = 1, #deathed do
						if deathed[i] then
							index = deathed[i]
							print(index)

							choosecard.stacks[index] = {}
							while #choosecard.stacks[index] < 3 do
								local card = cards[math.random(1, #cards)]
								if math.random(1, 100) <= card.chance then
									table.insert(choosecard.stacks[index], card)
								end
							end
							print(server:getPeerByIndex(index))
							server:sendToPeer(server:getPeerByIndex(index), "choose_card", choosecard.stacks[index])
						end
					end
				end


				choosecard.sent = true
			else
				socket.sleep(0.5)
			end
			if choosecard.bool == true and choosecard.sent == true then
				if #choosecard.stacks == 0 then
					deathed = {}
					choosecard.stacks = {}
					nextround()
					choosecard = {
						bool = false,
						sent = false,
						id = nil,
						stacks = {}
					}
					server_data[3] = { roundinprogress = true }
				end
			end
		end
	end

	server:update()
	-- Add a delay for ~60 FPS
	local elapsed = socket.gettime() - start
	local delay = 1 / 60 - elapsed
	if delay > 0 then
		socket.sleep(delay)
	end
end



--todo add Disconnection protection (done that i know)
--add more cards
