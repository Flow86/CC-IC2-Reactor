dofile("sGUIAPI/sGUIAPI.lua")

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

peripherals = {
	modem = "back",
	monitor = "top"
}

-- set all rednet targets allowed to send to
local allowedRednetTargets = {
	"mfsu_sensor",
	"reactor",
	"breeder",
}
local rednetTargets = {}

local function rednetSend(cmd, data)
	local msg = textutils.serialize({cmd = cmd, type = "reactor_control", data = data})
	if #rednetTargets == 0 then
		rednet.broadcast(msg)
	else
		for _,t in pairs(rednetTargets) do
			rednet.send(t, msg)
		end
	end
end


local lastsensordata = {
	stored = 0,
	capacity = 0,
	chargeRate = 0,
	dischargeRate = 0,
	percent = 0,
	mfsu = {},
	reactor = {
		uraniumcells = 0,
		lapislazuli = 0,
		heat = 0,
		output = 0,
		state = 0,
	},
	breeder = {
		depletedcells = 0,
		heat = 0,
		criticalheat = 81300,
		state = 0,
	},
}

local display = Display:new(peripherals.monitor)
local displayW, displayH = display:getSize()
local gui = {}

local function setButton(button, onoff, onlabel, offlabel)
	onlabel = onlabel or "On"
	offlabel = offlabel or "Off"
	
	if button == nil then
		return
	end
	
	if onoff then
		button.label = onlabel
		button.buttonColor = colors.green
	else
		button.label = offlabel
		button.buttonColor = colors.red
	end
end

local function toggleButton(button)
	if button.label == "Off" then
		button.label = "On"
		button.buttonColor = colors.green
	else
		button.label = "Off"
		button.buttonColor = colors.red
	end
	
	return (button.label ~= "Off")
end

displayM = math.floor(displayW/2) + 1

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
gui.labelUraniumCells     = Label:new("Uranium Cells:",    Rectangle:new( 3, 14,       15, 1), colors.white, colors.black)
gui.labelUraniumCellsC    = Label:new("         0",        Rectangle:new(19, 14,       10, 1), colors.white, colors.gray)
gui.buttonUraniumCells    = Button:new("ERR",              Rectangle:new(30, 14,        5, 1), colors.white, colors.red)
gui.labelLapislazuli      = Label:new("Lapislazuli:",      Rectangle:new( 3, 15,       15, 1), colors.white, colors.black)
gui.labelLapislazuliC     = Label:new("         0",        Rectangle:new(19, 15,       10, 1), colors.white, colors.gray)
gui.buttonLapislazuli     = Button:new("ERR",              Rectangle:new(30, 15,        5, 1), colors.white, colors.red)
gui.labelReactorHeat      = Label:new("Heat:",             Rectangle:new( 3, 17,       15, 1), colors.white, colors.black)
gui.labelReactorHeatC     = Label:new("         0",        Rectangle:new(19, 17,       10, 1), colors.white, colors.gray)
gui.buttonReactorHeat     = Button:new("ERR",              Rectangle:new(30, 17,        5, 1), colors.white, colors.red)
gui.labelReactorOutput    = Label:new("Output (Eu/t):",    Rectangle:new( 3, 18,       15, 1), colors.white, colors.black)
gui.labelReactorOutputC   = Label:new("         0",        Rectangle:new(19, 18,       10, 1), colors.white, colors.gray)
gui.buttonOutput          = Button:new("ERR",              Rectangle:new(30, 18,        5, 1), colors.white, colors.red)

gui.labelReactorState     = Label:new("State:",            Rectangle:new( 3, 20,       15, 1), colors.white, colors.black)
gui.labelReactorStateC    = Label:new(" Stopped  ",        Rectangle:new(19, 20,       10, 1), colors.white, colors.gray)

gui.buttonReactorOn       = Button:new("On",               Rectangle:new(12, 23,        6, 3), colors.white, colors.green, clickedButtonReactorOn)
gui.buttonReactorOff      = Button:new("Off",              Rectangle:new(19, 23,        7, 3), colors.white, colors.red,   clickedButtonReactorOff)

