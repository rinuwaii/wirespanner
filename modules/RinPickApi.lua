-------------------------------------------------------------------
---- Slider based HSV* color picker
-------------------------------------------------------------------
---- CREDITS
---- ToldFable/dispeller - - 2020 (creator)
---- Stonetr03 - - - - - - - 2021 (UI tweaks, two-slider RGB format, RGB input)
---- fiteuwu/rinuwaii - - -  2022 (UI refresh, script combination, optimization, HEX input)
---- fiteuwu/rinuwaii - - -  2024 (rescript, HSV-based sliders, ui rework, API)
-------------------------------------------------------------------
---- VARS
-- services
local UIS = game:GetService('UserInputService')

-- modules
local uifx = require(script.Parent.kagaUIFX)

-- top level ui
-- dirty way of doing it but idc really
local UI = script.Parent.Parent.UI.wirespanner.pages.colorPickerFrame.colorPicker

-- previews
local newPreview = UI.buttons.new
local oldPreview = UI.buttons.old

-- buttons
local pickBtn = UI.buttons.pickBtn
local cancelBtn = UI.buttons.cancelBtn

-- sliders
local uiSlide = {
	h = {
		name = 'h',
		area = UI.sliderH,
		slider = UI.sliderH.slider,
		grad = UI.sliderH.gradient.UIGradient
	},
	s = {
		name = 's',
		area = UI.sliderS,
		slider = UI.sliderS.slider,
		grad = UI.sliderS.gradient.UIGradient
	},
	v = {
		name = 'v',
		area = UI.sliderV,
		slider = UI.sliderV.slider,
		grad = UI.sliderV.gradient.UIGradient
	}
}

-- inputs
local uiIn = {
	rgb = {
		r = UI.RGB.R.input,
		g = UI.RGB.G.input,
		b = UI.RGB.B.input
	},
	hsv = {
		h = UI.HSV.H.input,
		s = UI.HSV.S.input,
		v = UI.HSV.V.input
	},
	hex = UI.HEX.TextBox.input
}

-------------------------------------------------------------------
---- FUNCTIONS

