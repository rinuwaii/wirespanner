---------------------------------------------------------
--[[

	WIRESPANNER
	
	written by rinuwaii
	
	---------------------------------------
	
	CHANGELOG
	
	v0.2.0 -> Beta 2 (2-11-24) 
	- renamed normal mode to "pen mode"
	- renamed model mode to "span matching mode"
	- redid a lot of the pairing logic to support "span a/b mode"
		- span a/b is like span matching but instead of finding the exact same point in two models,
		  it finds <pointName>_A from model A and <pointName>_B from model B and connects them together.
			- BE CAREFUL!! always face and click on your models so that: 
				- the first model you click is your "A model" and the second is your "B model"
				- _A points in your A model are pointing toward your B model
				- _B points in your B model are pointing toward your A model
			(eventually ill add toggles to flip these around live, so its not as much of a hassle)
		
	- added hover indicators in pen mode
	- made wire tagging work
	- added a new option to disable retroactive changes
	- a lot of ui improvements
	  - mode switching is now at the top
	  - replaced the seperate slack toggle and mode options with a single switch button that changes between having two (off/on) and three (off/per wire/per span) options depending on mode
	  - made the ui draggable
	  - added a button on the topbar to collapse the window, leaving only the modes and toggle buttton
	  - added a button to reroll the random slack that gets added
	- added auto update checks, the plugin will the latest tag from github if it doesnt match the one it has it will prompt to update. 
	  the github request is only done once per session (on place load)
	
	----
	
	v0.1.0 -> Beta 1 (2-7-24) 
	- initial (beta) release to github and Cube Studios developers

]]
---------------------------------------------------------
---- VARS

local _vNum = '0.2.0'
local _vTxt = 'Beta 2'

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
local tools = require(script.req.nijiTools)
local pluginEvents = require(script.req.ModularPluginEvents)(ui, plugin)
local colorPicker = require(script.req.RinPickApi)
local draggableObject = require(script.req.DraggableObject)

-- internal globals
local randomGen = Random.new(tick())

-- stored stuff
local storedTargets = {}
local penAttachments = {}
local globalWires = {
	['pen'] = {},
	['span'] = {}
}

local hoverIndicator = nil

-- ui linked
local active = false
local collapsed = false
local mouse = plugin:GetMouse()

local indFolder, modeSelectorEvents, slackTypeEvents

local config = {
	currentMode		= 0, -- 0 = pen, 1 = span matching attachments, 2 = span _A to _B attachments
	updateAll		= true,
	wireColor		= BrickColor.new(Color3.new(0,0,0)),
	wireWidth		= 0.2,
	wireTags		= {},
	slackMode		= 0, -- 0 = off, 1 = on/per wire, 2 = per span
	slackMin		= 0.1,
	slackMax		= 0.2
}

local modes = {
	[0] = 'pen',
	[1] = 'spanMatching',
	[2] = 'spanAB'
}

---------------------------------------------------------
---- FUNCTIONS

------ MISC
local function ERR(typ:string, ...:string)
	local func
	if typ == 'w' then func = warn
	elseif typ == 'e' then func = error
	else func = print
	end
	for _,o in {...} do func('[Wirespanner] ',o) end
end

local function DeepUpdate(tab:{}, func:(rope:RopeConstraint, depth:number)->(), addDepth:number?)
	local curDepth = addDepth or -1; curDepth = curDepth + 1
	for k,v in tab do
		if type(v) == 'table' then DeepUpdate(k, func, curDepth)
		else func(v, curDepth)
		end
	end
end

local function SpinnyIcon(ico)
	local curRot = ico.Rotation
	local newRot = (curRot - math.fmod(curRot, 360)) + 540
	UIFX.tween(ico, {Rotation = newRot}, 'Out', 'Quart', 1.5)
end

local function GenSlack(nilIfNotPerSpan:boolean?)
	if nilIfNotPerSpan and config.slackMode ~= 2 then return nil end
	if config.slackMode == 0 then return 0 end
	return randomGen:NextNumber(config.slackMin, config.slackMax)
end