gui.labelBreeder          = Label:new("Breeder",           Rectangle:new(displayM +  1, 12, displayM, 1), colors.white, colors.black)
gui.labelDepletedCells    = Label:new("Depleted Cells:",   Rectangle:new(displayM +  3, 14,       15, 1), colors.white, colors.black)
gui.labelDepletedCellsC   = Label:new("         0",        Rectangle:new(displayM + 19, 14,       10, 1), colors.white, colors.gray)
gui.buttonDepletedCells   = Button:new("ERR",              Rectangle:new(displayM + 30, 14,        5, 1), colors.white, colors.red)
gui.labelBreederHeat      = Label:new("Heat:",             Rectangle:new(displayM +  3, 17,       15, 1), colors.white, colors.black)
gui.labelBreederHeatC     = Label:new("         0",        Rectangle:new(displayM + 19, 17,       10, 1), colors.white, colors.gray)
gui.buttonBreederHeat     = Button:new("ERR",              Rectangle:new(displayM + 30, 17,        5, 1), colors.white, colors.red)
gui.labelCriticalHeat     = Label:new("Critical Heat:",    Rectangle:new(displayM +  3, 18,       15, 1), colors.white, colors.black)
gui.labelCriticalHeatC    = Label:new("         0",        Rectangle:new(displayM + 19, 18,       10, 1), colors.white, colors.gray)

gui.labelBreederState     = Label:new("State:",            Rectangle:new(displayM +  3, 20,       15, 1), colors.white, colors.black)
gui.labelBreederStateC    = Label:new(" Stopped  ",        Rectangle:new(displayM + 19, 20,       10, 1), colors.white, colors.gray)

gui.buttonBreederOn       = Button:new("On",               Rectangle:new(displayM + 12, 23,        6, 3), colors.white, colors.green, clickedButtonBreederOn)
gui.buttonBreederOff      = Button:new("Off",              Rectangle:new(displayM + 19, 23,        7, 3), colors.white, colors.red,   clickedButtonBreederOff)

-- todo: charge/discharge rate, in/outputs, reactor control, reactor inventories (lzh, lapislazuli), breeder

for _, child in pairs(gui) do
	display:addChild(child)
end

local function accumulateSensorData()
	local sensordata = {
		stored = 0,
		capacity = 0,
		chargeRate = 0,
		dischargeRate = 0,
	}
	
	for _,i in pairs(lastsensordata.mfsu) do
		sensordata.stored = sensordata.stored + i.stored
		sensordata.capacity = sensordata.capacity + i.capacity
		sensordata.chargeRate = sensordata.chargeRate + i.chargeRate
		sensordata.dischargeRate = sensordata.dischargeRate + i.dischargeRate
	end
	sensordata.percent = (sensordata.stored / sensordata.capacity) * 100.0
	
	for k,v in pairs(sensordata) do
		lastsensordata[k] = v
	end
end

