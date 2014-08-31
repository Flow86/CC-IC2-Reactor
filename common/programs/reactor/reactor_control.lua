-------------------------------------------------------------------------------
--
-- Reactor Control
--
-- needs (Wireless) Modem and Monitor
--
---------------------------------------------------------------------------------

dofile("common/apis/sGUIAPI/sGUIAPI.lua")

if not os.loadAPI("common/apis/tableutils") then
	print("Cannot load tableutils")
	return false
end

if not os.loadAPI("common/apis/rednetutils") then
	print("Cannot load rednetutils")
	return false
end

-------------------------------------------------------------------------------
-- 
-- 
-- 
-------------------------------------------------------------------------------

if rednetutils.initialize() == nil then
	print("Unable to find modem")
	return false
end

local config = {}

-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------
local function clickedButtonReactorOn()
	rednetutils.sendCommand("control", "ON")
end

-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------
local function clickedButtonReactorOff()
	rednetutils.sendCommand("control", "OFF")
end

-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------
local function clickedButtonReactorReset()
	rednetutils.sendCommand("control", "RESET")
end

-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------
local function clickedButtonReactorEmergency()
	rednetutils.sendCommand("control", "EMERGENCY")
end

-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------
local function initialize()
	-- todo: read basic config from file?

	rednetutils.register("reactor_control", { "mfsu_sensor", "reactor", "reactor_sensor", "reactor_refiller", "lapislazuli_creator" })

	config = {
		['gui'] = {
			['refresh'] = true,
			['monitor'] = nil,
			['display'] = nil,
			['controls'] = nil,
		},
		
		['rednet'] = true,
		
		['mfsu'] = {
			['stored'] = 0,
			['capacity'] = 0,
			['chargeRate'] = 0,
			['dischargeRate'] = 0,
			['percent'] = 0,
			['maxpercent'] = 98, -- shutdown limit
			
			['sensors'] = {}, -- listener list (computer ids)
		},
		
		['reactor'] = {
			-- from reactor.lua and reactor_tempsensor.lua
			['status']         = "UNKNOWN",
			['command']        = "OFF", 
			['security_lever'] = "OFF",

			-- from reactor_tempsensor.lua
			['heat']           = 0,
			['maxheat']        = 0,
			['heatpercent']    = 0,
			['maxheatpercent'] = 0,
			['active']         = false,
			['output']         = 0,
			['damage']         = 0,
			['maxdamage']      = 0,
			
			-- from reactor.lua and reactor_refill.lua
			['replaced'] = {
				['cells']        = 0,
				['condensators'] = 0,
			},
			
			['sensors'] = {}, -- listener list (computer ids)
		},
		
		-- old
		--breeder = {
		--	depletedcells = 0,
		--	heat = 0,
		--	criticalheat = 81300,
		--	state = 0,
		--},
	}
	
	-- find monitor side
	for _,side in pairs({ "top", "bottom", "left", "right", "front", "back" }) do
		if peripheral.isPresent(side) and peripheral.getType(side) == "monitor" then
			config.gui.monitor = side
			break
		end
	end
	
	if config.gui.monitor ~= nil then
		config.gui.display = Display:new(config.gui.monitor)
		local displayW, displayH = config.gui.display:getSize()
		
		local displayM = math.floor(displayW/2) + 1
		
		local gui = {}
		
		gui.labelTitle            = Label:new("Reactor Control",   Rectangle:new( 1,  1, displayW, 1), colors.white, colors.black)
		gui.labelEnergy           = Label:new("Energy Storage:",   Rectangle:new( 1,  3, displayW, 1), colors.white, colors.black)
		gui.labelEnergyStored     = Label:new("Stored:",           Rectangle:new( 3,  4,       14, 1), colors.white, colors.black)
		gui.labelEnergyStoredC    = Label:new("         0 kEu ",   Rectangle:new(19,  4,       14, 1), colors.white, colors.gray)
		gui.buttonEnergyStored    = Button:new("ERROR",            Rectangle:new(35,  4,        7, 1), colors.white, colors.red  )
		gui.labelEnergyCapacity   = Label:new("Capacity:",         Rectangle:new( 3,  5,       10, 1), colors.white, colors.black)
		gui.labelEnergyCapacityC  = Label:new("         0 kEu ",   Rectangle:new(19,  5,       14, 1), colors.white, colors.gray)
		gui.buttonEnergyCapacity  = Button:new("ERROR",            Rectangle:new(35,  5,        7, 1), colors.white, colors.red  )
		gui.labelEnergyPercent    = Label:new("Percent:",          Rectangle:new( 3,  6,       10, 1), colors.white, colors.black)
		gui.labelEnergyPercentC   = Label:new("         0 %   " ,  Rectangle:new(19,  6,       14, 1), colors.white, colors.gray)
		gui.buttonEnergyPercent   = Button:new("EMPTY",            Rectangle:new(35,  6,        7, 1), colors.white, colors.red  )
		gui.labelEnergyCharge     = Label:new("Charge:",           Rectangle:new( 3,  8,       10, 1), colors.white, colors.black)
		gui.labelEnergyChargeC    = Label:new("         0 Eu/t",   Rectangle:new(19,  8,       14, 1), colors.white, colors.gray)
		gui.labelEnergyDischarge  = Label:new("Discharge:",        Rectangle:new( 3,  9,       10, 1), colors.white, colors.black)
		gui.labelEnergyDischargeC = Label:new("         0 Eu/t",   Rectangle:new(19,  9,       14, 1), colors.white, colors.gray)
		
		gui.ruleHorizontal        = Rule:new(Rule.HORIZONTAL,      Rectangle:new( 1, 11, displayW,   1), colors.gray)
		gui.ruleVertical          = Rule:new(Rule.VERTICAL,        Rectangle:new(displayM, 11, 1,  displayH-10), colors.gray)
		
		gui.labelReactor          = Label:new("Reactor",           Rectangle:new( 1, 12, displayM, 1), colors.white, colors.black)
		--gui.labelUraniumCells     = Label:new("Uranium Cells:",    Rectangle:new( 3, 14,       15, 1), colors.white, colors.black)
		--gui.labelUraniumCellsC    = Label:new("         0",        Rectangle:new(19, 14,       10, 1), colors.white, colors.gray)
		--gui.buttonUraniumCells    = Button:new("ERR",              Rectangle:new(30, 14,        5, 1), colors.white, colors.red)
		--gui.labelLapislazuli      = Label:new("Lapislazuli:",      Rectangle:new( 3, 15,       15, 1), colors.white, colors.black)
		--gui.labelLapislazuliC     = Label:new("         0",        Rectangle:new(19, 15,       10, 1), colors.white, colors.gray)
		--gui.buttonLapislazuli     = Button:new("ERR",              Rectangle:new(30, 15,        5, 1), colors.white, colors.red)
		gui.labelReactorHeat      = Label:new("Heat:",             Rectangle:new( 3, 17,       15, 1), colors.white, colors.black)
		gui.labelReactorHeatC     = Label:new("         0",        Rectangle:new(19, 17,       10, 1), colors.white, colors.gray)
		gui.buttonReactorHeat     = Button:new("N/A",              Rectangle:new(30, 17,        5, 1), colors.white, colors.red)
		gui.labelReactorOutput    = Label:new("Output (Eu/t):",    Rectangle:new( 3, 18,       15, 1), colors.white, colors.black)
		gui.labelReactorOutputC   = Label:new("         0",        Rectangle:new(19, 18,       10, 1), colors.white, colors.gray)
		gui.buttonReactorOutput   = Button:new("N/A",              Rectangle:new(30, 18,        5, 1), colors.white, colors.red)
		
		gui.labelReactorState     = Label:new("State:",            Rectangle:new( 3, 20,       15, 1), colors.white, colors.black)
		gui.labelReactorStateC    = Label:new(" Stopped ",         Rectangle:new(19, 20,        9, 1), colors.white, colors.gray)
		gui.buttonReactorReset    = Button:new("Reset",            Rectangle:new(30, 20,        5, 1), colors.red,   colors.gray,  clickedButtonReactorReset, false)
		
		gui.buttonReactorEmergency = Button:new({"Reactor", "Emergency", "Off"},   Rectangle:new( 5, 23,       11, 3), colors.red,   colors.gray,  clickedButtonReactorEmergency)
		gui.buttonReactorOn        = Button:new("On",                              Rectangle:new(17, 23,        6, 3), colors.white, colors.green, clickedButtonReactorOn)
		gui.buttonReactorOff       = Button:new("Off",                             Rectangle:new(24, 23,        7, 3), colors.white, colors.red,   clickedButtonReactorOff)
		
		gui.labelReactorEmergency = Button:new("!! EMERGENCY SYSTEM ACTIVATED !!", Rectangle:new(3, 23,       32, 3), colors.white, colors.red, nil, false)
		
