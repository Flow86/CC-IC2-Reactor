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

-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------
local function initialize()
	-- todo: read basic config from file?

	rednetutils.register("reactor_sensor", { "reactor_control", "reactor" })

	config = {
		['lever'] = {
			['side']      = "back",
		},
	
		['reactor'] = {
			['side']        = "0,0,2",
			['maxpercent']  = 85,
			['maxdamage']   = 1000, -- tbc
			['status']      = "UNKNOWN",

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
		
		['rednet'] = true,
	}
	
	return true
end

-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------
local function emergency()
	redstone.setOutput(config['lever']['side'], false)
	config['reactor']['status'] = "ERROR"
end

-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------
local function running()
	redstone.setOutput(config['lever']['side'], true)
	config['reactor']['status'] = "RUNNING"
end

-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------
local function loopStatus()
	print("Starting status system...")
	while true do
		local reactor = sensor.getTargetDetails(config['reactor']['side'])
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
				running()
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
		running()

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
					
				elseif msg.cmd == "control" and config['rednet'] == true then
					if msg.data == "RESET" then
						running()
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
		print("Reactor Status:  "..(config['reactor']['active'] and "ON" or "OFF"))

		term.clearLine(1)
		print("")

		term.clearLine(1)
		print("Temperature: "..string.format("%5d  of %5d", config['reactor']['heat'], config['reactor']['maxheat']))
		print("             "..string.format("%5d%% of %5d%%", config['reactor']['heatpercent'], config['reactor']['maxpercent']))
		term.clearLine(1)
		print("Damage:      "..string.format("%5d  of %5d", config['reactor']['damage'], config['reactor']['maxdamage']))
		term.clearLine(1)
		print("Output:   "..string.format("%8d  Eu/t", config['reactor']['output']))
		
		term.clearLine(1)
		print("")

		term.clearLine(1)
		if config['reactor']['status'] == "ERROR" then
			print("  !!! EMERGENCY SYSTEM ACTIVATED !!!")
			term.clearLine(1)
			print("        Press S to clear error")
		else
			print("")
		end

		term.clearLine(1)
		print("")

		term.clearLine(1)
		print("Q to exit, R to redraw")
		
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
	
	rtn = parallel.waitForAny(loopEvents, loopStatus, loopMenu)
	
	emergency()
	
	return rtn
end

-------------------------------------------------------------------------------

local rtn, error = pcall(main)

if not rtn then
	print("Reactor Refill Program failed: " .. error)
end

return rtn

-------------------------------------------------------------------------------
-- EOF
-------------------------------------------------------------------------------