local function updateGui()
	gui.labelEnergyStoredC.text = string.format("%10d kEu ", lastsensordata.stored / 1000)
	setButton(gui.buttonEnergyStored, (lastsensordata.stored > 0), "OK", "EMPTY")
	
	gui.labelEnergyCapacityC.text = string.format("%10d kEu ", lastsensordata.capacity / 1000)
	setButton(gui.buttonEnergyCapacity, (lastsensordata.capacity > 6 * 4 * 4 * 1000000), "OK", "ERROR")
	
	gui.labelEnergyPercentC.text = string.format("%10d %%   ", lastsensordata.percent)
	setButton(gui.buttonEnergyPercent, lastsensordata.percent, "OK", "EMPTY")

	gui.labelEnergyChargeC.text = string.format("%10d Eu/t", lastsensordata.chargeRate)
	gui.labelEnergyDischargeC.text = string.format("%10d Eu/t", lastsensordata.dischargeRate)


	if lastsensordata.reactor.uraniumcells > 64 then
		gui.labelUraniumCellsC.text = string.format("%4d*64+%2d", math.floor(lastsensordata.reactor.uraniumcells/64), lastsensordata.reactor.uraniumcells%64)
	else
		gui.labelUraniumCellsC.text = string.format("        %2d", lastsensordata.reactor.uraniumcells)
	end
	setButton(gui.buttonUraniumCells, (lastsensordata.reactor.uraniumcells > 0), "OK", "ERR")

	if lastsensordata.reactor.lapislazuli > 64 then
		gui.labelLapislazuliC.text = string.format("%4d*64+%2d", math.floor(lastsensordata.reactor.lapislazuli/64), lastsensordata.reactor.lapislazuli%64)
	else
		gui.labelLapislazuliC.text = string.format("        %2d", lastsensordata.reactor.lapislazuli)
	end
	setButton(gui.buttonLapislazuli, (lastsensordata.reactor.lapislazuli > 0), "OK", "ERR")

	gui.labelReactorHeatC.text = string.format("%10d", lastsensordata.reactor.heat)
	setButton(gui.buttonReactorHeat, (lastsensordata.reactor.heat == 0), "OK ", "ERR")

	gui.labelReactorOutputC.text = string.format("%10d", lastsensordata.reactor.output)
	setButton(gui.buttonReactorOutput, (lastsensordata.reactor.output > 0), "OK", "ERR")
	
	if lastsensordata.reactor.state == 0 then
		gui.labelReactorStateC.text = " Stopped  "
		gui.labelReactorStateC.bgColor = colors.gray
	elseif lastsensordata.reactor.state < 0 then
		gui.labelReactorStateC.text = "  ERROR   "
		gui.labelReactorStateC.bgColor = colors.red
	else
		gui.labelReactorStateC.text = " Running  "
		gui.labelReactorStateC.bgColor = colors.green
	end

	if lastsensordata.breeder.depletedcells > 64 then
		gui.labelDepletedCellsC.text = string.format("%4d*64+%2d", math.floor(lastsensordata.breeder.depletedcells/64), lastsensordata.breeder.depletedcells%64)
	else
		gui.labelDepletedCellsC.text = string.format("        %2d", lastsensordata.breeder.depletedcells)
	end
	setButton(gui.buttonDepletedCells, (lastsensordata.breeder.depletedcells > 0), "OK", "ERR")

	gui.labelBreederHeatC.text = string.format("%10d", lastsensordata.breeder.heat)
	setButton(gui.buttonBreederHeat, (lastsensordata.breeder.heat < lastsensordata.breeder.criticalheat), "OK ", "ERR")

	gui.labelCriticalHeatC.text = string.format("%10d", lastsensordata.breeder.criticalheat)

	if lastsensordata.breeder.state == 0 then
		gui.labelBreederStateC.text = " Stopped  "
		gui.labelBreederStateC.bgColor = colors.gray
	elseif lastsensordata.breeder.state < 0 then
		gui.labelBreederStateC.text = "  ERROR   "
		gui.labelBreederStateC.bgColor = colors.red
	else
		gui.labelBreederStateC.text = " Running  "
		gui.labelBreederStateC.bgColor = colors.green
	end

	display:render()
end
 

local function doEvents()
	print("Event loop starting ...")
	while true do
		local event, param, message, p3, p4, p5 = os.pullEventRaw()
		
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
					rednetSend("heartbeat")

				elseif msg.cmd == "sensordata" then
					if lastsensordata.mfsu[param] == nil then
						lastsensordata.mfsu[param] = {}
					end

					for k,v in pairs(msg.data) do
						lastsensordata.mfsu[param][k] = v
					end
					
					accumulateSensorData()
				end
			end
		end
		
		display:interceptEvent(event, param, message, p3, p4, p5)
	end
	
	term.clear()
end

local function doMenu()
	print("Menu loop starting ...")
	term.clear()

	while true do
		sleep(1)
		updateGui()
		
		term.setCursorPos(1,1)
		
		term.clearLine()
		print(string.format("Reactor Control                (ID %03d)", os.getComputerID()))
		term.clearLine()
		print("")

		term.clearLine()
		print(string.format("Energy Storage:"))
		term.clearLine()
		print(string.format("  Stored:              %10d kEu ",  lastsensordata.stored / 1000))
		term.clearLine()
		print(string.format("  Capacity:            %10d kEu ",  lastsensordata.capacity / 1000))
		term.clearLine()
		print(string.format("  Percent:             %10d %%   ", lastsensordata.percent))
		term.clearLine()
		print("")
		
		term.clearLine()
		print(string.format("  Charge:              %10d Eu/t",  lastsensordata.chargeRate))
		term.clearLine()
		print(string.format("  Discharge:           %10d Eu/t",  lastsensordata.dischargeRate))
		term.clearLine()
		print("")
		
		term.clearLine()
		io.write("  Listener: ")
		for _,i in pairs(rednetTargets) do
			io.write(i.." ")
		end
		print("")
		
		term.clearLine()
		print("")
		term.clearLine()
		print("Q to exit")
	end
end

local function startup()
	print("Reactor Control starting...")

	rednet.open(peripherals.modem)
	rednetSend("announce")
	
	parallel.waitForAny(doEvents, doMenu)

	rednet.close(peripherals.modem)
end

local rtn, error = pcall(startup)
if not rtn then
	print("Reactor Control failed: " .. error)
end

display:clear()
