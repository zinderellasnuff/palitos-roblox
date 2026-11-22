-- SOLO PARA PROBAR: reenvía el Output de este cliente al servidor y juega solo (elige bando y clase, camina al castillo rival y usa todo).
local Players = game:GetService("Players")
local LogService = game:GetService("LogService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rules = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Rules"))
local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("DebugLog")
LogService.MessageOut:Connect(function(msg, kind)
	remote:FireServer(msg, kind.Name)
end)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
while not player:GetAttribute("Listo") do
	task.wait(0.2)
end
local n = tonumber(player.Name:match("%d+")) or 1
local team = if n % 2 == 1 then "azul" else "rojo"
Remotes.Elegir:FireServer(team, Rules.CLASS_ORDER[n % 3 + 1])
player.PlayerGui:WaitForChild("Palitos"):WaitForChild("Menu").Visible = false -- el bot elige sin tocar el menú
Remotes.Aviso.OnClientEvent:Connect(function(text)
	print("AVISO", text)
end)
workspace:GetAttributeChangedSignal("Estado"):Connect(function()
	print("estado →", workspace:GetAttribute("Estado"), "azul", workspace:GetAttribute("Hp_azul"), "rojo", workspace:GetAttribute("Hp_rojo"), "monedas", player:GetAttribute("Monedas"), "nivel", player:GetAttribute("Nivel"))
end)
player.CharacterAdded:Connect(function(char)
	print("aparece como", char:GetAttribute("Clase") or "?", "bando", player:GetAttribute("Bando"))
end)
local goal = Vector3.new(-Rules.side(team) * (Rules.CFG.castleX - 20), 3, 0)
local slot = 0
while true do
	task.wait(0.4)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if hum and root and hum.Health > 0 then
		hum:MoveTo(goal)
		slot = slot % 3 + 1
		local dir = (goal - root.Position) * Vector3.new(1, 0, 1)
		if dir.Magnitude > 1 then
			Remotes.Usar:FireServer(slot, dir.X, dir.Z)
		end
	end
end
