local CurrentAction = nil
local GUI                       = {}
GUI.Time                        = 0
local HasAlreadyEnteredMarker   = false
local LastZone                  = nil
local CurrentActionMsg          = ''
local CurrentActionData         = {}

local this_Garage = {}
ESX = nil

Citizen.CreateThread(function()
	while ESX == nil do
		TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
		Citizen.Wait(0)
	end
end)

RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(xPlayer)
    --PlayerData = xPlayer
    --TriggerServerEvent('esx_jobs:giveBackCautionInCaseOfDrop')
    refreshBlips()
end)

function refreshBlips()
	local zones = {}
	local blipInfo = {}	

	for zoneKey, zoneValues in pairs(Config.Garages)do
		local blip = AddBlipForCoord(zoneValues.Pos.x, zoneValues.Pos.y, zoneValues.Pos.z)
		SetBlipSprite (blip, Config.BlipInfos.Sprite)
		SetBlipDisplay(blip, 4)
		SetBlipScale  (blip, 1.2)
		SetBlipColour (blip, Config.BlipInfos.Color)
		SetBlipAsShortRange(blip, true)
		BeginTextCommandSetBlipName("STRING")
		AddTextComponentString(zoneKey)
		EndTextCommandSetBlipName(blip)
	end
end

function OpenMenuGarage()
	ESX.UI.Menu.CloseAll()

	local elements = {
		{label = "List Vehicles", value = 'list_vehicles'},
		{label = "Return Vehicle", value = 'stock_vehicle'},
		--{label = "Retour vehicule ("..Config.Price.."$)", value = 'return_vehicle'},
	}

	ESX.UI.Menu.Open(
		'default', GetCurrentResourceName(), 'garage_menu',
		{
			title    = 'Garage',
			align    = 'top-left',
			elements = elements,
		},
		function(data, menu)
			menu.close()
			
			if data.current.value == 'list_vehicles' then
				ListVehiclesMenu()
			elseif data.current.value == 'stock_vehicle' then
				StockVehicleMenu()
			elseif data.current.value == 'return_vehicle' then
				ReturnVehicleMenu()
			end

			local playerPed = GetPlayerPed(-1)
			SpawnVehicle(data.current.value)
			--local coords    = societyConfig.Zones.VehicleSpawnPoint.Pos
		end,
		function(data, menu)
			menu.close()
			--CurrentAction = 'open_garage_action'
	end)	
end

function ListVehiclesMenu()
	local elements = {}

	ESX.TriggerServerCallback('eden_garage:getVehicles', function(vehicles)
		for _,v in pairs(vehicles) do
			local hashVehicule = v.vehicle.model
			local vehicleName = GetDisplayNameFromVehicleModel(hashVehicule)
			local labelvehicle
				
			if v.state then
				labelvehicle = vehicleName..': Returns'
			else
				labelvehicle = vehicleName..': Already Out'
			end	
			
			table.insert(elements, {label =labelvehicle , value = v})
		end

		ESX.UI.Menu.Open(
		'default', GetCurrentResourceName(), 'spawn_vehicle',
		{
			title = 'Garage',
			align = 'top-left',
			elements = elements,
		},
		function(data, menu)
			if(data.current.value.state)then
				menu.close()
				SpawnVehicle(data.current.value.vehicle)
			else
				TriggerEvent('esx:showNotification', 'Your vehicle is already out!')
			end
		end,
		function(data, menu)
			menu.close()
			--CurrentAction = 'open_garage_action'
		end)	
	end)
end

function StockVehicleMenu()
	local playerPed = GetPlayerPed(-1)
	if IsAnyVehicleNearPoint(this_Garage.DeletePoint.Pos.x,  this_Garage.DeletePoint.Pos.y,  this_Garage.DeletePoint.Pos.z,  30.5) then

		local vehicle = GetClosestVehicle(this_Garage.DeletePoint.Pos.x, this_Garage.DeletePoint.Pos.y, this_Garage.DeletePoint.Pos.z, this_Garage.DeletePoint.Size.x, 0, 70)
		local vehicleProps = ESX.Game.GetVehicleProperties(vehicle)

		ESX.TriggerServerCallback('eden_garage:stockv', function(valid)

			if(valid) then
				TriggerServerEvent('eden_garage:debug', vehicle)
				DeleteVehicle(vehicle)
				TriggerServerEvent('eden_garage:modifystate', vehicleProps, true)
				TriggerEvent('esx:showNotification', 'Your vehicle is in the garage')
			else
				TriggerEvent('esx:showNotification', 'You must be outside your vehicle to park it!')
			end
		end, vehicleProps)
	else
		TriggerEvent('esx:showNotification', 'There is no vehicle to enter')
	end

end

function SpawnVehicle(vehicle)

	ESX.Game.SpawnVehicle(vehicle.model,{
			x=this_Garage.SpawnPoint.Pos.x ,
			y=this_Garage.SpawnPoint.Pos.y,
			z=this_Garage.SpawnPoint.Pos.z + 1											
		}, this_Garage.SpawnPoint.Heading, function(callback_vehicle)
			ESX.Game.SetVehicleProperties(callback_vehicle, vehicle)
			SetVehRadioStation(callback_vehicle, "OFF")
			TaskWarpPedIntoVehicle(GetPlayerPed(-1), callback_vehicle, -1)
	end)
	TriggerServerEvent('eden_garage:modifystate', vehicle, false)