--		gui.labelBreeder          = Label:new("Breeder",           Rectangle:new(displayM +  1, 12, displayM, 1), colors.white, colors.black)
--		gui.labelDepletedCells    = Label:new("Depleted Cells:",   Rectangle:new(displayM +  3, 14,       15, 1), colors.white, colors.black)
--		gui.labelDepletedCellsC   = Label:new("         0",        Rectangle:new(displayM + 19, 14,       10, 1), colors.white, colors.gray)
--		gui.buttonDepletedCells   = Button:new("ERR",              Rectangle:new(displayM + 30, 14,        5, 1), colors.white, colors.red)
--		gui.labelBreederHeat      = Label:new("Heat:",             Rectangle:new(displayM +  3, 17,       15, 1), colors.white, colors.black)
--		gui.labelBreederHeatC     = Label:new("         0",        Rectangle:new(displayM + 19, 17,       10, 1), colors.white, colors.gray)
--		gui.buttonBreederHeat     = Button:new("ERR",              Rectangle:new(displayM + 30, 17,        5, 1), colors.white, colors.red)
--		gui.labelCriticalHeat     = Label:new("Critical Heat:",    Rectangle:new(displayM +  3, 18,       15, 1), colors.white, colors.black)
--		gui.labelCriticalHeatC    = Label:new("         0",        Rectangle:new(displayM + 19, 18,       10, 1), colors.white, colors.gray)
--		
--		gui.labelBreederState     = Label:new("State:",            Rectangle:new(displayM +  3, 20,       15, 1), colors.white, colors.black)
--		gui.labelBreederStateC    = Label:new(" Stopped  ",        Rectangle:new(displayM + 19, 20,       10, 1), colors.white, colors.gray)
--		
--		gui.buttonBreederOn       = Button:new("On",               Rectangle:new(displayM + 12, 23,        6, 3), colors.white, colors.green, clickedButtonBreederOn)
--		gui.buttonBreederOff      = Button:new("Off",              Rectangle:new(displayM + 19, 23,        7, 3), colors.white, colors.red,   clickedButtonBreederOff)		
		
		config.gui.controls = gui
		
		-- todo: charge/discharge rate, in/outputs, reactor inventories (lzh, lapislazuli), breeder

		for _, child in pairs(gui) do
			config.gui.display:addChild(child)
		end
	end
	
	rednetutils.sendCommand("announce")
	
	return true
