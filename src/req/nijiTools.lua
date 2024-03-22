--[[

	niji.tools
	an offshoot of the kaga.uifx project but for non-ui tools

	v1.0

]]--[[

	written by @rinuwaii (fiteuwu on roblox for now)
	for use only by rin (rinuwaii) herself, Cube Studios, and explicity permitted people
	
	read more in kagaUIFX
	
]]

local m = {['dictionary']={}}


m.DeepCopyTable = function(tab:{})
	local copy = {}
	for k, v in pairs(tab) do
		if type(v) == "table" then v = m.DeepCopyTable(v) end
			copy[k] = v
		end
	return copy
end

m.dictionary.find = function(dict:{[string]:any}, value:any)
		for k, v in pairs(dict) do
			if v == value then
				return k
			end
		end
	end

m.CombineTables = function (...:{})
	local Output = {}
	local i = 1
	for x, list in ipairs({...}) do
		for y, item in ipairs(list) do
			table.insert(Output, i, item)
			i = i + 1
		end
	end
	return Output
end

m.CaseIndependentFindFirstChild = function(instance:Instance, name:string, descendantMode:boolean?)
	local search = not descendantMode and instance:GetChildren() or instance:GetDescendants()

	for _, descendant in ipairs(search) do
		if descendant.Name:lower() == name:lower() then return descendant end
	end
	return nil
end

m.FindTopmostModel = function(part, includeParts:boolean?)
	local foundModel = nil
	if part == nil then return nil end
	if part:IsA('Model') or part:IsA('BasePart') then
		if part.Parent == workspace then
			if part:IsA('Model') then foundModel = part
			elseif part:IsA('BasePart') then
				if includeParts then foundModel = part
				else
					local partDesendantsThatAreModels = part:FindFirstChildOfClass('Model', true) -- start looking the other direction i guess lol, i dont know why a model would be under a part but idk blocky would do something like that
					if partDesendantsThatAreModels then foundModel = partDesendantsThatAreModels end -- if nil then this is (probably) a part with no models
				end
			end
		else 
			foundModel = m.FindTopmostModel(part.Parent)
		end
	end
	return foundModel
end

return m