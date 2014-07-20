-------------------------------------------------------------------------------
--
-- Reactor Resupply and Control Script
--
-- needs Turtle with Inventory Module and Wireless Modem.
--
--
-- reactor design from: http://www.youtube.com/watch?v=sy7rtCq6Z0A
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

if not os.loadAPI("common/apis/inventory") then
	print("Cannot load inventory api")
	return false
end

-------------------------------------------------------------------------------

if rednetutils.initialize() == nil then
	print "Unable to find modem"
	return false
end

if not inventory.initialize() then
	print("Unable to find inventory module")
	return false
end

local config = {}

-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------
local function condensatorState(slotNr)
	if slotNr then
		local reactorSlot = inventory.getItem(slotNr, config['reactor']['side'])
		if reactorSlot then
			local damage = reactorSlot['DamageValue']
			
			if damage == nil then
				damage = 10000
			end
			return (10000 - damage)
		end
	end
	return nil
end

-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------
local function drawCondensatorState()
	print("Condensator Durability:")
	print("-------------------------------------")
	
	percent = 100
	for i = 1, #config['cooling']['blocks'], 4 do
		local blockOneDura   = condensatorState(config['cooling']['blocks'][i]) 
		local blockTwoDura   = condensatorState(config['cooling']['blocks'][i+1])
		local blockThreeDura = condensatorState(config['cooling']['blocks'][i+2])
		local blockFourDura  = condensatorState(config['cooling']['blocks'][i+3])
		
		local blockOneOutput = blockOneDura and string.format("%3d%%", blockOneDura/percent) or "    "
		local blockTwoOutput = blockTwoDura and string.format("%3d%%", blockTwoDura/percent) or "    "
		local blockThreeOutput = blockThreeDura and string.format("%3d%%", blockThreeDura/percent) or "    "
		local blockFourOutput = blockFourDura and string.format("%3d%%", blockFourDura/percent) or "    "
		
		term.clearLine(1)
		print(string.format("|  %s  |  %s  |  %s  |  %s  |", blockOneOutput, blockTwoOutput, blockThreeOutput, blockFourOutput))
	end
	print("-------------------------------------")
end

-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------
local function start()
	if redstone.getInput(config['lever']['side']) == false then
		print("Cannot Start... Security Switch is off")
		return
	end

	if config['reactor']['status'] ~= "RUNNING" and config['reactor']['command'] == "ON" then
		config['reactor']['status'] = "RUNNING"
		term.clearLine(1)
		print("Starting Reactor...")
		redstone.setOutput(config['reactor']['side'], true)
	end
end

-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------
local function stop()
	if config['reactor']['status'] ~= "STOPPED" then
		config['reactor']['status'] = "STOPPED"
		term.clearLine(1)
		print("Stopping Reactor...")
	end
	redstone.setOutput(config['reactor']['side'], false)
end

-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------
local function initialize()
	-- todo: read basic config from file?

	rednetutils.register("reactor", { "reactor_control" })

	config = {
		['lever'] = {
			['side'] = "back",
		},

		['reactor'] = {
			['side'] = "top",
			['status'] = "STOPPED",
			['command'] = "OFF", 
			['security_lever'] = "OFF",
			['size'] = 0,
		},
		
		['cooling'] = {
			['name'] = "ic2.reactorcondensatorlap",
			['blocks'] = {},
			['replaced'] = 0,
			['refresh'] = false,
		},
	
		['gui'] = {
			['refresh'] = true,
		},
		
		['redstone'] = {
			["top"] = redstone.getInput("top"),
			["front"] = redstone.getInput("front"),
			["left"] = redstone.getInput("left"),
			["right"] = redstone.getInput("right"),
			["back"] = redstone.getInput("back"),
			["bottom"] = redstone.getInput("bottom"),
		},
	}
	
	config['reactor']['security_lever'] = config['redstone'][config['lever']['side']] and "ON" or "OFF"
	config['reactor']['size'] = inventory.getSlotCount(config['reactor']['side'])

	stop()

	io.write("Building reactor pattern... ")
	for slotNr = 1, config['reactor']['size'] do
		local reactorSlot = inventory.getItem(slotNr, config['reactor']['side'])
		if reactorSlot then
			if reactorSlot['RawName'] == config['cooling']['name'] then
				table.insert(config['cooling']['blocks'], slotNr)
			end
		end
	end
	
	if #config['cooling']['blocks'] == 0 then
		error("Could not find condensator patterns in reactor")
		return false
	end
	print("DONE")
	
	return true
end

-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------
local function loopRedstone()
	print("Starting redstone detector...")
	while true do
		local event = os.pullEvent("redstone")
		local changed = {}
		
		for side, state in pairs(config['redstone']) do
			if redstone.getInput(side) ~= state then
				config['redstone'][side] = redstone.getInput(side)
				changed[side] = side
				table.insert(changed, side)
			end
		end
		
		config['reactor']['security_lever'] = config['redstone'][config['lever']['side']] and "ON" or "OFF"
		
		if config['reactor']['status'] == "RUNNING" then
			if config['redstone'][config['lever']['side']] == false then
				term.clearLine(1)
				print("Stop Signal... Security Lever is off")
				stop()
			end
		end
		
		if config['reactor']['command'] == "ON" then
			if config['redstone'][config['lever']['side']] == true and  changed[config['lever']['side']] ~= nil then
				term.clearLine(1)
				print("Start Signal... Security Lever is on")
				start()
			end
		end		
	end
end

-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------
local function processKeyEvent(key)
	key = string.lower(key)
	
	if key == "q" then
		return false
	
	elseif key == "x" then
		config['cooling']['refresh'] = true
	
	elseif key == "r" then
		config['gui']['refresh'] = true
	
	elseif key == "s" then
		if config['reactor']['command'] == "ON" then
			config['reactor']['command'] = "OFF"
		else
			config['reactor']['command'] = "ON"
		end

		if config['reactor']['command'] == "ON" then
			start()
		else
			stop()
		end
	end
	
	return true
end

-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------
local function loopEvents()
	while true do
		local event, param, message = os.pullEvent()
		
		if event == "char" then
			if not processKeyEvent(param) then
				return false
			end
			
		elseif event == "rednet_message" then
			local msg = rednetutils.processEvent(param, message)
			if msg ~= nil then
				if msg.cmd == "announce" then
					rednetSend("reactorinfo", config['reactor']['info'])

				elseif msg.cmd == "control" then
					config['reactor']['command'] = msg.data
					if config['reactor']['command'] == "ON" then
						start()
					else
						stop()
					end
				end
			end
		end
	end
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
		print(string.format("Lever: %3s, Reactor: %s/%s", config['reactor']['security_lever'], config['reactor']['command'], config['reactor']['status']))
		term.clearLine(1)
		print(string.format("Condensators Replaced: %5s", config['cooling']['replaced']))

		drawCondensatorState()

		term.clearLine(1)
		print("Q to exit, S to toggle, R to redraw")
		
		rednetutils.sendCommand("reactorinfo", config['reactor'])
	end
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
	
    -- doCooling
	parallel.waitForAny(loopRedstone, loopEvents, loopMenu)
	
	stop()
	
	return rtn
end

-------------------------------------------------------------------------------

local rtn, error = pcall(main)

if not rtn then
	print("Reactor Program failed: " .. error)
end

print("Exiting...")

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- EOF
-------------------------------------------------------------------------------
