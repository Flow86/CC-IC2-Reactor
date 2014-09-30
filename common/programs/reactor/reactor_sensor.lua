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

sensor = nil

for _,side in pairs({ "top", "bottom", "left", "right", "front", "back" }) do
	if peripheral.isPresent(side) and peripheral.getType(side) == "sensor" then
		sensor = peripheral.wrap(side)
		if sensor.getSensorName() ~= "machineCard" then
			sensor = nil
		else
			break
		end
	end
end

if not sensor then
	print("Unable to find machine sensor module")
	return false
end

local config = {}
local settings_file = string.format("reactor_%03d.properties", os.getComputerID())

-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------
local function write_settings(t)
	file = fs.open(settings_file, "w")
	file.write(t)
	file.close()
end

-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------
local function start()
	if redstone.getInput(config['lever']['side']) == false then
		term.clearLine(1)
		print("Cannot Start... Security Switch is off")
		return
	end
	
	if config['reactor']['status'] == "ERROR" then
		term.clearLine(1)
		print("Cannot Start... Emergency triggered")
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
local function clearError()
	redstone.setOutput(config['reactor']['side'], false)
	config['reactor']['status'] = "STOPPED"
end

-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------
local function emergency()
	redstone.setOutput(config['reactor']['side'], false)
	config['reactor']['status'] = "ERROR"
	write_settings("ERROR")
end

-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------
local function initialize()
	-- todo: read basic config from file?

	rednetutils.register("reactor_sensor", { "reactor_control" })

	config = {
		['lever'] = {
			['side']      = "back",
		},
	
		['reactor'] = {
			['side']           = "front",
			['sensor']         = "-3,0,1",
			['maxpercent']     = 10, -- explodes very fast (step / tick approx >20%!)
			['maxdamage']      = 10, -- tbc
			['status']         = "STOPPED",
			['command']        = "OFF", 
			['security_lever'] = "OFF",

			['heat']        = 0,
			['maxheat']     = 0,
			['heatpercent'] = 0,
			['active']      = false,
			['output']      = 0,
			['damage']      = 0,
		},
	
		['gui'] = {
			['refresh'] = true,
		},

		['redstone'] = {
			["top"]    = redstone.getInput("top"),
			["front"]  = redstone.getInput("front"),
			["left"]   = redstone.getInput("left"),
			["right"]  = redstone.getInput("right"),
			["back"]   = redstone.getInput("back"),
			["bottom"] = redstone.getInput("bottom"),
		},
		
		['rednet'] = true,
	}
	
	config['reactor']['security_lever'] = config['redstone'][config['lever']['side']] and "ON" or "OFF"
	
	if fs.exists(settings_file) then
		file = fs.open(settings_file, "r")
		config.reactor.command = file.readAll()
		file.close()
		
		if config.reactor.command == "ERROR" then
			emergency()
		elseif config.reactor.command == "ON" then
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
local function loopStatus()
	print("Starting status system...")
	while true do
		local reactor = sensor.getTargetDetails(config['reactor']['sensor'])
		if reactor == nil then
			emergency()
		else
			config['reactor']['heat'] = reactor['Heat']
			config['reactor']['maxheat'] = reactor['MaxHeat']
			config['reactor']['heatpercent'] = reactor['HeatPercentage']
			config['reactor']['active'] = reactor['Active']
			config['reactor']['output'] = reactor['Output'] * 10 -- output seems to be wrong :/
			config['reactor']['damage'] = reactor['DamageValue']
			
			if config['reactor']['heatpercent'] >= config['reactor']['maxpercent'] then
				emergency()
			end
			if config['reactor']['damage'] >= config['reactor']['maxdamage'] then
				emergency()
			end
			
			-- initialize first time
			if config['reactor']['status'] == "UNKNOWN" then
				clearError()
			end
		end

		sleep(1)
	end
	
	return true
end

-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------
local function processKeyEvent(key)
	key = string.lower(key)
	
	if key == "q" then
		emergency()
		error("Stopped")
		return false
	
	elseif key == "s" then
		if config['reactor']['status'] == "ERROR" then
			clearError()
		else
			if config['reactor']['command'] == "ON" then
				config['reactor']['command'] = "OFF"
			else
				config['reactor']['command'] = "ON"
			end
			write_settings(config.reactor.command)
		end
		
		if config['rednet'] and config['reactor']['command'] == "ON" then
			start()
		else
			stop()
		end

	elseif key == "e" then
		emergency()
	
	elseif key == "r" then
		config['gui']['refresh'] = true
	
	end
	
	return true
end

-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------
local function loopEvents()
	while true do
		--sleep(0.01)
		local event, param, message = os.pullEvent()
		
		if event == "char" then
			if not processKeyEvent(param) then
				return false
			end
			
		elseif event == "rednet_message" then
			local msg = rednetutils.processEvent(param, message)
			if msg ~= nil then
				if msg.cmd == "announce" or msg.cmd == "heartbeat" then
					rednetutils.sendCommand("info", config['reactor'])
					
				elseif msg.cmd == "control_reactor" and config['rednet'] == true then
					if msg.data == "ON" or msg.data == "OFF" then
						config['reactor']['command'] = msg.data
						write_settings(config.reactor.command)
						if config['rednet'] and config['reactor']['command'] == "ON" then
							start()
						else
							stop()
						end
					elseif msg.data == "RESET" then
						clearError()
					elseif msg.data == "EMERGENCY" then
						emergency()
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
local function loopRedstone()
	print("Starting redstone detector...")
	while true do
		--sleep(0.01)
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
		if config['gui']['refresh'] == true then
			config['gui']['refresh'] = false
			term.clear()
		end
		term.setCursorPos(1,1)
		
		term.clearLine(1)
		print(string.format("Reactor Sensor & Control      (ID %03d)", os.getComputerID()))

		term.clearLine(1)
		print("")

		term.clearLine(1)
		print("Reactor Status:  "..config['reactor']['command'].." / "..config['reactor']['status'])
		term.clearLine(1)
		print("Security Lever:  "..config['reactor']['security_lever'])

		term.clearLine(1)
		print("")

		term.clearLine(1)
		print("Temperature: "..string.format("%5d  of %5d", config['reactor']['heat'], config['reactor']['maxheat']))
		print("             "..string.format("%5d%% of %5d%%", config['reactor']['heatpercent'], config['reactor']['maxpercent']))
		term.clearLine(1)
		print("Damage:      "..string.format("%5d  of %5d", config['reactor']['damage'], config['reactor']['maxdamage']))

		term.clearLine(1)
		if config['reactor']['status'] == "ERROR" then
			print("  !!! EMERGENCY SYSTEM ACTIVATED !!!")
			term.clearLine(1)
			print("        Press S to clear error")
		else
			print("")
			term.clearLine(1)
			print("")
		end

		term.clearLine(1)
		print("")

		term.clearLine(1)
		print("Q to exit, S to toggle, R to redraw")
		
		rednetutils.sendCommand("info", config['reactor'])

		sleep(1)
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
	
	rtn = parallel.waitForAny(loopRedstone, loopEvents, loopStatus, loopMenu)
	
	emergency()
	
	return rtn
end

-------------------------------------------------------------------------------

local rtn, error = pcall(main)

if not rtn then
	print("Reactor Sensor Program failed: " .. error)
end

return rtn

-------------------------------------------------------------------------------
-- EOF
-------------------------------------------------------------------------------
