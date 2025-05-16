local GetPlugin = require("../Lib/GetPlugin")

local plugin = GetPlugin

local module = {}

local toolbar = plugin:CreateToolbar("Bulk Save")
local button = toolbar:CreateButton("Save", "Invidividually saves selected Instances", "rbxassetid://94073691148866")
button.ClickableWhenViewportHidden = true

module.Toolbar = toolbar
module.Button = button
module.OnClick = nil :: () -> ()?

button.Click:Connect(function()
	if module.OnClick then
		module.OnClick()
	end
end)

return module