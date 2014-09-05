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

if not os.loadAPI("common/apis/inventory") then
	print("Cannot load inventory api")
	return false
end

-------------------------------------------------------------------------------

if rednetutils.initialize() == nil then
	print("Unable to find modem")
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
local function fuelRodState(slotNr)
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
local function drawFuelRodState()
	print("Fuel Rod Durability:")
	print("---------------------------------------")
	
	percent = 100
	for i = 1, #config['refill']['blocks'], 7 do
		local text = "|"
		for j = 0,6 do
			local block = fuelRodState(config['refill']['blocks'][i+j]) 
			local blocktext = block and string.format("%3d%%", block/percent) or "    "
			
			text = text..string.format(" %s", blocktext)
		end
		term.clearLine(1)
		print(text.."  |")
	end
	print("---------------------------------------")
end

-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------
local function initialize()
	-- todo: read basic config from file?

	rednetutils.register("reactor_refiller", { "reactor_control" })

	config = {
		['reactor'] = {
			['side']           = "front",
			['size']           = 0,
			['replaced'] = {
				['cells'] = 0,
			}
		},
		
		['refill'] = {
			['name']      = "ic2.reactoruraniumquad",
			['blocks']    = {},
			['replenish'] = "top",
			['drop']      = turtle.dropDown,
			['refresh']   = false,
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
	
	config['reactor']['size'] = inventory.getSlotCount(config['reactor']['side'])

	io.write("Building reactor pattern... ")
	for slotNr = 1, config['reactor']['size'] do
		local reactorSlot = inventory.getItem(slotNr, config['reactor']['side'])
		if reactorSlot then
			if reactorSlot['RawName'] == config['refill']['name'] then
				table.insert(config['refill']['blocks'], slotNr)
			end
		else
			table.insert(config['refill']['blocks'], slotNr)
		end
	end
	
	if #config['refill']['blocks'] == 0 then
		error("Could not find fuel rod patterns in reactor")
		return false
	end
	print("DONE")
	
	return true
end

-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------
local function dropOld(slotNr)
	if turtle.getItemCount(slotNr) > 0 then
		turtle.select(slotNr)
		while not config['refill']['drop']() do
			stop()
			term.clearLine(1)
			print("Old fuel rod chest is full, waiting...")
			sleep(1)
		end
	end
end

-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------
local function replenishFuelRod(slotNr)
	if turtle.getItemCount(slotNr) < 1 then
		turtle.select(slotNr)
	
		local found = false
		repeat
			for slotNr = 1, inventory.getSlotCount(config['refill']['replenish']) do
				local replenishSlot = inventory.getItem(slotNr, config['refill']['replenish'])
				if replenishSlot then
					if replenishSlot['RawName'] == config['refill']['name'] then
						if inventory.suck(slotNr, replenishSlot['Size'], config['refill']['replenish']) then
							found = true
						end
					end
				end
			end
			if not found then
				term.clearLine(1)
				print("New fuel rod chest is empty, waiting...")
				sleep(1)
			end
		until found
	end
end

-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------
local function replenishFuelRods()
	for slotNr = 1, 8 do
		replenishFuelRod(slotNr)
	end
end

-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------
local function placeFuelRod(slotNr)
	while true do
		for i = 1, 8 do
			if turtle.getItemCount(i) > 0 then
				turtle.select(i)
				if inventory.drop(slotNr, 1, config['reactor']['side']) then
					return true
				end
				-- blacklist
				print("Blacklist Slot"..slotNr)
				for k, s in ipairs(config.refill.blocks) do
					if s == slotNr then
						table.remove(config.refill.blocks, k)
						break
					end
				end
				return false
			end
		end
		replenishFuelRod(1)
	end
	return nil -- never reached
end

-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------
local function loopRefill()
	print("Starting refill system...")
	while true do
		-- check each fuel rod slot if empty
		
		local turtleSlot = 9
		
		for _, slotNr in ipairs(config['refill']['blocks']) do
			local replenishSlot = inventory.getItem(slotNr, config['refill']['side'])
			if replenishSlot ~= nil then
				if replenishSlot['RawName'] ~= config['refill']['name'] then
					replenishSlot = nil
				end
			end
			if replenishSlot == nil then
				turtle.select(turtleSlot)
				inventory.suck(slotNr, 1, config['reactor']['side'])

				if placeFuelRod(slotNr) then
					config['reactor']['replaced']['cells'] = config['reactor']['replaced']['cells'] + 1
				end

				turtleSlot = turtleSlot + 1
				if turtleSlot == 17 then
					for i = 9, 16 do
						dropOld(i)
					end
					replenishFuelRods()
					turtleSlot = 9
				end
			else
				replenishFuelRods()
			end
		end

		for i = 9, 16 do
			dropOld(i)
		end
		
		turtle.select(1)
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
					rednetutils.sendCommand("info", config['reactor'])
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
		print(string.format("Fuel Rods Replaced: %5s", config['reactor']['replaced']['cells']))

		drawFuelRodState()

		term.clearLine(1)
		print("Q to exit, R to redraw")
		
		rednetutils.sendCommand("info", config['reactor'])
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
	
	rtn = parallel.waitForAny(loopEvents, loopRefill, loopMenu)
	
	stop()
	
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