end

-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------
local function setButton(button, onoff, onlabel, offlabel)
	onlabel = onlabel or "On"
	offlabel = offlabel or "Off"
	
	if button == nil then
		return
	end
	
	if onoff then
		button:setLabel(onlabel)
		button.buttonColor = colors.green
	else
		button:setLabel(offlabel)
		button.buttonColor = colors.red
	end
end

-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------
local function toggleButton(button)
	if button:getLabel() == "Off" then
		button:setLabel("On")
		button.buttonColor = colors.green
	else
		button:setLabel("Off")
		button.buttonColor = colors.red
	end
	
	return (button.getLabel() ~= "Off")
end

-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------
local function updateGui()
	local gui = config.gui.controls

	gui.labelEnergyStoredC.text = string.format("%10d kEu ", config.mfsu.stored / 1000)
	setButton(gui.buttonEnergyStored, (config.mfsu.stored > 0), "OK", "EMPTY")
	
	gui.labelEnergyCapacityC.text = string.format("%10d kEu ", config.mfsu.capacity / 1000)
	setButton(gui.buttonEnergyCapacity, (config.mfsu.capacity > 6 * 4 * 4 * 1000000), "OK", "ERROR")
	
	gui.labelEnergyPercentC.text = string.format("%10d %%   ", config.mfsu.percent)
	setButton(gui.buttonEnergyPercent, config.mfsu.percent, "OK", "EMPTY")

	gui.labelEnergyChargeC.text = string.format("%10d Eu/t", config.mfsu.chargeRate)
	gui.labelEnergyDischargeC.text = string.format("%10d Eu/t", config.mfsu.dischargeRate)


	--if lastsensordata.reactor.uraniumcells > 64 then
	--	gui.labelUraniumCellsC.text = string.format("%4d*64+%2d", math.floor(lastsensordata.reactor.uraniumcells/64), lastsensordata.reactor.uraniumcells%64)
	--else
	--	gui.labelUraniumCellsC.text = string.format("        %2d", lastsensordata.reactor.uraniumcells)
	--end
	--setButton(gui.buttonUraniumCells, (lastsensordata.reactor.uraniumcells > 0), "OK", "ERR")

	--if lastsensordata.reactor.lapislazuli > 64 then
	--	gui.labelLapislazuliC.text = string.format("%4d*64+%2d", math.floor(lastsensordata.reactor.lapislazuli/64), lastsensordata.reactor.lapislazuli%64)
	--else
	--	gui.labelLapislazuliC.text = string.format("        %2d", lastsensordata.reactor.lapislazuli)
	--end
	--setButton(gui.buttonLapislazuli, (lastsensordata.reactor.lapislazuli > 0), "OK", "ERR")

	gui.labelReactorHeatC.text = string.format("%10d", config.reactor.heat)
	setButton(gui.buttonReactorHeat, (config.reactor.heat <= 0.1), "OK ", "ERR")

	gui.labelReactorOutputC.text = string.format("%10d", config.reactor.output)
	setButton(gui.buttonReactorOutput, (config.reactor.output > 0.1), "OK ", "ERR")
	
	gui.buttonReactorReset.visible = false
	gui.buttonReactorEmergency.visible = true
	gui.labelReactorEmergency.visible = false
	gui.buttonReactorOn.visible = true
	gui.buttonReactorOff.visible = true
	if config.reactor.status == "STOPPED" then
		gui.labelReactorStateC.text = " Stopped "
		gui.labelReactorStateC.bgColor = colors.gray
	elseif config.reactor.status == "ERROR" then
		gui.labelReactorStateC.text = "EMERGENCY"
		gui.labelReactorStateC.bgColor = colors.red
		gui.buttonReactorReset.visible = true
		gui.buttonReactorEmergency.visible = false
		gui.labelReactorEmergency.visible = true
		gui.buttonReactorOn.visible = false
		gui.buttonReactorOff.visible = false
	elseif config.reactor.status == "RUNNING" then
		gui.labelReactorStateC.text = " Running "
		gui.labelReactorStateC.bgColor = colors.green
	else
		gui.labelReactorStateC.text = " UNKNOWN "
		gui.labelReactorStateC.bgColor = colors.red
	end

	--if lastsensordata.breeder.depletedcells > 64 then
	--	gui.labelDepletedCellsC.text = string.format("%4d*64+%2d", math.floor(lastsensordata.breeder.depletedcells/64), lastsensordata.breeder.depletedcells%64)
	--else
	--	gui.labelDepletedCellsC.text = string.format("        %2d", lastsensordata.breeder.depletedcells)
	--end
	--setButton(gui.buttonDepletedCells, (lastsensordata.breeder.depletedcells > 0), "OK", "ERR")

	--gui.labelBreederHeatC.text = string.format("%10d", lastsensordata.breeder.heat)
	--setButton(gui.buttonBreederHeat, (lastsensordata.breeder.heat < lastsensordata.breeder.criticalheat), "OK ", "ERR")

	--gui.labelCriticalHeatC.text = string.format("%10d", lastsensordata.breeder.criticalheat)

	--if lastsensordata.breeder.state == 0 then
	--	gui.labelBreederStateC.text = " Stopped  "
	--	gui.labelBreederStateC.bgColor = colors.gray
	--elseif lastsensordata.breeder.state < 0 then
	--	gui.labelBreederStateC.text = "  ERROR   "
	--	gui.labelBreederStateC.bgColor = colors.red
	--else
	--	gui.labelBreederStateC.text = " Running  "
	--	gui.labelBreederStateC.bgColor = colors.green
	--end

	config.gui.display:render()
