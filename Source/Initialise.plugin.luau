local Selection = game:GetService("Selection")
local Toolbar = require("./Plugin/Toolbar")

Toolbar.OnClick = function()
	local allSelected = Selection:Get()

	for _, v in allSelected do
		Selection:Set({v})
		plugin:PromptSaveSelectionAsync(v.Name)
	end

	Selection:Set(allSelected)
end