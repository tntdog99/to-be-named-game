local socket = require("socket")
local udp = socket.udp()
udp:setsockname("0.0.0.0", 8080)
print("Listening on port 8080...")
while true do
    local data, ip, port = udp:receivefrom()
    if data then
        print("Received:", data, "from", ip, port)
    end
end
