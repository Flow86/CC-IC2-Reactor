-------------------------------------------------------------------------------
--
-- MFSU Sensor Script
--
-- needs Turtle with Sensor Module and Wireless Modem.
--
--
-- reactor design from: http://www.youtube.com/watch?v=sy7rtCq6Z0A
--
---------------------------------------------------------------------------------

if not os.loadAPI("common/apis/rednetutils") then
	print("Cannot load rednetutils")
	return false
end

if not os.loadAPI("ocs/apis/sensor") then
	print("Cannot load sensor api")
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
		if sensor.getSensorName() ~= "powerCard" then
			sensor = nil
		else
			break
		end
	end
end

if not sensor then
	print("Unable to find power sensor module")
	return false
end

local config = {}

-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------
local function initialize()
	-- todo: read basic config from file?

	rednetutils.register("mfsu_sensor", { "reactor_control" })

	config = {
		['mfsu'] = {
			['stored']        = 0,
			['capacity']      = 0,
			['chargeRate']    = 0,
			['dischargeRate'] = 0,
			['limits'] = {
				['x'] = { 1, -1 },
				['y'] = { 5, -5 },
				['z'] = { 3, -3 },
			},
			['blocks'] = {},
		},
	
		['gui'] = {
			['refresh'] = true,
		},
		
		['rednet'] = true,
	}
	
	-- find all mfsu's around
	for block,info in pairs(sensor.getTargets()) do
		-- print(tableutils.pretty_print(info, "\n"))
		-- print(tableutils.pretty_print(config.mfsu, "\n"))
		if info.RawName == "ic2.mfsu" and 
			info.Position.X <= config.mfsu.limits.x[1] and info.Position.X >= config.mfsu.limits.x[2] and
			info.Position.Z <= config.mfsu.limits.z[1] and info.Position.Z >= config.mfsu.limits.z[2] and
			info.Position.Y <= config.mfsu.limits.y[1] and info.Position.Y >= config.mfsu.limits.y[2] then
			table.insert(config.mfsu.blocks, block)
		end
	end
	
	return true
end
-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------
local function loopStatus()
	print("Starting status system...")

	local lastEnergySunken = 0
	local lastEnergyEmitted = 0
	local lastTimestamp = os.time()

	while true do
		local timestamp = os.time()
		
		local timedifference = math.floor(timestamp / 0.02 - lastTimestamp / 0.02)
		if timedifference == 0 then
			timedifference = 1
		end
		
		local energySunken = 0
		local energyEmitted = 0

		local mfsu = tableutils.copy(config.mfsu)
		mfsu.stored = 0
		mfsu.capacity = 0
		
		-- remove unneeded info
		mfsu.limits = nil
		mfsu.blocks = nil
	
		for i=1,#config.mfsu.blocks do
			local detail = sensor.getTargetDetails(config.mfsu.blocks[i])
			if detail ~= nil then
				energySunken = energySunken + detail['EnergySunken']
				energyEmitted = energyEmitted + detail['EnergyEmitted']
			
				mfsu.stored = mfsu.stored + detail['Stored']
				mfsu.capacity = mfsu.capacity + detail['Capacity']
			end
		end

		local chargedifference = (energySunken - lastEnergySunken)
		local dischargedifference = (energyEmitted - lastEnergyEmitted)

		mfsu.chargeRate = (chargedifference / timedifference) / 100
		mfsu.dischargeRate = (dischargedifference / timedifference) / 100

		lastEnergySunken = energySunken
		lastEnergyEmitted = energyEmitted
		lastTimestamp = timestamp

		rednetutils.sendCommand("info", mfsu)
		config.mfsu = tableutils.join(config.mfsu, mfsu)
		
		sleep(5)
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
					rednetutils.sendCommand("info", config['mfsu'])
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
		
		term.clearLine()
		print(string.format("Reactor MFSU Sensorsystem      (ID %03d)", os.getComputerID()))
		term.clearLine()
		print("")
		
		term.clearLine()
		print(string.format("MFSU Overall:   %d", #config.mfsu.blocks))
		term.clearLine()
		print(string.format("  Stored:              %10d kEu", config.mfsu.stored / 1000))
		term.clearLine()
		print(string.format("  Capacity:            %10d kEu", config.mfsu.capacity / 1000))
		term.clearLine()
		print(string.format("  Percent:             %10d %% ", (config.mfsu.stored / config.mfsu.capacity) * 100.0))
		term.clearLine()
		print("")

		term.clearLine()
		print(string.format("  Charge:              %10d Eu/t", config.mfsu.chargeRate))
		term.clearLine()
		print(string.format("  Discharge:           %10d Eu/t", config.mfsu.dischargeRate))
		term.clearLine()
		print("")
		
		term.clearLine()
		print("")
		term.clearLine()
		print("Q to exit")

		sleep(1)
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
	
	rtn = parallel.waitForAny(loopEvents, loopStatus, loopMenu)
	
	return rtn
end

-------------------------------------------------------------------------------

local rtn, error = pcall(main)

if not rtn then
	print("MFSU Sensor Program failed: " .. error)
end

return rtn

-------------------------------------------------------------------------------
-- EOF
-------------------------------------------------------------------------------