end

-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------
local function accumulateMFSUInfo()
	local mfsuinfo = {
		stored = 0,
		capacity = 0,
		chargeRate = 0,
		dischargeRate = 0,
	}
	
	for _,i in pairs(config.mfsu.sensors) do
		mfsuinfo.stored = mfsuinfo.stored + i.stored
		mfsuinfo.capacity = mfsuinfo.capacity + i.capacity
		mfsuinfo.chargeRate = mfsuinfo.chargeRate + i.chargeRate
		mfsuinfo.dischargeRate = mfsuinfo.dischargeRate + i.dischargeRate
	end
	mfsuinfo.percent = (mfsuinfo.stored / mfsuinfo.capacity) * 100.0
	
	config.mfsu = tableutils.join(config.mfsu, mfsuinfo, true)
end

-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------
local function loopEvents()
	print("Event loop starting ...")
	while true do
		local event, param, message, p3, p4, p5 = os.pullEventRaw()
		
		if event == "char" then
			if string.lower(param) == "q" then
				break
			end
			
		elseif event == "rednet_message" then
			local msg = rednetutils.processEvent(param, message)
			if msg ~= nil then
				if msg.cmd == "announce" then
					rednetutils.sendCommand("heartbeat")
				elseif msg.cmd == "info" then
					if msg.type == "reactor" then
						if config.reactor.status == "ERROR" then
							msg.data.status = nil
						end
						config.reactor = tableutils.join(config.reactor, msg.data, true)
						--print("R: "..tableutils.pretty_print(config.reactor))
					elseif msg.type == "reactor_sensor" then
						if msg.data.status == "RUNNING" then
							msg.data.status = nil
						end
						config.reactor = tableutils.join(config.reactor, msg.data, true)
						--print("S: "..tableutils.pretty_print(config.reactor))
					elseif msg.type == "reactor_refiller" then
						config.reactor = tableutils.join(config.reactor, msg.data, true)
					elseif msg.type == "mfsu_sensor" then
						if config.mfsu.sensors[param] == nil then
							config.mfsu.sensors[param] = {}
						end
						config.mfsu.sensors[param] = tableutils.join(config.mfsu.sensors[param], msg.data)
						accumulateMFSUInfo()
						
						if config.mfsu.percent >= config.mfsu.maxpercent then
							clickedButtonReactorOff()
						end
					end
				end
			end
		end
		
		config.gui.display:interceptEvent(event, param, message, p3, p4, p5)
	end
