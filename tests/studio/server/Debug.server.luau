-- SOLO PARA PROBAR (no va en Palitos.rbxlx): manda todo lo que sale en Output (servidor y clientes) a http://127.0.0.1:8766
-- y acelera las batallas. Se arma con `rojo build test.project.json -o PruebaDebug.rbxlx`.
local HttpService = game:GetService("HttpService")
local LogService = game:GetService("LogService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CFG = require(ReplicatedStorage.Shared.Rules).CFG
CFG.countdown, CFG.roundTime, CFG.endTime, CFG.castleHp, CFG.respawn = 4, 90, 5, 500, 2

local queue = {}
local function log(who: string, msg: string, kind: string)
	table.insert(queue, ("[%s][%s] %s"):format(who, kind, msg))
end
LogService.MessageOut:Connect(function(msg, kind)
	log("SERVER", msg, kind.Name)
end)
local remote = Instance.new("RemoteEvent")
remote.Name = "DebugLog"
remote.Parent = ReplicatedStorage
remote.OnServerEvent:Connect(function(plr, msg, kind)
	log(plr.Name, tostring(msg), tostring(kind))
end)
log("SERVER", "debug listo", "Info")
while true do
	task.wait(1)
	if #queue > 0 then
		local body = table.concat(queue, "\n")
		table.clear(queue)
		pcall(HttpService.PostAsync, HttpService, "http://127.0.0.1:8766/", body, Enum.HttpContentType.TextPlain)
	end
end
