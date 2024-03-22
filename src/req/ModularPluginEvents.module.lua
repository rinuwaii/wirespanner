return function(ui, plugin, name, icon, tooltip)
	
	---- requires
	local sharedToolbar = require(script.Parent.SharedToolbar)
	local TBS = {} :: sharedToolbar.SharedToolbarSettings

	---- setup toggle stuff
	local state = false
	local function TogglePlugin(inState)
		if inState == nil then inState = not state end
		state = inState
		
		ui:SetAttribute('uiOpen', state)
		TBS.Button:SetActive(state)
		if state then plugin:Activate(false) end
	end
	
	plugin.Deactivation:connect(function()
		TogglePlugin(false)
	end)

	---- edit section
	TBS.ButtonName = name
	TBS.ButtonIcon = icon
	TBS.ButtonTooltip = tooltip
	TBS.CombinerName = "rinstuff"
	TBS.ToolbarName = "rin's tools"
	TBS.ClickedFn = TogglePlugin

	---- setup shared toolbar
	sharedToolbar(plugin, TBS)
	
	---------------------
	---------------------
	---- add to rebar
	-- this is my custom toolbar thingy
	
	local cGUI = game:GetService('CoreGui')
	local addedToRebar = false
	local rebarInstance = nil

	local function AddToRebar()
		local newEvent = Instance.new('BindableEvent')
		newEvent:SetAttribute('pluginName', name)
		newEvent:SetAttribute('pluginIcon', icon)
		newEvent.Event:Connect(TogglePlugin)
		newEvent.Parent = cGUI:WaitForChild('reBar'):WaitForChild('connections')
	end

	if cGUI:FindFirstChild('reBar') then
		AddToRebar()
	end

	cGUI.ChildAdded:Connect(function(child)
		if child.Name == 'reBar' then
			if (not addedToRebar) or (rebarInstance ~= child) then
				rebarInstance = child
				AddToRebar()
			end
		end
	end)
	
end