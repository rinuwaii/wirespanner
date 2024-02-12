return function(ui, plugin)
	
	---- requires
	local sharedToolbar = require(script.Parent.SharedToolbar)
	local TBS = {} :: sharedToolbar.SharedToolbarSettings

	---- setup toggle stuff
	local state = false
	local function togglePlugin(forceState)
		if forceState == nil then forceState = false end
		ui:SetAttribute('uiOpen', forceState)
		TBS.Button:SetActive(forceState)
		state = forceState
	end

	plugin.Deactivation:connect(function()
		togglePlugin(false)
	end)

	---- edit section
	TBS.ButtonName = "Wirespanner"
	TBS.ButtonIcon = "rbxassetid://16326291280"
	TBS.ButtonTooltip = "Easily place down spans of wire!"
	TBS.CombinerName = "rinstuff"
	TBS.ToolbarName = "rin's tools"
	TBS.ClickedFn = function()
		state = not state
		if state then togglePlugin(true)
		else togglePlugin(false)
		end
	end

	---- setup shared toolbar
	sharedToolbar(plugin, TBS)
	
	
end