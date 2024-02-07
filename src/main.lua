---------------------------------------------------------
--[[

	WIRESPANNER vBETA-GH-1
	
	written by rinuwaii
	
	---------------------------------------
	
	CHANGELOG
	
	vBETA-GH-1 -> 2-7-24
	- initial (beta) release to github and Cube Studios developers

]]
---------------------------------------------------------
---- VARS

local _v = 'BETA-GH-1'

-- services
local CHS = game:GetService("ChangeHistoryService")
local SLS = game:GetService("Selection")
local STS = game:GetService("StudioService")

-- ui
local ui = script.UI.wirespanner
local mainPage = ui.pages.mainFrame
local options = mainPage.optionFrame
local colorPickerUI = ui.pages.colorPickerFrame
ui:SetAttribute('uiOpen', false)

-- modules
local UIFX = require(script.req.kagaUIFX)
local pluginEvents = require(script.req.ModularPluginEvents)(ui, plugin)
local colorPicker = require(script.req.RinPickApi)

-- internal globals
local indName = '_wirespannerIndicator_'..tostring(STS:GetUserId())

local randomGen = Random.new(tick())

local attCount = 0
local attachments = {}
local wires = {}
local modelCount = 0
local modelAttachments = {}

-- ui linked
local active = false
local mouse = plugin:GetMouse()

local conf = {
	wireColor		= BrickColor.new(Color3.new(0,0,0)),
	wireWidth		= 0.2,
	slackToggled	= false,
	slackMin		= 0.1,
	slackMax		= 0.2,
	modelModeToggled= false,
	modelSlackMode	= 'random', --or 'same'
}

---------------------------------------------------------
---- FUNCTIONS

local function deepCopy(original)
	local copy = {}
	for k, v in pairs(original) do
		if type(v) == "table" then
			v = deepCopy(v)
		end
		copy[k] = v
	end
	return copy
end

