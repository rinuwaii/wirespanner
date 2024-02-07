-----------------------------------------------------------
-----------------------------------------------------------
------------------------ kaga.uifx ------------------------
----- previously: project midnight UI utility library -----
-----------------------------------------------------------
------ this version was specifically made for use in ------
------ studio plugins, it doesnt have nearly as much ------
-----------------------------------------------------------
--[[-------------------------------------------------------

	version history - rewrite soon (as of Feb 5th 2024)
	
	latest -> v1.4.2-ST (STUDIO PORT) 
	- ported multiSelect and TextBoxMustBeNum to Studio

	v1.4.1-ST (STUDIO PORT) 
	- ported mainline v1.4 to Studio but only the main button
	
]]---------------------------------------------------------
-----------------------------------------------------------

--[[
	written by @rinuwaii (fiteuwu on roblox for now)
	this is probably my proudest work
	
	for use only by rin (rinuwaii) herself, Cube Studios, and explicity permitted people
 	if you've made it here, you are welcome to ask permission to use it. just dm me on twitter or discord or something
 	(the full version not limited by in-studio UI interaction limitations is a lot cooler anyway, you can see it in "Project Midnight")
 	
 	ive got no problem with people looking through my plugins, thats how i learned how to make them anyway 
 	(just, yk, dont republish them as your own. make your own idea instead. yours is probably a lot cooler than mine!)
 	
 	ill prob be releasing the rewrite, so if youd rather wait on that then go ahead
]]

-----------------------------------------------------------
---- initalization ----------------------------------------
-----------------------------------------------------------

local UIS = game:GetService("UserInputService")
local TWS = game:GetService("TweenService")

local UIEffects   = {}

-----------------------------------------------------------
----  global utilities that are useful --------------------
-----------------------------------------------------------

----- easy centralized tweening
UIEffects.tween = function(obj, goal, direction, style, len)
	if direction == nil then direction	= 'InOut' end
	if style 	 == nil then style		= 'Quint' end
	if len		 == nil then len		= 0.5 end
	local FadeInfo = TweenInfo.new(len, Enum.EasingStyle[style], Enum.EasingDirection[direction])
	local the = TWS:Create(obj, FadeInfo, goal)
	the:Play()
	the:Destroy()
end

-----------------------------------------------------------
---- buttons & interfaces ---------------------------------
-----------------------------------------------------------

----- button effects
UIEffects.button = function(object, colored, altClick, altEvent, clickFunc:()->()?)
	local event = nil
	if not altClick or not altEvent then event = Instance.new('BindableEvent') end
	--if not noStroke then script.UIStroke:Clone().Parent = object.background end

	local mouseIn = false

	object.ClipsDescendants = false
	object.Selectable = false

	object.MouseEnter:Connect(function()
		mouseIn = true
		UIEffects.tween(object.background, {Size = UDim2.new(1,3,1,3)}, 'InOut', 'Quint', 0.1)

		if colored then
			UIEffects.tween(object.background.hover, {BackgroundTransparency = 0}, 'InOut', 'Quint', 0.2)
		else
			UIEffects.tween(object.background.hover, {BackgroundTransparency = 0.7}, 'InOut', 'Quint', 0.2)
		end
	end)

	object.MouseLeave:Connect(function()
		mouseIn = false
		UIEffects.tween(object.background, {Size = UDim2.new(1,0,1,0)}, 'InOut', 'Quint', 0.1)
		UIEffects.tween(object.background.hover, {BackgroundTransparency = 1}, 'InOut', 'Quint', 0.2)
	end)

	UIS.InputBegan:Connect(function(input)
		if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonA) then
			if mouseIn then
				object.background:TweenSize(UDim2.new(1,-5,1,-5), "InOut", "Quint", 0.05, true)
			end
		end
	end)

	UIS.InputEnded:Connect(function(input)
		if not altClick then
			if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonA) then
				if mouseIn then
					event:Fire()
					if clickFunc then clickFunc() end
					object.background:TweenSize(UDim2.new(1,0,1,0), "InOut", "Quint", 0.1, true)
				end
			end
		end
	end)

	if not altClick or not altEvent then return event end
end

----- multi select buttons group
UIEffects.multiSelect = function(objects, hoverColored, selectColored, valName, valLocation, default)
	local buttonEvents = {}

	---- reset to default
	local function reset()
		for _,o in pairs(objects) do
			UIEffects.tween(o.background.select, {BackgroundTransparency = 1}, 'InOut', 'Quint', 0.2)
		end
		if default then
			if selectColored then
				UIEffects.tween(default.background.select, {BackgroundTransparency = 0}, 'InOut', 'Quint', 0.2)
			else
				UIEffects.tween(default.background.select, {BackgroundTransparency = 0.7}, 'InOut', 'Quint', 0.2)
			end
			valLocation:SetAttribute(valName, default.Name)

		else valLocation:SetAttribute(valName, nil) end
	end
	local resetEvent = Instance.new('BindableEvent')
	resetEvent.Event:Connect(reset)

	---- set default value up
	if default then valLocation:SetAttribute(valName, default.Name)
	else valLocation:SetAttribute(valName, nil) end

	---- set up buttons
	for i, o in ipairs(objects) do
		local event = Instance.new('BindableEvent')

		UIEffects.button(o, hoverColored, false, false, function()
			if valLocation:GetAttribute(valName) == o.Name then
				reset()

			else
				event:Fire()
				o.background:TweenSize(UDim2.new(1,0,1,0), "InOut", "Quint", 0.1, true)

				for _,o2 in pairs(objects) do
					UIEffects.tween(o2.background.select, {BackgroundTransparency = 1}, 'InOut', 'Quint', 0.2)
				end

				if selectColored then
					UIEffects.tween(o.background.select, {BackgroundTransparency = 0}, 'InOut', 'Quint', 0.2)
				else
					UIEffects.tween(o.background.select, {BackgroundTransparency = 0.7}, 'InOut', 'Quint', 0.2)
				end

				valLocation:SetAttribute(valName, o.Name)

			end
		end)
		table.insert(buttonEvents, event)
	end

	reset()
	return buttonEvents, resetEvent
end

UIEffects.textBoxMustBeNum = function(object, reqLen, maxNumber, minNumber, nextObject)
	local oldText = object.Text -- assuming that the ui starts with a predefined value
	object.FocusLost:Connect(function(enterPressed, inputThatCausedFocusLost)
		local newText = object.Text

		if tonumber(newText) then
			newText = tonumber(newText)
		else
			newText = oldText
		end

		-- testing numbers
		-- make sure value is in the defined range 
		if maxNumber then
			if newText > maxNumber then newText = maxNumber end
		end
		if minNumber then
			if newText < minNumber then newText = minNumber end
		end

		-- format correcly
		local testNum = tostring(newText)
		if reqLen ~= 0 then
			if string.len(newText) < reqLen then
				testNum = "0"..testNum
			end
		end
		newText = testNum

		-- tab to next box if defined
		if enterPressed then
			if nextObject then
				nextObject:CaptureFocus()
			end
		end

		object.Text = newText
	end)
end

return UIEffects
