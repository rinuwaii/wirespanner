
local HTP = game:GetService('HttpService')

local PROM = require(script.Parent.Promise)

return {
	CheckForUpdate = function()
		return PROM.new(function(resolve, reject)
			local response, data
			pcall(function()
				response = HTP:GetAsync(
					'https://api.github.com/repos/rinyafii/wirespanner/releases/latest',
					false,
					{['X-GitHub-Api-Version'] = '2022-11-28', ['Accept'] = 'application/vnd.github+json'}
				)
				data = HTP:JSONDecode(response)
			end)

			if data then resolve(data) else reject() end
		end)
	end,
}