local function placeAttachment()
	local newAtt = Instance.new('Attachment')
	newAtt.Parent = mouse.Target
	newAtt.WorldPosition = mouse.Hit.p
	table.insert(attachments[#attachments], newAtt)
	return newAtt
end

local function placeRope(v, o, slackLength)
	local newRope = Instance.new('RopeConstraint')
	newRope.Parent = v.Parent
	newRope.Attachment0 = v
	newRope.Attachment1 = o
	
	if conf.slackToggled then
		if not slackLength then slackLength = randomGen:NextNumber(conf.slackMin, conf.slackMax) end
	else
		slackLength = 0
	end
	
	newRope.Length = newRope.CurrentDistance + slackLength
	newRope.Color = conf.wireColor
	newRope.Thickness = conf.wireWidth
	
	newRope.Visible = true
	table.insert(wires[#wires], newRope)
	return newRope
end

local function findAttachmentsInModel(model:Model)
	local foundAttachments = {}
	for _,o in pairs(model:GetDescendants()) do
		if o:IsA("Attachment") then
			-- check if it isnt the default name
			local use = true
			for i, v in foundAttachments do 
				if v.Name == o.Name then use = false end
			end
			
			if o.Name == 'Attachment' then
				use = false
			end
			
			if use then
				foundAttachments[o.Name] = o
			end
		end
	end
	if foundAttachments ~= nil then
		modelAttachments[#modelAttachments+1] = foundAttachments
		return true
	else
		return false
	end
end

local function connectModelAttachments()
	
	local modelAttsA = modelAttachments[#modelAttachments-1]
	local modelAttsB = modelAttachments[#modelAttachments]
	local modelAttsA_copy = deepCopy(modelAttsA)
	local modelAttsB_copy = deepCopy(modelAttsB)
	
	local matches = {}
	
	-- check for matching pairs of attachments and remove matches from copied table
	for k, v in pairs(modelAttsA_copy) do
		if modelAttsB_copy[k] then
			matches[#matches+1] = {v, modelAttsB_copy[k]}
			modelAttsA_copy[k] = nil
			modelAttsB_copy[k] = nil
		end
	end
	
	-- remove non matches from main list
	for _, v in pairs(modelAttsA_copy) do
		table.remove(modelAttsA, table.find(modelAttsA, v))
	end
	for _, v in pairs(modelAttsB_copy) do
		table.remove(modelAttsB, table.find(modelAttsB, v))
	end
	
	-- connect matches
	local randomNum = 0
	if conf.modelSlackMode == 'same' then
		randomNum = randomGen:NextNumber(conf.slackMin, conf.slackMax)
	end
	for _,v in matches do
		if conf.modelSlackMode == 'same' then placeRope(v[1], v[2], randomNum)
		else placeRope(v[1], v[2])
		end
	end
end

local function FindTopmostModel(part)
	local foundModel = nil
	if part:IsA('Model') or part:IsA('BasePart') then
		if part.Parent == workspace then
			if part:IsA('Model') then foundModel = part
			elseif part:IsA('BasePart') then
				local partDesendantsThatAreModels = part:FindFirstChildOfClass('Model', true)
				if partDesendantsThatAreModels then foundModel = partDesendantsThatAreModels end
			end
		else 
			foundModel = FindTopmostModel(part.Parent)
		end
	end
	return foundModel
end

local function CleanTables(tab:{}, parent:{}?)
	for k, v in pairs(tab) do
		if typeof(v) == "table" then
			if v == {} or v == nil or #v == 0 then table.remove(v, k); print('empty table found')
			else v = CleanTables(v, tab)
			end
		elseif typeof(v) == 'Instance' then
			if v:IsA('Attachment') then
				if v.Parent == nil then table.remove(parent, k); print('dead attachment found') end
			elseif v:IsA('RopeConstraint') then
				if v.Parent == nil or v.Attachment0 == nil or v.Attachment1 == nil then table.remove(parent, k); print('dead wire found') end
			end
		end
	end
	return tab
end

local function cleanup()
	
	attachments = CleanTables(attachments)
	modelAttachments = CleanTables(modelAttachments)
	wires = CleanTables(wires)
	
	for i, o in ipairs(attachments) do
		if #o == 1 then o[1]:Destroy(); print('found stray attachments') end
	end
	attachments = CleanTables(attachments)
end

local function switchToggleButton(button, state)
	if state then
		UIFX.tween(button.background, {BackgroundColor3 = Color3.fromRGB(141, 208, 94)}, 'InOut', 'Quint', 0.2)
		button.stuff.text.Text = 'On'
	else
		UIFX.tween(button.background, {BackgroundColor3 = Color3.fromRGB(223, 101, 101)}, 'InOut', 'Quint', 0.2)
		button.stuff.text.Text = 'Off'
	end
end

local function updateOptionsUI()
	options.modelSlackMode.Visible = (conf.slackToggled and conf.modelModeToggled)
	options.slackAmmount.Visible = conf.slackToggled
	
	options.color.preview.BackgroundColor3 = conf.wireColor.Color
	
	if active then
		local sameRand = randomGen:NextNumber(conf.slackMin, conf.slackMax)
		for i,v in pairs(wires[#wires]) do
			
			v.Color = conf.wireColor
			v.Thickness = conf.wireWidth
			
			local slackLength
			if conf.slackToggled then
				if conf.modelSlackMode == 'same' then slackLength = sameRand
				else slackLength = randomGen:NextNumber(conf.slackMin, conf.slackMax)
				end
			else
				slackLength = 0
			end
			v.Length = v.CurrentDistance + slackLength
			
		end
	end
end

local function toggleUI(state)
	if state then
		ui.Visible = true
		ui.Position = UDim2.new(1, -30, 1.1, -30)
		UIFX.tween(ui, {GroupTransparency = 0, Position = UDim2.new(1, -30, 1, -30)}, 'Out', 'Quart', 0.35)
	else
		-- check if it was just running
		if active then active = false end
		cleanup()
		
		UIFX.tween(ui, {GroupTransparency = 1, Position = UDim2.new(1, -30, 1.1, -30)}, 'In', 'Quart', 0.35)
		wait(0.35)
		if ui.GroupTransparency == 1 then ui.Visible = false end
	end
end

---------------------------------------------------------


-- listen for undos and make sure the script knows what got undone
CHS.OnUndo:Connect(function(waypoint)
	if waypoint == 'Wirespanner: Place Point' then
		task.wait() 
		cleanup()
	end
end)

-- main loop
mouse.Button1Down:Connect(function()
	if ui:GetAttribute('uiOpen') then
		if active and mouse.Target then
			
			local rec = CHS:TryBeginRecording('Wirespanner: Place Point')
			
			if conf.modelModeToggled then
				local topModel = FindTopmostModel(mouse.Target)
				if topModel then
					local validModel = findAttachmentsInModel(topModel)
					if validModel then
						modelCount = modelCount + 1
						if modelCount == 2 then
							connectModelAttachments()
							modelCount = 0
						end
					end
				end
				
			else
				
				placeAttachment()
				attCount = attCount + 1
				if attCount >= 2 then
					local attachmentSubTable = attachments[#attachments]
					placeRope(attachmentSubTable[#attachmentSubTable-1], attachmentSubTable[#attachmentSubTable])
				end
				
			end
			
			CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit)
			
		end
	end
end)

-- main start/stop button
UIFX.button(mainPage.toggleBtn, false).Event:Connect(function()
	if not active then
		if conf.modelModeToggled then
			modelCount = 0
		else
			attCount = 0
			attachments[#attachments+1] = {}
		end
		wires[#wires+1] = {}

		active = true
		mainPage.toggleBtn.stuff.text.Text = 'Finish This Wire'
		mainPage.toggleBtn.background.BackgroundColor3 = Color3.fromRGB(225, 132, 132)
	else
		active = false
		cleanup()
		mainPage.toggleBtn.stuff.text.Text = 'Start New Wire'
		mainPage.toggleBtn.background.BackgroundColor3 = Color3.fromRGB(255, 217, 155)
	end
end)

local selectionObj = nil
coroutine.wrap(function()
	while true do
		if active and conf.modelModeToggled then
			if not selectionObj then
				selectionObj = Instance.new('Highlight')
				
				selectionObj.Parent = workspace.Camera
				selectionObj.Name = indName
				selectionObj.FillColor = Color3.fromRGB(249, 191, 97)
				selectionObj.OutlineColor = Color3.fromRGB(249, 191, 97)
				selectionObj.FillTransparency = 0.7
				selectionObj.OutlineTransparency = 0
			end

			if mouse.Target then
				selectionObj.Adornee = FindTopmostModel(mouse.Target)
			else
				selectionObj.Adornee = nil
			end
		elseif selectionObj then
			selectionObj:Destroy()
			selectionObj = nil
		end
		
		task.wait()
	end
end)()

---------------------------------------------------------
---- OPTIONS

---- wire settings
-- color picker
UIFX.button(options.color.button, false).Event:Connect(function()
	ui.pages.UIPageLayout:JumpTo(colorPickerUI)
	local newColor = colorPicker.PromptPickColor(options.color.preview.BackgroundColor3)
	
	ui.pages.UIPageLayout:JumpTo(mainPage)
	wait(0.3)
	conf.wireColor = BrickColor.new(newColor)
	
	updateOptionsUI()
end)

-- width
UIFX.textBoxMustBeNum(options.width.num.box, 0)
options.width.num.box.FocusLost:Connect(function()
	task.wait()
	conf.wireWidth = options.width.num.box.Text
	updateOptionsUI()
end)

---- slack settings
-- slack toggle
UIFX.button(options.slackToggle.button, false).Event:Connect(function()
	conf.slackToggled = not conf.slackToggled
	if conf.slackToggled then switchToggleButton(options.slackToggle.button, true)
	else switchToggleButton(options.slackToggle.button, false)
	end
	updateOptionsUI()
end)

-- slack min and max
UIFX.textBoxMustBeNum(options.slackAmmount.min.box, 0)
UIFX.textBoxMustBeNum(options.slackAmmount.max.box, 0)
options.slackAmmount.min.box.FocusLost:Connect(function()
	task.wait()
	conf.slackMin = options.slackAmmount.min.box.Text
	updateOptionsUI()
end)
options.slackAmmount.max.box.FocusLost:Connect(function()
	task.wait()
	conf.slackMax = options.slackAmmount.max.box.Text
	updateOptionsUI()
end)

---- model settings
-- model mode toggle
UIFX.button(options.modelMode.button, false).Event:Connect(function()
	if not active then
		conf.modelModeToggled = not conf.modelModeToggled
		if conf.modelModeToggled then switchToggleButton(options.modelMode.button, true)
		else switchToggleButton(options.modelMode.button, false)
		end
		updateOptionsUI()
	end
end)

-- model slack mode types
UIFX.multiSelect(
	{options.modelSlackMode.frame.same, options.modelSlackMode.frame.random},
	false,
	false,
	'modelSlackRandomnessMode',
	script,
	options.modelSlackMode.frame.random
)
script:GetAttributeChangedSignal('modelSlackRandomnessMode'):Connect(function()
	conf.modelSlackMode = script:GetAttribute('modelSlackRandomnessMode')
	updateOptionsUI()
end)

---------------------------------------------------------
---- UI TOGGLES

-- close button
UIFX.button(ui.header.closeBtn, false).Event:Connect(function()
	toggleUI(false)
end)

-- listen for external state changes
ui:GetAttributeChangedSignal('uiOpen'):Connect(function()
	local state = ui:GetAttribute('uiOpen')
	toggleUI(state)
end)

---------------------------------------------------------
---- start

local coreUI = game:GetService("CoreGui")
local newUI = script.UI
if coreUI:FindFirstChild(ui.Name) then coreUI[ui.Name]:Destroy() end -- for development, if theres an old version still there
newUI.Name = ui.Name
newUI.Parent = coreUI
ui.header.title.Text = 'WIRESPANNER <font transparency="0.4">v'.._v..'</font>'
warn('ready')
