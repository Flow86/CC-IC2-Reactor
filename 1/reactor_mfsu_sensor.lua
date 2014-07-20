os.loadAPI("ocs/apis/sensor")

function table.copy(t, deep, seen)
	deep = deep or true
	seen = seen or {}
	if t == nil then return nil end
	if seen[t] then return seen[t] end
	
	local nt = {}
	for k, v in pairs(t) do
		if deep and type(v) == 'table' then
			nt[k] = table.copy(v, deep, seen)
		else
			nt[k] = v
		end
	end
	setmetatable(nt, table.copy(getmetatable(t), deep, seen))
	seen[t] = nt
	return nt
end

function table.contains(t, item)
	for i,e in pairs(t) do
		if e == item then
			return i
		end
	end
	return nil
end

-------------------------------------------------------------------------------
-- 
-- 
-- 
-------------------------------------------------------------------------------

local peripherals = {
	modem = "right",
	power = "left",
}

local sensors = {
	power = sensor.wrap(peripherals.power),
}

local config = {
	mfsu = {}
}

local lastsensordata = {
	stored = 0,
	capacity = 0,
	chargeRate = 0,
	dischargeRate = 0,
}

-- set all rednet targets allowed to send to
local allowedRednetTargets = {
	"massfabricator", 
	"reactor_control",
}
local rednetTargets = {}

local function rednetSend(cmd, data)
	local msg = textutils.serialize({cmd = cmd, type = "mfsu_sensor", data = data})
	if #rednetTargets == 0 then
		rednet.broadcast(msg)
	else
		for _,t in pairs(rednetTargets) do
			rednet.send(t, msg)
		end
	end
end

local function doSensors()
	sleep(2.0)

	local lastEnergySunken = 0
	local lastEnergyEmitted = 0
	local lastTimestamp = os.time()

	while true do
		local timestamp = os.time()
		
		local timedifference = math.floor(timestamp - lastTimestamp)
		if timedifference == 0 then
			timedifference = 1
		end
		
		local energySunken = 0
		local energyEmitted = 0

		local sensordata = table.copy(lastsensordata)
		sensordata.stored = 0
		sensordata.capacity = 0
	
		for i=1,#config.mfsu do
			local detail = sensors.power.getTargetDetails(config.mfsu[i])
			if detail ~= nil then
				energySunken = energySunken + detail['EnergySunken']
				energyEmitted = energyEmitted + detail['EnergyEmitted']
			
				sensordata.stored = sensordata.stored + detail['Stored']
				sensordata.capacity = sensordata.capacity + detail['Capacity']
			end
		end

		local chargedifference = (energySunken - lastEnergySunken)
		local dischargedifference = (energyEmitted - lastEnergyEmitted)

		sensordata.chargeRate = (chargedifference / timedifference) / 100
		sensordata.dischargeRate = (dischargedifference / timedifference) / 100

		lastEnergySunken = energySunken
		lastEnergyEmitted = energyEmitted
		lastTimestamp = timestamp

		rednetSend("sensordata", sensordata)
		lastsensordata = sensordata
	
		sleep(5.0)
	end
end

local function doEvents()
	while true do
		local event, param, message = os.pullEvent()
		
		if event == "char" then
			if string.lower(param) == "q" then
				break
			end
			
		elseif event == "rednet_message" and param ~= os.getComputerID() then
			local msg = textutils.unserialize(message)

			if table.contains(allowedRednetTargets, msg.type) and not table.contains(rednetTargets, param) then
				table.insert(rednetTargets, param)
			end
			
			if table.contains(rednetTargets, param) then
				if msg.cmd == "announce" then
					rednetSend("sensordata", lastsensordata)
				end
			end
		end
	end
end

local function doMenu()
	term.clear()
	
	while true do
		sleep(1)
		term.setCursorPos(1,1)
		
		term.clearLine()
		print(string.format("Reactor MFSU Sensorsystem      (ID %03d)", os.getComputerID()))
		term.clearLine()
		print("")
		
		if lastsensordata ~= nil then
			term.clearLine()
			print(string.format("MFSU Overall:   %d", #config.mfsu))
			term.clearLine()
			print(string.format("  Stored:              %10d Eu", lastsensordata.stored))
			term.clearLine()
			print(string.format("  Capacity:            %10d Eu", lastsensordata.capacity))
			term.clearLine()
			print(string.format("  Percent:             %10d %% ", (lastsensordata.stored / lastsensordata.capacity) * 100.0))
			term.clearLine()
			print("")

			term.clearLine()
			print(string.format("  Charge:              %10d Eu/t", lastsensordata.chargeRate))
			term.clearLine()
			print(string.format("  Discharge:           %10d Eu/t", lastsensordata.dischargeRate))
			term.clearLine()
			print("")
		end
		
		term.clearLine()
		print("")
		term.clearLine()
		print("Q to exit")
	end
end

local function startup()
	print("Reactor MFSU Sensor starting...")

	-- find all mfsu's around
	for block,info in pairs(sensors.power.getTargets()) do
		if info.RawName == "ic2.mfsu" and 
		   info.Position.X <= 1 and info.Position.X >= -1 and
		   info.Position.Z <= 3 and info.Position.Z >= -3 and
		   info.Position.Y <= 5 and info.Position.Y >= -5 then
			table.insert(config.mfsu, block)
		end
	end

	rednet.open(peripherals.modem)
	rednetSend("announce")

	parallel.waitForAny(doEvents, doSensors, doMenu)

	rednet.close(peripherals.modem)
end

local rtn, error = pcall(startup)

--term.clear()

if not rtn then
	print("Reactor MFSU Sensor failed: " .. error)
end


