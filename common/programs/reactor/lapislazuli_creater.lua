-------------------------------------------------------------------------------
--
-- Reactor Cell Refiller
--
-- needs Turtle with Inventory Module and Wireless Modem.
--
---------------------------------------------------------------------------------

if not os.loadAPI("common/apis/tableutils") then
	print("Cannot load tableutils")
	return false
end

if not os.loadAPI("common/apis/rednetutils") then
	print("Cannot load rednetutils")
	return false
end

-------------------------------------------------------------------------------

if rednetutils.initialize() == nil then
	print("Unable to find modem")
	return false
end

-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------
local function initialize()
	-- todo: read basic config from file?

	rednetutils.register("lapislazuli_creator", { "reactor", "reactor_control" })

	config = {
		['crafter'] = {
			['side'] = "bottom",
			['timer'] = 10.0,
		},
		
		['gui'] = {
			['refresh'] = true,
		},
			
		['rednet'] = true,
	}
	
	return true
end

-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------
local function processKeyEvent(key)
	key = string.lower(key)
	
	if key == "q" then
		error("Stopped")
		return false
	
	elseif key == "r" then
		config['gui']['refresh'] = true
	
	end
	
	return true
end

-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------
local function loopEvents()
	local lastTimestamp = os.time()

	while true do
		local event, param, message = os.pullEvent()
		
		if event == "char" then
			if not processKeyEvent(param) then
				return false
			end
			
		elseif event == "rednet_message" then
			local msg = rednetutils.processEvent(param, message)
			if msg ~= nil then
				if msg.cmd == "announce" or msg.cmd == "heartbeat" then
					rednetutils.sendCommand("info", config['crafter'])
				elseif msg.cmd == "info" then
					if msg.type == "reactor" then
						if msg.data.status == "RUNNING" then
							local timestamp = os.time()
							local timedifference = math.floor(timestamp / 0.02 - lastTimestamp / 0.02)
							if timedifference < 0.0 then
								timedifference = 0.0
							end
							-- print("Diff: "..timedifference.. "  ".. timestamp.. " vs " .. lastTimestamp)
							if timedifference > config.crafter.timer then			
								-- print("Ping")
								redstone.setOutput(config.crafter.side, true)
								sleep(1.0)
								redstone.setOutput(config.crafter.side, false)
								-- print("Peng")
								lastTimestamp = os.time()
							end
						else
							-- print("Pong")
							redstone.setOutput(config.crafter.side, false)
						end
					end
				end
			end
		end
	end
	
	return true
end

-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------
local function loopMenu()
	print("Displaying menu...")
	
	config['gui']['refresh'] = true

	rednetutils.sendCommand("announce")
	
	while true do
		sleep(1)
		if config['gui']['refresh'] == true then
			config['gui']['refresh'] = false
			term.clear()
		end
		term.setCursorPos(1,1)

		term.clearLine(1)
		print("Lapislazuli Crafter")

		term.clearLine(1)
		print("")

		term.clearLine()
		io.write("  Listener: ")
		for _,i in pairs(rednetutils.getListeners()) do
			io.write(i.." ("..rednetutils.getTypeOfTarget(i)..") ")
		end
		print("")

		for i = 1,10 do
			term.clearLine(1)
			print("")
		end

		
		term.clearLine(1)
		print("Q to exit, R to redraw")
	end
	
	return true
end

-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------
local function main()
	term.clear()
	term.setCursorPos(1,1)
	
	if not initialize() then
		return false
	end
	
	redstone.setOutput(config.crafter.side, false)
	
	rtn = parallel.waitForAny(loopEvents, loopMenu)
	
	redstone.setOutput(config.crafter.side, false)
	
	return rtn
end

-------------------------------------------------------------------------------

local rtn, error = pcall(main)

if not rtn then
	print("Lapislazuli Crafter Program failed: " .. error)
end

return rtn

-------------------------------------------------------------------------------
-- EOF
-------------------------------------------------------------------------------
