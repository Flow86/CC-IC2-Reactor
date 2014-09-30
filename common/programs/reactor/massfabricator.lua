-------------------------------------------------------------------------------
--
-- Massfabricator Script
--
-- needs Turtle with Wireless Modem.
--
---------------------------------------------------------------------------------

if not os.loadAPI("common/apis/rednetutils") then
	print("Cannot load rednetutils")
	return false
end

-------------------------------------------------------------------------------

if rednetutils.initialize() == nil then
	print("Unable to find modem")
	return false
end

local config = {}
local settings_file = string.format("massfabricator_%03d.properties", os.getComputerID())

-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------
local function write_settings(t)
	file = fs.open(settings_file, "w")
	file.writeLine(t)
	file.writeLine(config.mode)
	file.close()
end

-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------
local function start()
	if config.massfabricator.status ~= "RUNNING" and config.massfabricator.command == "ON" then
		config.massfabricator.status = "RUNNING"
		term.clearLine(1)
		print("Starting Massfabricator...")
		redstone.setOutput(config.massfabricator.side, false)
	end
end

-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------
local function stop()
	if config.massfabricator.status ~= "STOPPED" then
		config.massfabricator.status = "STOPPED"
		term.clearLine(1)
		print("Stopping Massfabricator...")
	end
	redstone.setOutput(config.massfabricator.side, true)
end
-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------
local function initialize()
	-- todo: read basic config from file?

	rednetutils.register("massfabricator", { "mfsu_sensor", "reactor_control" })

	config = {
		['mfsu'] = {
			['stored'] = 0,
			['capacity'] = 0,
			['percent'] = 0,
			['minpercent'] = 85,  -- start limit
			['maxpercent'] = 5, -- shutdown limit
			
			['sensors'] = {}, -- listener list (computer ids)
		},
		
		['mode'] = "AUTO",
		
		['massfabricator'] = {
			['command'] = "OFF",
			['status'] = "STOPPED",
			['side'] = "front",
		},
	
		['gui'] = {
			['refresh'] = true,
		},
		
		['rednet'] = true,
	}
	
	if fs.exists(settings_file) then
		file = fs.open(settings_file, "r")
		config.massfabricator.command = file.readLine()
		config.mode = file.readLine()
		file.close()
	end

	if config.mode ~= "AUTO" then
		config.mode = "MANUAL"
	end
	
	if config.mode == "MANUAL" and config.massfabricator.command == "ON" then
		start()
	else
		stop()
	end
		
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
		
	elseif key == "m" then
		if config.mode == "MANUAL" then
			config.mode = "AUTO"
		else
			config.mode = "MANUAL"
			if config['rednet'] and config.massfabricator.command == "ON" then
				start()
			end
		end
		write_settings(config.massfabricator.command)

	elseif key == "s" then
		if config.massfabricator.command == "ON" then
			config.massfabricator.command = "OFF"
		else
			config.massfabricator.command = "ON"
		end
		write_settings(config.massfabricator.command)
		
		if config['rednet'] and config.massfabricator.command == "ON" then
			start()
		else
			stop()
		end
	
	elseif key == "r" then
		config['gui']['refresh'] = true
	
	end
	
	return true
end

-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------
local function accumulateMFSUInfo()
	local mfsuinfo = {
		stored = 0,
		capacity = 0,
	}
	
	for _,i in pairs(config.mfsu.sensors) do
		mfsuinfo.stored = mfsuinfo.stored + i.stored
		mfsuinfo.capacity = mfsuinfo.capacity + i.capacity
	end
	mfsuinfo.percent = (mfsuinfo.stored / mfsuinfo.capacity) * 100.0
	
	config.mfsu = tableutils.join(config.mfsu, mfsuinfo, true)
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
					rednetutils.sendCommand("info", config['massfabricator'])

				elseif msg.cmd == "info" then
					if msg.type == "mfsu_sensor" then
						if config.mfsu.sensors[param] == nil then
							config.mfsu.sensors[param] = {}
						end
						config.mfsu.sensors[param] = tableutils.join(config.mfsu.sensors[param], msg.data)
						accumulateMFSUInfo()
						
						if config.mode == "AUTO" then
							-- start limit
							if config.mfsu.percent >= config.mfsu.maxpercent and config.massfabricator.status == "STOPPED" then
								start()
							end
						
							-- stop limit
							if config.mfsu.percent < config.mfsu.minpercent and config.massfabricator.status ~= "STOPPED" then
								stop()
							end
						else
							if config.mfsu.percent <= 0.1 then
								stop()
							end
						end
					end
				
				elseif msg.cmd == "control_massfabricator" and config['rednet'] == true then
					config.massfabricator.command = msg.data
					write_settings(config.massfabricator.command)
					if config['rednet'] and config.massfabricator.command == "ON" then
						start()
					else
						stop()
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
	
	sleep(1)
	while true do
		if config['gui']['refresh'] == true then
			config['gui']['refresh'] = false
			term.clear()
		end
		term.setCursorPos(1,1)
		
		term.clearLine(1)
		print(string.format("Massfabricator Controlsystem   (ID %03d)", os.getComputerID()))
		term.clearLine(1)
		print("")
		
		term.clearLine(1)
		print("Massfabricator Status:  "..config.massfabricator.command.." / "..config.massfabricator.status)
		term.clearLine(1)
		print("Massfabricator Mode:    "..config.mode)
		term.clearLine(1)
		print("")

		term.clearLine(1)
		print(string.format("Energy Storage:"))
		term.clearLine(1)
		print(string.format("  Stored:              %10d kEu ",  config.mfsu.stored / 1000))
		term.clearLine(1)
		print(string.format("  Capacity:            %10d kEu ",  config.mfsu.capacity / 1000))
		term.clearLine(1)
		print(string.format("  Percent:             %10d %%   ", config.mfsu.percent))
		term.clearLine(1)
		print("")
		
		term.clearLine(1)
		print("Q to exit, S to toggle, R to redraw")

		sleep(2)
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
	
	rtn = parallel.waitForAny(loopEvents, loopMenu)
	
	return rtn
end

-------------------------------------------------------------------------------

local rtn, error = pcall(main)

if not rtn then
	print("Massfabricator Program failed: " .. error)
end

return rtn

-------------------------------------------------------------------------------
-- EOF
-------------------------------------------------------------------------------