end

-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------
local function loopMenu()
	print("Menu loop starting ...")

	while true do
		updateGui()
		
		if config['gui']['refresh'] == true then
			config['gui']['refresh'] = false
			term.clear()
		end
		term.setCursorPos(1,1)
		
		term.clearLine()
		print(string.format("Reactor Control                (ID %03d)", os.getComputerID()))
		term.clearLine()
		print("")

		term.clearLine()
		print(string.format("Energy Storage:"))
		term.clearLine()
		print(string.format("  Stored:              %10d kEu ",  config.mfsu.stored / 1000))
		term.clearLine()
		print(string.format("  Capacity:            %10d kEu ",  config.mfsu.capacity / 1000))
		term.clearLine()
		print(string.format("  Percent:             %10d %%   ", config.mfsu.percent))
		term.clearLine()
		print("")
		
		term.clearLine()
		print(string.format("  Charge:              %10d Eu/t",  config.mfsu.chargeRate))
		term.clearLine()
		print(string.format("  Discharge:           %10d Eu/t",  config.mfsu.dischargeRate))
		term.clearLine()
		print("")
		
		term.clearLine()
		io.write("  Listener: ")
		for _,i in pairs(rednetutils.getListeners()) do
			io.write(i.." ("..rednetutils.getTypeOfTarget(i)..") ")
		end
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
	
	rtn = parallel.waitForAny(loopEvents, loopMenu)
	
	-- clickedButtonReactorOff()

	term.clear()
	config.gui.display:clear()
	
	return rtn
end

-------------------------------------------------------------------------------

local rtn, error = pcall(main)

if not rtn then
	print("Reactor Control failed: " .. error)
end

return rtn

-------------------------------------------------------------------------------
-- EOF
-------------------------------------------------------------------------------