end

AddEventHandler('eden_garage:hasEnteredMarker', function(zone)
	if zone == 'garage' then
		CurrentAction = 'garage_action_menu'
		CurrentActionMsg = "Press ~INPUT_PICKUP~ to open the garage"
		CurrentActionData = {}
	end
end)

AddEventHandler('eden_garage:hasExitedMarker', function(zone)
	ESX.UI.Menu.CloseAll()
	CurrentAction = nil
end)

function ReturnVehicleMenu()
	ESX.TriggerServerCallback('eden_garage:getOutVehicles', function(vehicles)
		local elements = {}

		for _,v in pairs(vehicles) do
			local hashVehicule = v.model
			local vehicleName = GetDisplayNameFromVehicleModel(hashVehicule)
			local labelvehicle
				
			labelvehicle = vehicleName..': Out'
    	
			table.insert(elements, {label =labelvehicle , value = v})		
		end

		ESX.UI.Menu.Open(
		'default', GetCurrentResourceName(), 'return_vehicle',
		{
			title = 'Garage',
			align = 'top-left',
			elements = elements,
		},
		function(data, menu)
			ESX.TriggerServerCallback('eden_garage:checkMoney', function(hasEnoughMoney)
				if hasEnoughMoney then		
					TriggerServerEvent('eden_garage:pay')
					SpawnVehicle(data.current.value)
				else
					ESX.ShowNotification('You do not have enough money')						
				end
			end)
		end,
		function(data, menu)
			menu.close()
			--CurrentAction = 'open_garage_action'
		end
		)	
	end)
end

Citizen.CreateThread(function()
	while true do
		Wait(0)		
		local coords = GetEntityCoords(GetPlayerPed(-1))			
		for k,v in pairs(Config.Garages) do
			if(GetDistanceBetweenCoords(coords, v.Pos.x, v.Pos.y, v.Pos.z, true) < Config.DrawDistance) then		
				DrawMarker(v.Marker, v.Pos.x, v.Pos.y, v.Pos.z, 0.0, 0.0, 0.0, 0, 0.0, 0.0, v.Size.x, v.Size.y, v.Size.z, v.Color.r, v.Color.g, v.Color.b, 100, false, true, 2, false, false, false, false)
				DrawMarker(v.SpawnPoint.Marker, v.SpawnPoint.Pos.x, v.SpawnPoint.Pos.y, v.SpawnPoint.Pos.z, 0.0, 0.0, 0.0, 0, 0.0, 0.0, v.SpawnPoint.Size.x, v.SpawnPoint.Size.y, v.SpawnPoint.Size.z, v.SpawnPoint.Color.r, v.SpawnPoint.Color.g, v.SpawnPoint.Color.b, 100, false, true, 2, false, false, false, false)	
				DrawMarker(v.DeletePoint.Marker, v.DeletePoint.Pos.x, v.DeletePoint.Pos.y, v.DeletePoint.Pos.z, 0.0, 0.0, 0.0, 0, 0.0, 0.0, v.DeletePoint.Size.x, v.DeletePoint.Size.y, v.DeletePoint.Size.z, v.DeletePoint.Color.r, v.DeletePoint.Color.g, v.DeletePoint.Color.b, 100, false, true, 2, false, false, false, false)	
			end		
		end	
	end
end)

Citizen.CreateThread(function()
	local currentZone = 'garage'
	while true do
		Wait(0)
		local coords = GetEntityCoords(GetPlayerPed(-1))
		local isInMarker = false

		for _,v in pairs(Config.Garages) do
			if(GetDistanceBetweenCoords(coords, v.Pos.x, v.Pos.y, v.Pos.z, true) < v.Size.x) then
				isInMarker = true
				this_Garage = v
			end
		end

		if isInMarker and not hasAlreadyEnteredMarker then
			hasAlreadyEnteredMarker = true
			LastZone = currentZone
			TriggerEvent('eden_garage:hasEnteredMarker', currentZone)
		end

		if not isInMarker and hasAlreadyEnteredMarker then
			hasAlreadyEnteredMarker = false
			TriggerEvent('eden_garage:hasExitedMarker', LastZone)
		end
	end
end)

Citizen.CreateThread(function()
	while true do
		Citizen.Wait(0)
		if CurrentAction ~= nil then
			SetTextComponentFormat('STRING')
			AddTextComponentString(CurrentActionMsg)
			DisplayHelpTextFromStringLabel(0, 0, 1, -1)

			if IsControlPressed(0, 38) and (GetGameTimer() - GUI.Time) > 150 then
				if CurrentAction == 'garage_action_menu' then
					OpenMenuGarage()
				end
				CurrentAction = nil
				GUI.Time = GetGameTimer()
			end
		end
	end
end)
