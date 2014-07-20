--
-- Reactor Resupply and Control Script
--
-- reactor design from: http://www.youtube.com/watch?v=sy7rtCq6Z0A

if not os.loadAPI("inv/apis/tableutils") then
	print("Cannot load table api")
	return false
end

modemSide = "left"
inventorySide = "right"

inventoryProxy = nil

for k,side in pairs({ "top", "bottom", "left", "right", "front", "back" }) do
	if peripheral.isPresent(side) then
		if peripheral.getType(side) == "inventory" then
			inventoryProxy = peripheral.wrap(side)
		end
		-- todo: modem
	end
end

if not inventoryProxy then
	print("Unable to find inventory module")
	return false
end

local reactorSize = inventoryProxy.getSlotCountUp()
local condensatorBlockName = "ic2.reactorcondensatorlap"
local condensatorBlocks = {}
local condensatorsReplaced = 0
local reactorStatus = "OFFLINE"

local forceRedraw = true
local forceReplace = false

local function stopReactor()
	if reactorStatus ~= "OFFLINE" then
		reactorStatus = "OFFLINE"
		term.clearLine(1)
		print("Stopping Reactor!")
	end
	redstone.setOutput("top", false)
end
 
local function startReactor()
	if redstone.getInput("back") == false then  -- Temperature Sensor and Lever
		return
	end

	if reactorStatus ~= "ONLINE" then
		term.clearLine(1)
		print("Starting Reactor!")
		reactorStatus = "ONLINE"
		redstone.setOutput("top", true)
	end
end
 
local function doRedstone()
	print("Starting redstone detector...")
	while true do
		local event = os.pullEvent("redstone")
		
		if reactorStatus == "OFFLINE" then
			if redstone.getInput("back") == true then
				term.clearLine(1)
				print("Start Signal...")
				startReactor()
			end
		end
		
		if reactorStatus == "ONLINE" then
			if redstone.getInput("back") == false then
				term.clearLine(1)
				print("Shutdown Signal...")
				stopReactor()
			end
		end
	end
end

local function fastSleep()
	sleep(1)
end

local function getLZHDurability(lzhSlot)
	if lzhSlot then
		local info = inventoryProxy.getItemUp(lzhSlot)
		if info then
			local damVal = info['DamageValue']
			
			if damVal == nil then
				damVal = 10000
			end
			return (10000 - damVal)
		end
	end
	return 10000
end

local function dropOld(slot)
	turtle.select(slot)
	while not turtle.dropDown() do
		stopReactor()
		term.clearLine(1)
		print("Old condensator chest is full, waiting...")
		sleep(1)
	end
end

local function doCondensatorStocking()
	for i = 1, 8 do
		if turtle.getItemCount(i) < 1 then
			turtle.select(i)
			while not turtle.suck() do 
				stopReactor()
				term.clearLine(1)
				print("New condensator chest is empty, waiting...")
				sleep(1)
			end
		end
	end
end

local function placeCondensator(slot)
	while true do
		for i = 1, 8 do
			if turtle.getItemCount(i) > 0 then
				turtle.select(i)
				inventoryProxy.dropUp(slot, 1)
				return
			end
		end
		turtle.select(1)
		while not turtle.suck() do
			term.clearLine(1)
			print("Waiting for new condensator...")
			sleep(1)
		end
	end
end

local function doCooling()
	print("Starting cooling system...")
	while true do
		local needToReplace = forceReplace
		for _, slot in ipairs(condensatorBlocks) do
			local durability = getLZHDurability(slot)
			if durability <= 1000 then
				needToReplace = true
				break
			end
		end		
		if needToReplace then
			stopReactor()
			while reactorStatus == "ONLINE" do
				-- coroutine.yield()
				sleep(2)
			end
			local badIndex = 9
			for _, slot in ipairs(condensatorBlocks) do
				local durability = getLZHDurability(slot)
				if (forceReplace and durability < 10000) or durability <= 2000 then
					turtle.select(badIndex)
					--analyzer.takeAt(block)
					inventoryProxy.suckUp(slot, 1)
					placeCondensator(slot)
					badIndex = badIndex + 1
					condensatorsReplaced = condensatorsReplaced + 1
					if badIndex == 16 then
						for i = 9, 15 do
							if turtle.getItemCount(i) > 0 then
								dropOld(i)
							end
							doCondensatorStocking()
						end
						badIndex = 9
					end
				end
			end			
		else
			doCondensatorStocking()
		end
		
		if forceReplace then
			forceReplace = false
		end
		
		if needToReplace then
			for i = 9, 15 do
				if turtle.getItemCount(i) > 0 then
					dropOld(i)
				end
			end

			if reactorStatus == "OFFLINE" then
				startReactor()
			end
		end

		fastSleep()
	end
