--[=[
MIT License

Copyright (c) 2022 JohnnyMorganz

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
]=]

--[=[
	Lune script to execute Luau tasks using OpenCloud within a Roblox engine.
	This script can execute any task within the environment, such as publishing the plugin.

	Steps for usage:
		1) `rojo build test.project.json --output plugin_place.rbxl`
		2) `ROBLOX_API_KEY=xxxx lune run publish_plugin.luau plugin_place.rbxl <cloud_task_file>`

	test.project.json will build a full place file with the plugin stored in ReplicatedStorage
	at game.ReplicatedStorage.Plugin. The cloud task file can then reference this Instance for
	necessary tasks

	For publishing, see `publishing_task.luau` which will publish the plugin to Roblox
]=]

local fs = require("@lune/fs")
local net = require("@lune/net")
local process = require("@lune/process")
local task = require("@lune/task")

local ROBLOX_API_KEY = assert(process.env.ROBLOX_API_KEY, "Missing ENV variable: ROBLOX_API_KEY")
local UNIVERSE_ID = 4059912034
local PLACE_ID = 11411951000

assert(#process.args == 2, "Usage: lune run publish_plugin.luau PLACE_FILE CLOUD_TASK_FILE")
local PLACE_FILE = process.args[1]
local CLOUD_TASK_FILE = process.args[2]

print(`Attempting to execute {CLOUD_TASK_FILE}`)

local SCRIPT_CONTENTS = fs.readFile(CLOUD_TASK_FILE)

print("=== SCRIPT CONTENTS ===")
print(SCRIPT_CONTENTS)
print("=== END ===")

type LuauTask = {
	path: string,
	createTime: string,
	updateTime: string,
	user: string,
	state: "STATE_UNSPECIFIED" | "QUEUED" | "PROCESSING" | "CANCELLED" | "COMPLETE" | "FAILED",
	script: string,
}

local function uploadPlaceFile(universeId: number, placeId: number, placeFile: string): number
	print("Uploading place file...")
	local response = net.request({
		method = "POST",
		url = `https://apis.roblox.com/universes/v1/{universeId}/places/{placeId}/versions?versionType=Saved`,
		headers = {
			["Content-Type"] = "application/xml",
			["Accept"] = "application/json",
			["X-API-Key"] = ROBLOX_API_KEY,
		},
		body = fs.readFile(placeFile),
	})

	if response.ok then
		print("Place file upload succeeded", response.body)
		return net.jsonDecode(response.body)["versionNumber"]
	else
		error(`uploadPlaceFile failed: {response.statusCode} - {response.statusMessage}: {response.body}`)
	end
end

local function createTask(universeId: number, placeId: number, placeVersion: number, scriptContents: string): LuauTask
	local response = net.request({
		method = "POST",
		url = `https://apis.roblox.com/cloud/v2/universes/{universeId}/places/{placeId}/versions/{placeVersion}/luau-execution-session-tasks`,
		headers = {
			["Content-Type"] = "application/json",
			["X-API-Key"] = ROBLOX_API_KEY,
		},
		body = net.jsonEncode({
			script = scriptContents,
		}),
	})

	if not response.ok then
		error(`Create task request failed: {response.body}`)
	end

	return net.jsonDecode(response.body)
end

local function pollForTaskCompletion(taskPath: string)
	print("Polling for task status...")

	while true do
		local response = net.request({
			method = "GET",
			url = `https://apis.roblox.com/cloud/v2/{taskPath}`,
			headers = {
				["X-API-Key"] = ROBLOX_API_KEY,
			},
		})

		if not response.ok then
			error(`Poll task completion failed: {response.body}`)
		end

		local cloudTask = net.jsonDecode(response.body)
		if cloudTask.state ~= "PROCESSING" then
			return cloudTask
		else
			print(".")
			task.wait(3)
		end
	end
end

local function getTaskLogs(taskPath: string)
	local response = net.request({
		method = "GET",
		url = `https://apis.roblox.com/cloud/v2/{taskPath}/logs`,
		headers = {
			["X-API-Key"] = ROBLOX_API_KEY,
		},
	})

	if not response.ok then
		error(`Get task logs failed: {response.body}`)
	end

	return table.concat(net.jsonDecode(response.body).luauExecutionSessionTaskLogs[1].messages, "\n")
end

local function runLuauTask(universeId: number, placeId: number, placeVersion: number, scriptContents: string)
	print("Executing Luau task...")

	local cloudTask = createTask(universeId, placeId, placeVersion, scriptContents)
	cloudTask = pollForTaskCompletion(cloudTask.path)
	local logs = getTaskLogs(cloudTask.path)

	print(logs)
	print(cloudTask)

	if cloudTask.state == "COMPLETE" then
		print("Luau task completed successfully")
	else
		error("Luau task failed")
	end
end

local placeVersion = uploadPlaceFile(UNIVERSE_ID, PLACE_ID, PLACE_FILE)
runLuauTask(UNIVERSE_ID, PLACE_ID, placeVersion, SCRIPT_CONTENTS)