local function GetColorFromGradient (percentage, ColorKeyPoints)
	if (percentage < 0) or (percentage>1) then
		--error'getColor percentage out of bounds!'
		warn'getColor got out of bounds percentage (less than 0 or greater than 1'
	end

	local closestToLeft = ColorKeyPoints[1]
	local closestToRight = ColorKeyPoints[#ColorKeyPoints]
	local LocalPercentage = .5
	local color = closestToLeft.Value

	-- This loop can probably be improved by doing something like a Binary search instead
	-- This should work fine though
	for i=1,#ColorKeyPoints-1 do
		if (ColorKeyPoints[i].Time <= percentage) and (ColorKeyPoints[i+1].Time >= percentage) then
			closestToLeft = ColorKeyPoints[i]
			closestToRight = ColorKeyPoints[i+1]
			LocalPercentage = (percentage-closestToLeft.Time)/(closestToRight.Time-closestToLeft.Time)
			color = closestToLeft.Value:lerp(closestToRight.Value,LocalPercentage)
			return color
		end
	end
	warn('Color not found!')
	return color
end

local function UpdateAllValues(activeSlider:string, newColor3:Color3?)

	local hSliderPos, sSliderPos, vSliderPos
	if newColor3 == nil then
		-- getting color from slider positions
		hSliderPos = uiSlide.h.slider.Position.X.Scale
		sSliderPos = uiSlide.s.slider.Position.X.Scale
		vSliderPos = uiSlide.v.slider.Position.X.Scale
		newColor3 = Color3.fromHSV(hSliderPos,sSliderPos,vSliderPos)

	else
		-- getting color from input and setting slider positions automatically	
		hSliderPos, sSliderPos, vSliderPos = newColor3:ToHSV()
	end

	---- slider gradients
	-- update saturation and value slider colors
	local newSSlider = ColorSequence.new{
		ColorSequenceKeypoint.new(0, Color3.fromHSV(hSliderPos,0,vSliderPos)),
		ColorSequenceKeypoint.new(1, Color3.fromHSV(hSliderPos,1,vSliderPos))
	}
	local newVSlider = ColorSequence.new{
		ColorSequenceKeypoint.new(0, Color3.fromHSV(hSliderPos,sSliderPos,0)),
		ColorSequenceKeypoint.new(1, Color3.fromHSV(hSliderPos,sSliderPos,1))
	}
	uiSlide.s.grad.Color = newSSlider
	uiSlide.v.grad.Color = newVSlider

	---- update all inputs 
	-- update slider pull position but not if they are in use because that would be awkward
	if activeSlider ~= 'h' then uiSlide.h.slider.Position = UDim2.new(hSliderPos,0,0.5,0) end
	if activeSlider ~= 's' then uiSlide.s.slider.Position = UDim2.new(sSliderPos,0,0.5,0) end
	if activeSlider ~= 'v' then uiSlide.v.slider.Position = UDim2.new(vSliderPos,0,0.5,0) end
	-- color preview
	newPreview.BackgroundColor3 = newColor3
	newPreview.cornerCutter.BackgroundColor3 = newColor3
	-- HSV input strings (more accurate reading then directly from the bars)
	uiIn.hsv.h.Text = tostring(math.floor(hSliderPos * 360))
	uiIn.hsv.s.Text = tostring(math.floor(sSliderPos * 100))
	uiIn.hsv.v.Text = tostring(math.floor(vSliderPos * 100))
	-- update RBG input strings
	uiIn.rgb.r.Text = tostring(math.floor(newColor3.R * 255))
	uiIn.rgb.g.Text = tostring(math.floor(newColor3.G * 255))
	uiIn.rgb.b.Text = tostring(math.floor(newColor3.B * 255))
	-- Hex input strings
	uiIn.hex.Text = newColor3:ToHex()

end

local selecting = false
local function PullSliders(slider)
	selecting = true
	repeat wait()

		-- get the edge positions and calculate the full width of the area
		local minXPos = slider.area.AbsolutePosition.X
		local maxXPos = minXPos+slider.area.AbsoluteSize.X
		local xPixelSize = maxXPos-minXPos

		-- raw Mouse X pixel position
		local mouseX = UIS:GetMouseLocation().X

		-- constraints
		if mouseX<minXPos then
			mouseX = minXPos
		elseif mouseX>maxXPos then
			mouseX = maxXPos
		end

		-- get percentage mouse is on
		local xPos = (mouseX-minXPos)/xPixelSize

		-- move the visual Picker line
		slider.slider.Position = UDim2.new(xPos,0,0.5,0)

		UpdateAllValues(slider.name)

	until not selecting
end

local function CheckInRange(input, min, max)
	input = tonumber(input)
	if input ~= nil then
		if input < min or input > max then
			input = nil
		end
	end
	return input
end

local function UpdateFromInput(inType)

	local newColor3
	local isValid = true

	if inType == 'hsv' then
		local checkH = CheckInRange(uiIn.hsv.h.Text, 0, 360)
		local checkS = CheckInRange(uiIn.hsv.s.Text, 0, 100)
		local checkV = CheckInRange(uiIn.hsv.v.Text, 0, 100)

		if checkH == nil or checkS == nil or checkV == nil then isValid = false 
		else
			newColor3 = Color3.fromHSV(checkH/360, checkS/100, checkV/100)
		end 

	elseif inType == 'rgb' then
		local checkR = CheckInRange(uiIn.rgb.r.Text, 0, 255)
		local checkG = CheckInRange(uiIn.rgb.g.Text, 0, 255)
		local checkB = CheckInRange(uiIn.rgb.b.Text, 0, 255)

		if checkR == nil or checkG == nil or checkB == nil then isValid = false 
		else
			newColor3 = Color3.fromRGB(checkR, checkG, checkB)
		end

	elseif inType == 'hex' then
		local checkHex
		-- im using a pcall because i cant find a good way to test if a hex value is valid
		local success = pcall(function()
			checkHex = Color3.fromHex(uiIn.hex.Text)
		end)

		if success == false then isValid = false
		else
			newColor3 = checkHex
		end
	end

	if not isValid then -- if the input wasnt valid, grab the old color from the preview and apply it
		newColor3 = newPreview.BackgroundColor3
	end

	print(newColor3)

	UpdateAllValues('', newColor3)
end

-------------------------------------------------------------------
---- module exports
return {
	
	PromptPickColor = function(oldColor:Color3)
		
		local pickEvent, pickConnection, cancelConnection

		-- add connections on prompt and save them to a table so we can disconnect them later
		local conns = {}
		conns[#conns+1] = uiSlide.h.area.MouseButton1Down:Connect(function() PullSliders(uiSlide.h) end)
		conns[#conns+1] = uiSlide.h.area.InputEnded:Connect(function() selecting = false end)
		conns[#conns+1] = uiSlide.s.area.MouseButton1Down:Connect(function() PullSliders(uiSlide.s) end)
		conns[#conns+1] = uiSlide.s.area.InputEnded:Connect(function() selecting = false end)
		conns[#conns+1] = uiSlide.v.area.MouseButton1Down:Connect(function() PullSliders(uiSlide.v) end)
		conns[#conns+1] = uiSlide.v.area.InputEnded:Connect(function() selecting = false end)

		conns[#conns+1] = uiIn.hsv.h.FocusLost:Connect(function() UpdateFromInput('hsv') end)
		conns[#conns+1] = uiIn.hsv.s.FocusLost:Connect(function() UpdateFromInput('hsv') end)
		conns[#conns+1] = uiIn.hsv.v.FocusLost:Connect(function() UpdateFromInput('hsv') end)
		conns[#conns+1] = uiIn.rgb.r.FocusLost:Connect(function() UpdateFromInput('rgb') end)
		conns[#conns+1] = uiIn.rgb.g.FocusLost:Connect(function() UpdateFromInput('rgb') end)
		conns[#conns+1] = uiIn.rgb.b.FocusLost:Connect(function() UpdateFromInput('rgb') end)
		conns[#conns+1] = uiIn.hex.FocusLost:Connect(function() UpdateFromInput('hex') end)

		-- set old color preview and all inputs to the old color
		oldPreview.BackgroundColor3 = oldColor
		oldPreview.cornerCutter.BackgroundColor3 = oldColor
		UpdateAllValues('', oldColor)
		
		local newColor = nil
		conns[#conns+1] = uifx.button(pickBtn, false).Event:Connect(function()
			newColor = newPreview.BackgroundColor3
		end)
		conns[#conns+1] = uifx.button(cancelBtn, false).Event:Connect(function()
			newColor = oldColor
		end)
		
		repeat task.wait() until newColor
	
		-- cleanup
		for i,v in ipairs(conns) do v:Disconnect() end
		
		return newColor
	end,
	
}