end

local function drawLZH()	
	print("LZH Durability:")
	print("-------------------------------------")
	percent = 100
	for i = 1, #condensatorBlocks, 4 do
		local blockOneDura = getLZHDurability(condensatorBlocks[i]) 
		local blockTwoDura = getLZHDurability(condensatorBlocks[i+1]) 
		local blockThreeDura = getLZHDurability(condensatorBlocks[i+2]) 
		local blockFourDura = getLZHDurability(condensatorBlocks[i+3]) 
		local blockOneOutput = blockOneDura and string.format("%3d%%", blockOneDura/percent) or "    "
		local blockTwoOutput = blockTwoDura and string.format("%3d%%", blockTwoDura/percent) or "    "
		local blockThreeOutput = blockThreeDura and string.format("%3d%%", blockThreeDura/percent) or "    "
		local blockFourOutput = blockFourDura and string.format("%3d%%", blockFourDura/percent) or "    "
		term.clearLine(1)
		print(string.format("|  %s  |  %s  |  %s  |  %s  |", blockOneOutput, blockTwoOutput, blockThreeOutput, blockFourOutput))
	end
	print("-------------------------------------")
end

local function doMenu()
	print("Displaying menu...")
	
	forceRedraw = true

	while true do
		sleep(1)
		if forceRedraw then
			forceRedraw = false
			term.clear()
		end
		term.setCursorPos(1,1)
		-- print(string.format("Cooling System Status: %s", coolingStatus))
		-- print(string.format("Reactor Monitor Id:    %s", reactorMonitorId and tostring(reactorMonitorId) or "Unknown"))
		
		systemStatus = "OFF"
		if redstone.getInput("back") then
			systemStatus = "ON"
		end
		
		term.clearLine(1)
		print(string.format("Status: System: %3s, Reactor: %s", systemStatus, reactorStatus))
		term.clearLine(1)
		print(string.format("Condensators Replaced: %s", condensatorsReplaced))
		drawLZH()

		term.clearLine(1)
		print("Q to exit, S to toggle, R to redraw")
	end
end

local function doKeyboard()
	print("Starting keyboard handler...")
	while true do
		local event, key = os.pullEvent("char")
		
		if string.lower(key) == "q" then
			break

		elseif string.lower(key) == "x" then
			forceReplace = true

		elseif string.lower(key) == "r" then
			forceRedraw = true

		elseif string.lower(key) == "s" then
			if reactorStatus == "OFFLINE" then
				startReactor()
			else
				stopReactor()
			end
		end
	end
end

local function startup()
	term.clear()
	term.setCursorPos(1,1)
	io.write("Building condensator pattern...")
	for slot = 1, reactorSize do		
		-- if analyzer.getBlockIdAt(i) == condensatorBlockId then
		local item = inventoryProxy.getItemUp(slot)

		if item then
			if item['RawName'] == condensatorBlockName then
				table.insert(condensatorBlocks, slot)
			end
		end
	end

	if #condensatorBlocks > 0 then
		print("DONE")
		parallel.waitForAny(doRedstone, doCooling, doKeyboard, doMenu)
	else
		error("Could not find LZH-Condensators in reactor")
	end	

end

stopReactor()

local rtn, error = pcall(startup)

term.clear()

if not rtn then
	print("Reactor Resupply failed: " .. error)
end

print("Exiting.")
stopReactor()