local function NewSubtable(tab:{})
	tab[#tab+1] = {}
	return tab[#tab]
end

-- make attachment highlight
local function MakePointHighlight(name:string, color:Color3)
	local selectionObj = Instance.new('Part')
	selectionObj.Name = name
	selectionObj.Color = color
	selectionObj.Material = Enum.Material.Neon
	selectionObj.Transparency = 0.8
	selectionObj.Archivable = false
	selectionObj.Size = Vector3.new(0.5,0.5,0.5)
	selectionObj.Locked = true
	selectionObj.Shape = Enum.PartType.Ball
	selectionObj.Parent = indFolder
	return selectionObj
end

-- make model highlight
local function MakeModelHighlight(name:string, color:Color3)
	local selectionObj = Instance.new('Highlight')
	selectionObj.Name = name
	selectionObj.FillColor = color
	selectionObj.OutlineColor = color
	selectionObj.FillTransparency = 0.6
	selectionObj.OutlineTransparency = 0
	selectionObj.Archivable = false
	selectionObj.Parent = indFolder
	return selectionObj
end

------ STUFF FOR PLACING/FINDING POINTS
-- function for setting wire properties, outside NewRope() so UpdateOptions() can also use the same stuff
local function SetWireProperties(w:RopeConstraint, slack:number)
	w.Color = config.wireColor
	w.Thickness = config.wireWidth
	w.Length =  w.CurrentDistance + slack

	for _,o in pairs(w:GetTags()) do
		w:RemoveTag(o)
	end

	if #config.wireTags > 0 then 
		for _,o in pairs(config.wireTags) do
			w:AddTag(o)
		end
	end
end

-- universal place rope, all modes use this
local function NewRope(v, o, tableToAdd, slackLength)
	local new = Instance.new('RopeConstraint')
	new.Name = 'wirespannerRope'
	new.Parent = v.Parent
	new.Attachment0 = v
	new.Attachment1 = o
	new.Visible = true
	
	SetWireProperties(new, slackLength)

	local newIndex = #tableToAdd or 0
	tableToAdd[newIndex+1] = new
	return new
end

-- pen mode
local function PlaceAttachmentPoint(parent, pos)
	local newAtt = Instance.new('Attachment')
	newAtt.Parent = parent
	newAtt.WorldPosition = pos
	table.insert(penAttachments[#penAttachments], newAtt)
	return newAtt
end

-- generic tests for span mode
local function CheckIfValidModel(model:Model)
	local foundAttachments = {}
	
	if model == nil then return nil end
	
	for _,o in pairs(model:GetDescendants()) do
		
		--- basic checks: class, not the default name, not duplicate name
		if o:IsA("Attachment") and o.Name ~= 'Attachment' and model:FindFirstChild(o.Name, true) ~= nil then
					
			-- if we're in span A/B mode and the name is even long enough, check for matching pairs
			if config.currentMode == 2 then
				if #o.Name > 2 then
					
					local alreadyFoundPair = false
					for i, v in pairs(foundAttachments) do
						if tools.dictionary.find(v, o) then
							alreadyFoundPair = true
						end
					end

					if not alreadyFoundPair then

						local attName = string.sub(o.Name, #(o.Name)-1)
						if string.upper(attName) == '_A' then
							local foundModel = tools.CaseIndependentFindFirstChild(model, string.gsub(string.lower(o.Name), '_a', '_b'), true)
							if foundModel then
								if model:FindFirstChild(foundModel.Name, true) ~= nil then
									table.insert(foundAttachments, {['name']=string.upper(o.Name), ['att']=o})
									table.insert(foundAttachments, {['name']=string.upper(foundModel.Name), ['att']=foundModel})
								end
							end

						elseif string.upper(attName) == '_B' then
							local foundModel = tools.CaseIndependentFindFirstChild(model, string.gsub(string.lower(o.Name), '_b', '_a'), true)
							if foundModel then
								if model:FindFirstChild(foundModel.Name, true) ~= nil then
									table.insert(foundAttachments, {['name']=string.upper(foundModel.Name), ['att']=foundModel})
									table.insert(foundAttachments, {['name']=string.upper(o.Name), ['att']=o})
								end
							end
						end
					end
				end
			else
				table.insert(foundAttachments, {['name']=string.upper(o.Name), ['att']=o})
			end
		end
	end
	
	if #foundAttachments > 0 then return foundAttachments else return nil end
end

-- pair together models in span modes
local function SpanModels(targets)
	
	local modelA = targets[1]
	local modelB = targets[2]
	
	local matches = {}
	
	-- check for matching pairs of attachments and remove matches from copied table
	for i, v in pairs(modelA['attachments']) do
		local nodeToFind
		if config.currentMode == 1 then nodeToFind = v['name'] else
			--TODO: add swap a/b b/a here sometime
			nodeToFind = string.gsub(v['name'], '_A', '_B')
		end

		local foundNode = nil
		for i2, o in pairs(modelB['attachments']) do
			if tools.dictionary.find(o, nodeToFind) then
				foundNode = i2
			end
		end

		if foundNode then
			matches[#matches+1] = {modelA['attachments'][i], modelB['attachments'][foundNode]}
			modelA['attachments'][i] = nil
			modelB['attachments'][foundNode] = nil
		end
	end
	
	-- make new table for span group
	local sessionTab 		= globalWires['span']
	local currentSessionTab = sessionTab[#sessionTab]
	local currentGroupTab = currentSessionTab[#currentSessionTab]
	if currentGroupTab == nil or currentGroupTab ~= {} then currentGroupTab = NewSubtable(currentSessionTab) end
	
	-- connect matches
	local slackPerSpanRandom = GenSlack(true)
	for _,v in matches do
		local slackRandom = slackPerSpanRandom or GenSlack()
		NewRope(v[1]['att'], v[2]['att'], currentGroupTab, slackRandom)
	end
	
	for _,o in pairs(indFolder:GetChildren()) do o:Destroy() end
	hoverIndicator = nil
	storedTargets = {}
end

------- CLEANUP
-- clean out unused/removed instances and empty tables from the session tables
local function CleanTables(tab:{})
	for k, v in pairs(tab) do
		if typeof(v) == "table" then
			if v == {} or v == nil or #v == 0 then table.remove(v, k)
			else v = CleanTables(v)
			end
		elseif typeof(v) == 'Instance' then
			if v:IsA('Attachment') then
				if v.Parent == nil then table.remove(tab, k) end
			elseif v:IsA('RopeConstraint') then
				if v.Parent == nil or v.Attachment0 == nil or v.Attachment1 == nil then table.remove(tab, k) end
			end
		end
	end
	return tab
end

-- wrap
local function Cleanup()
	penAttachments = CleanTables(penAttachments)
	globalWires['span'] = CleanTables(globalWires['span'])
	globalWires['pen'] = CleanTables(globalWires['pen'])
	for i, o in ipairs(penAttachments) do
		if #o == 1 then o[1]:Destroy(); penAttachments = CleanTables(penAttachments) end
	end
	for _,o in pairs(indFolder:GetChildren()) do o:Destroy() end
	hoverIndicator = nil
	storedTargets = {}
end

------ UI & options

-- update the ui and wires in session whenever an option gets changed
local function UpdateOptions()
	
	---- check to see new state and upate the ui as needed
	-- if you're in pen mode then the per-span option wont be shown
	-- this requires re-aligning the buttons and hiding all the extra frames i added to get the fancy corners
	local hideSlackPerSpan
	if config.currentMode == 0 then
		hideSlackPerSpan = false
		options.slackType.on.stuff.text.Text = 'On'
		options.slackType.on.stuff.ImageLabel.Image = 'rbxassetid://16301644189'
		options.slackType.off.stuff.ImageLabel.Image = 'rbxassetid://16301644412'
		options.slackType.off.Size = UDim2.new(0.4, 0 ,0, 25)
		
		if config.slackMode == 2 then slackTypeEvents.reset() end
	else
		hideSlackPerSpan = true
		options.slackType.on.stuff.text.Text = 'Per Wire'
		options.slackType.on.stuff.ImageLabel.Image = 'rbxassetid://16301644739'
		options.slackType.off.stuff.ImageLabel.Image = 'rbxassetid://16301644930'
		options.slackType.off.Size = UDim2.new(1, 0 ,0, 25)
	end
	
	options.slackType.perSpan.Visible = hideSlackPerSpan
	options.slackType.onHeader.Visible = hideSlackPerSpan
	for _,o in pairs(options.slackType.on.background:GetChildren()) do
		if o:IsA('Frame') and o:GetAttribute('hide') then o.Visible = hideSlackPerSpan end
	end
	
	-- turning off slack will hide the min/max input
	if config.slackMode == 0 then
		options.slackAmmount.Visible = false
		options.slackAmmountDesc.Visible = false
	else
		options.slackAmmount.Visible = true
		options.slackAmmountDesc.Visible = true
	end
	
	-- update color	
	options.wireColor.stuff.preview.BackgroundColor3 = config.wireColor.Color
	options.wireColor.stuff.preview.nocorner.BackgroundColor3 = config.wireColor.Color
	
	---- live wire config updates
	if active and config.updateAll then
		if config.currentMode == 0 then
			local index = globalWires['pen']
			for i, v in ipairs(globalWires['pen'][#index]) do
				SetWireProperties(v, GenSlack())

			end
		else
			local index = globalWires['span']
			for i, v in ipairs(globalWires['span'][#index]) do
				
				local slackPerSpanRandom = GenSlack(true)
				
				for i2, v2 in pairs(v) do
					local slackRandom = slackPerSpanRandom or GenSlack()
					SetWireProperties(v2, slackRandom)
					
				end
			end
		end
	end
end

-- main func for opening/closing ui
local function ToggleUI(state)
	if state then
		plugin:Activate(false)
		
		if collapsed then
			ui.Size = UDim2.new(0,300,0,525)
			ui.header.collapseBtn.stuff.settings.ImageTransparency = 1
			ui.header.collapseBtn.stuff.arrow.ImageTransparency = 1
			collapsed = false
		end
		
		indFolder = Instance.new('Folder')
		indFolder.Name = 'wirespannerIndicators_'..tostring(STS:GetUserId())
		indFolder.Parent = workspace.Camera
		mouse.TargetFilter = indFolder
		
		ui.Visible = true
		ui.Position = UDim2.new(1, -30, 1, 60)
		UIFX.tween(ui, {GroupTransparency = 0, Position = UDim2.new(1, -30, 1, -30)}, 'Out', 'Quart', 0.35)
	else
		-- check if it was just running
		if active then active = false end
		Cleanup()
		
		local newPos = UDim2.new(0, ui.AbsolutePosition.X+ui.AbsoluteSize.X, 0, ui.AbsolutePosition.Y+ui.AbsoluteSize.Y+60)
		UIFX.tween(ui, {GroupTransparency = 1, Position = newPos}, 'In', 'Quart', 0.35)
		wait(0.35)
		if ui.GroupTransparency == 1 then ui.Visible = false end
		
		indFolder:Destroy()
		plugin:Deactivate()
	end
end

---------------------------------------------------------
---- MAIN EVENTS

-- listen for undos and make sure the script knows what got undone
CHS.OnUndo:Connect(function(waypoint)
	if waypoint == 'Wirespanner: Place Point' then
		task.wait() 
		Cleanup()
	end
end)

-- on click
mouse.Button1Down:Connect(function()
	if ui:GetAttribute('uiOpen') and active and mouse.Target then
		
		local target = mouse.Target
		local hit = mouse.Hit
		local rec = CHS:TryBeginRecording('Wirespanner: Place Point')
			
		if config.currentMode == 0 then	
			local attachmentSubTable = penAttachments[#penAttachments]
			
			PlaceAttachmentPoint(target, hit.p)
			if #attachmentSubTable >= 1 then
				local newSelect = MakePointHighlight('penPoint'..tostring(#attachmentSubTable), Color3.fromRGB(170, 101, 249))
				newSelect:PivotTo(mouse.Hit)
			end
			
			if #attachmentSubTable >= 2 then
				local wireTable = globalWires['pen'][#globalWires['pen']]
				NewRope(attachmentSubTable[#attachmentSubTable-1], attachmentSubTable[#attachmentSubTable], wireTable, GenSlack())
			end
			
		else
			local modelOfTarget = tools.FindTopmostModel(target)
			local validAttachments = CheckIfValidModel(modelOfTarget) --both funcs support nil arguments
			if validAttachments then
				storedTargets[#storedTargets+1] = {['model']=modelOfTarget, ['attachments']=validAttachments}
				if #storedTargets == 1 then
					local newSelect = MakeModelHighlight('firstModelSelected', Color3.fromRGB(170, 101, 249))
					newSelect.Adornee = modelOfTarget
				elseif #storedTargets == 2 then
					SpanModels(storedTargets)
				end
			end
		end
		
		CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit)
		
	end	
end)

-- indicator
coroutine.wrap(function()
	while true do
		
		if active then
			if config.currentMode == 0 then
				if not hoverIndicator then hoverIndicator = MakePointHighlight('modelHover', Color3.fromRGB(249, 191, 97)) end
				if mouse.Target then
					hoverIndicator:PivotTo(mouse.Hit)
				else
					hoverIndicator:PivotTo(CFrame.new(0,-20,0)) --sure idk
				end
				
			elseif config.currentMode >= 1 then
				if not hoverIndicator then hoverIndicator = MakeModelHighlight('modelHover', Color3.fromRGB(249, 191, 97)) end
				if mouse.Target then
					local model = tools.FindTopmostModel(mouse.Target)
					local validModel = CheckIfValidModel(model)
					if model and model:FindFirstChildOfClass('Highlight') then
						hoverIndicator.Adornee = nil
					else
						if validModel then
							hoverIndicator.Adornee = model
							hoverIndicator.FillColor = Color3.fromRGB(122, 249, 97)
							hoverIndicator.OutlineColor = Color3.fromRGB(122, 249, 97)
						else
							hoverIndicator.Adornee = model
							hoverIndicator.FillColor = Color3.fromRGB(249, 191, 97)
							hoverIndicator.OutlineColor = Color3.fromRGB(249, 191, 97)
						end
					end
				else
					hoverIndicator.Adornee = nil
				end
			end
			
		elseif hoverIndicator then
			hoverIndicator:Destroy()
			hoverIndicator = nil
		end

		task.wait()
	end
end)()

-- main start/stop button
UIFX.button(mainPage.toggleFrame.toggleBtn, false).Event:Connect(function()
	if not active then
		
		-- add new/reset session tables
		if config.currentMode == 0 then
			NewSubtable(penAttachments)
			NewSubtable(globalWires['pen'])
		else
			NewSubtable(globalWires['span'])
		end
		storedTargets = {}

		active = true
		mainPage.toggleFrame.toggleBtn.stuff.text.Text = 'Finish This Wire'
		mainPage.toggleFrame.toggleBtn.background.BackgroundColor3 = Color3.fromRGB(225, 132, 132)
	else
		active = false
		Cleanup()
		mainPage.toggleFrame.toggleBtn.stuff.text.Text = 'Start New Wire'
		mainPage.toggleFrame.toggleBtn.background.BackgroundColor3 = Color3.fromRGB(255, 217, 155)
	end
end)

---------------------------------------------------------
---- OPTIONS

-- mode selector
modeSelectorEvents = UIFX.multiSelect(
	{mainPage.modeSelect.pen, mainPage.modeSelect.spanMatching, mainPage.modeSelect.spanAB},
	true, true, 'currentMode', script, mainPage.modeSelect.pen)
script:GetAttributeChangedSignal('currentMode'):Connect(function()
	
	local new = script:GetAttribute('currentMode')
	
	if active then
		
		ERR('w','[Wirespanner] Finish your wire before chaning modes!')
		
		if modes[new] ~= config.currentMode then
			modeSelectorEvents.force(mainPage.modeSelect[modes[config.currentMode]])
		end
		
		coroutine.wrap(function()
			UIFX.tween(mainPage.modeSelect, {BackgroundColor3 = Color3.fromRGB(139, 73, 74)}, 'In', 'Quart', 0.1)
			wait(0.1)
			UIFX.tween(mainPage.toggleFrame, {BackgroundColor3 = Color3.fromRGB(139, 73, 74)}, 'In', 'Quart', 0.1)
			UIFX.tween(mainPage.modeSelect, {BackgroundColor3 = Color3.fromRGB(45, 40, 33)}, 'Out', 'Quart', 1.5)
			wait(0.1)
			UIFX.tween(mainPage.toggleFrame, {BackgroundColor3 = Color3.fromRGB(45, 40, 33)}, 'Out', 'Quart', 1.5)
		end)()
		
	else
		if modes[new] ~= config.currentMode then
			config.currentMode = tools.dictionary.find(modes, new)
			UpdateOptions()
		end
	end
end)

-- slack types 
slackTypeEvents = UIFX.multiSelect(
	{options.slackType.off, options.slackType.on, options.slackType.perSpan},
	true,
	true,
	'slackMode',
	script,
	options.slackType.off)
script:GetAttributeChangedSignal('slackMode'):Connect(function()
	local new = script:GetAttribute('slackMode')
	if new == 'off' and config.slackMode ~= 0 then
		config.slackMode = 0
		UpdateOptions()
	elseif new == 'on' and config.slackMode ~= 1 then
		config.slackMode = 1
		UpdateOptions()
	elseif new == 'perSpan' and config.slackMode ~= 2 then
		config.slackMode = 2
		UpdateOptions()
	end
end)

UIFX.button(options.genUpdateAllInSpan.button, false).Event:Connect(function()
	local button = options.genUpdateAllInSpan.button
	config.updateAll = not config.updateAll
	
	if config.updateAll then
		UIFX.tween(button.background, {BackgroundColor3 = Color3.fromRGB(141, 208, 94)}, 'InOut', 'Quint', 0.2)
		button.stuff.text.Text = 'On'
	else
		UIFX.tween(button.background, {BackgroundColor3 = Color3.fromRGB(223, 101, 101)}, 'InOut', 'Quint', 0.2)
		button.stuff.text.Text = 'Off'
	end
end)

-- color picker
UIFX.button(options.wireColor.stuff.button, true).Event:Connect(function()
	ui.pages.UIPageLayout:JumpTo(colorPickerUI)
	local newColor = colorPicker.PromptPickColor(options.wireColor.stuff.preview.BackgroundColor3)
	ui.pages.UIPageLayout:JumpTo(mainPage)
	wait(0.3)
	
	local new = BrickColor.new(newColor)
	if new ~= config.wireColor then
		config.wireColor = new
		UpdateOptions()
	end
end)

-- width
UIFX.textBoxMustBeNum(options.wireWidth.num.box, 0)
options.wireWidth.num.box.FocusLost:Connect(function()
	task.wait()
	local new = tonumber(options.wireWidth.num.box.Text)
	if new ~= config.wireWidth then
		config.wireWidth = new
		UpdateOptions()
	end
end)

options.wireTag.num.box.FocusLost:Connect(function()
	local new = options.wireTag.num.box.Text

	new = new:gsub('^%s+','') -- remove space at the start of strings
	new = new:gsub('$%s+','') -- remove space at the end of strings
	new = new:gsub(',%s+',',') -- remove space at the start of commas
	new = new:gsub('%s+,',',') -- remove space at the end of commas

	local tab = new:split(',') -- convert to table

	for i,o in ipairs(tab) do -- check for empty table entries (input as ",,")
		if o == '' then table.remove(tab, i) end
	end

	local cleanedStr = table.concat(tab, ', ') -- make a new string to set as the text in the box
	config.wireTags = tab
	options.wireTag.num.box.Text = cleanedStr
	
	UpdateOptions()
end)

-- slack min and max
UIFX.textBoxMustBeNum(options.slackAmmount.stuff.min.box, 0)
UIFX.textBoxMustBeNum(options.slackAmmount.stuff.max.box, 0)
options.slackAmmount.stuff.min.box.FocusLost:Connect(function()
	task.wait()
	local new = tonumber(options.slackAmmount.stuff.min.box.Text)
	if new ~= config.slackMin then
		config.slackMin = new
		
		if new > config.slackMax then 
			options.slackAmmount.stuff.max.box.Text = new
			config.slackMax = new
		end
		
		UpdateOptions()
	end
end)
options.slackAmmount.stuff.max.box.FocusLost:Connect(function()
	task.wait()
	local new = tonumber(options.slackAmmount.stuff.max.box.Text)
	if new ~= config.slackMax then
		config.slackMax = new

		if new < config.slackMin then 
			options.slackAmmount.stuff.min.box.Text = new
			config.slackMin = new
		end

		UpdateOptions()
	end
end)

-- reroll random nums
UIFX.button(options.slackAmmount.stuff.rerollBtn, true).Event:Connect(function()
	UpdateOptions()
	SpinnyIcon(options.slackAmmount.stuff.rerollBtn.stuff.ImageLabel)
end)

-- hehe spinny icon go weeee
options.slackAmmount.stuff.rerollBtn.MouseEnter:Connect(function() SpinnyIcon(options.slackAmmount.stuff.rerollBtn.stuff.ImageLabel) end)

---------------------------------------------------------
---- UI TOGGLES

-- close button
UIFX.button(ui.header.closeBtn, false).Event:Connect(function()
	ToggleUI(false)
end)

-- collapse button
UIFX.button(ui.header.collapseBtn, false).Event:Connect(function()
	collapsed = not collapsed
	
	local alsoMove = false; if ui.Position == UDim2.new(1, -30, 1, -30) or ui.Position == UDim2.new(1, -10, 1, -10) then alsoMove = true end
	if collapsed then
		if alsoMove then UIFX.tween(ui, {Position = UDim2.new(1,-10,1,-10)}, 'InOut', 'Quint', 0.35) end
		UIFX.tween(ui, {Size = UDim2.new(0,300,0,180)}, 'InOut', 'Quint', 0.35)
		
		UIFX.tween(ui.header.collapseBtn.stuff.arrow, {ImageTransparency = 1}, 'InOut', 'Quint', 0.35)
		UIFX.tween(ui.header.collapseBtn.stuff.settings, {ImageTransparency = 0}, 'InOut', 'Quint', 0.35)
		SpinnyIcon(options.slackAmmount.stuff.rerollBtn.stuff.ImageLabel)
		
	else
		if alsoMove then UIFX.tween(ui, {Position = UDim2.new(1,-30,1,-30)}, 'InOut', 'Quint', 0.35) end
		UIFX.tween(ui, {Size = UDim2.new(0,300,0,525)}, 'InOut', 'Quint', 0.35)
		
		UIFX.tween(ui.header.collapseBtn.stuff.settings, {ImageTransparency = 1}, 'InOut', 'Quint', 0.35)
		UIFX.tween(ui.header.collapseBtn.stuff.arrow, {ImageTransparency = 0}, 'InOut', 'Quint', 0.35)
	end
	
	task.wait(0.35)
	if ui.AbsolutePosition.Y < 0 then
		local newPos = UDim2.new(0, ui.AbsoluteSize.X+ui.AbsolutePosition.X, 0, ui.AbsoluteSize.Y+20)
		UIFX.tween(ui, {Position = newPos}, 'InOut', 'Quint', 0.25)

	elseif workspace.Camera.ViewportSize.Y < ui.AbsolutePosition.Y then
		local newPos = UDim2.new(0, ui.AbsoluteSize.X+ui.AbsolutePosition.X, 0, workspace.Camera.ViewportSize.Y-20)
		UIFX.tween(ui, {Position = newPos}, 'InOut', 'Quint', 0.25)

	end
end)

-- extra thing bc its fun: spin settings icon on hover :3
ui.header.collapseBtn.MouseEnter:Connect(function() SpinnyIcon(ui.header.collapseBtn.stuff.settings) end)

-- listen for external state changes
ui:GetAttributeChangedSignal('uiOpen'):Connect(function()
	local state = ui:GetAttribute('uiOpen')
	ToggleUI(state)
end)

---------------------------------------------------------
---- start

-- start out at main page
ui.pages.UIPageLayout:JumpTo(mainPage)

-- check if ran before
local firstRun = plugin:GetSetting('firstRun')
if firstRun == nil then
	local page = ui.pages.updaterConfirm
	
	local okConn
	okConn = UIFX.button(page.okBtn, false).Event:Connect(function()
		ui.pages.UIPageLayout:JumpTo(mainPage)
		plugin:SetSetting('firstRun', false)
		
		require(script.req.UpdateChecker).CheckForUpdate():andThen(function()
			--dont do aanything here but still run the check so they get the prompt
		end)
		
		okConn:Disconnect()
	end)
	
	ui.pages.UIPageLayout:JumpTo(page)
end
	
-- check for update
if firstRun == false then
	require(script.req.UpdateChecker).CheckForUpdate()
	:andThen(function(response)
		local latestVer = response['tag_name']

		if _vNum == latestVer then
			--ERR('w','[Version check] Up to date!')
		else
			local page = ui.pages.newUpdate
			
			page.ver.Text = 'v'..latestVer
			
			local okConn
			okConn = UIFX.button(page.okBtn, false).Event:Connect(function()
				ui.pages.UIPageLayout:JumpTo(mainPage)
				okConn:Disconnect()
			end)
			
			ui.pages.UIPageLayout:JumpTo(page)
			
			--ERR('w','[Version check] New version available! (v'..latestVer..') ')
		end
	end)
	:catch(function(uhoh)
		ERR('w','[Version check] failed to get update info. You can manually check via the GitHub (rinuwaii/wirespanner)',uhoh)
	end)
end

-- place ui in core ui & start
local coreUI = game:GetService("CoreGui")
local newUI = script.UI
if coreUI:FindFirstChild(ui.Name) then coreUI[ui.Name]:Destroy() end -- for development, if theres an old version still there
newUI.Name = ui.Name
newUI.Parent = coreUI


local drag = draggableObject.new(ui.header)
drag:Enable()
ui.header.title.Text = 'WIRESPANNER <font size="16" transparency="0.4">'.._vTxt..'</font>'
UpdateOptions() -- reset to default
