return function(ui, plugin)
	
	---- requires
	local sharedToolbar = require(script.Parent.SharedToolbar)
	local TBS = {} :: sharedToolbar.SharedToolbarSettings

	---- setup toggle stuff
	local state = false
	local function togglePlugin(forceState)
		print('hi')
		if forceState == nil then forceState = false end
		ui:SetAttribute('uiOpen', forceState)
		TBS.Button:SetActive(forceState)
		state = forceState
		if state then plugin:Activate(false) end
	end

	plugin.Deactivation:connect(function()
		togglePlugin(false)
	end)

	---- edit section
	TBS.ButtonName = "Wirespanner"
	TBS.ButtonIcon = "rbxassetid://14270498279"
	TBS.ButtonTooltip = "Easily place down spans of wire!"
	TBS.CombinerName = "rinstuff"
	TBS.ToolbarName = "rins things"
	TBS.ClickedFn = function()
		state = not state
		if state then togglePlugin(true)
		else togglePlugin(false)
		end
	end

	---- setup shared toolbar
	sharedToolbar(plugin, TBS)
	
	
end
