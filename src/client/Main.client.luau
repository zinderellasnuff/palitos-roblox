-- Cliente de Palitos: menú de bando y clase, marcador, botones de habilidades, trazos de los ataques y piernas de los soldados.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")
local Rules = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Rules"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local player = Players.LocalPlayer
local mouse = player:GetMouse()

local INK = { azul = Color3.fromRGB(35, 75, 205), rojo = Color3.fromRGB(215, 45, 45), cura = Color3.fromRGB(60, 190, 90) }
local PAPER = Color3.fromRGB(250, 248, 240)
local DARK = Color3.fromRGB(40, 40, 50)
local NAMES = { azul = "AZUL", rojo = "ROJO" }
local KEYS = { "Clic", "Q", "E" }

local function mk(class: string, props: { [string]: any }, parent: Instance?): any
	local o = Instance.new(class)
	if o:IsA("TextLabel") or o:IsA("TextButton") then
		o.Font = Enum.Font.PatrickHand
		o.TextScaled = true
		o.TextColor3 = DARK
		o.BackgroundColor3 = PAPER
	end
	if o:IsA("GuiObject") then
		o.BorderSizePixel = 0
	end
	for k, v in props do
		(o :: any)[k] = v
	end
	o.Parent = parent
	return o
end
local function round(o: Instance, ink: Color3?)
	mk("UICorner", { CornerRadius = UDim.new(0, 10) }, o)
	mk("UIStroke", { Thickness = 3, Color = ink or DARK, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, o)
end

local gui = mk("ScreenGui", { Name = "Palitos", ResetOnSpawn = false, IgnoreGuiInset = true }, player:WaitForChild("PlayerGui"))

-- Marcador: vida de los dos castillos y el reloj
local top = mk("Frame", { Size = UDim2.fromScale(0.5, 0.06), Position = UDim2.fromScale(0.25, 0.02), BackgroundTransparency = 1 }, gui)
local bars = {}
for i, team in { "azul", "rojo" } do
	local back = mk("Frame", { Size = UDim2.fromScale(0.4, 0.6), Position = UDim2.fromScale(if i == 1 then 0 else 0.6, 0.2), BackgroundColor3 = PAPER }, top)
	round(back, INK[team])
	bars[team] = mk("Frame", { Size = UDim2.fromScale(1, 1), AnchorPoint = Vector2.new(i - 1, 0), Position = UDim2.fromScale(i - 1, 0), BackgroundColor3 = INK[team] }, back)
	mk("UICorner", { CornerRadius = UDim.new(0, 10) }, bars[team])
end
local clock = mk("TextLabel", { Size = UDim2.fromScale(0.2, 1), Position = UDim2.fromScale(0.4, 0), BackgroundTransparency = 1, Text = "" }, top)
local banner = mk("TextLabel", { Size = UDim2.fromScale(0.6, 0.1), Position = UDim2.fromScale(0.2, 0.1), BackgroundTransparency = 1, Text = "", TextStrokeTransparency = 0, TextStrokeColor3 = PAPER }, gui)
local notice = mk("TextLabel", { Size = UDim2.fromScale(0.5, 0.05), Position = UDim2.fromScale(0.25, 0.21), BackgroundTransparency = 1, Text = "", TextStrokeTransparency = 0, TextStrokeColor3 = PAPER }, gui)
local wallet = mk("TextLabel", { Size = UDim2.fromScale(0.16, 0.04), Position = UDim2.fromScale(0.01, 0.9), BackgroundTransparency = 1, Text = "", TextXAlignment = Enum.TextXAlignment.Left, TextStrokeTransparency = 0, TextStrokeColor3 = PAPER }, gui)

Remotes.Aviso.OnClientEvent:Connect(function(text)
	notice.Text = text
	task.delay(8, function()
		if notice.Text == text then
			notice.Text = ""
		end
	end)
end)

-- Menú: primero el bando (una sola vez), después la clase
local menu = mk("Frame", { Name = "Menu", ZIndex = 10, Size = UDim2.fromScale(1, 1), BackgroundColor3 = PAPER, BackgroundTransparency = 0.1, Visible = false }, gui)
local title = mk("TextLabel", { Size = UDim2.fromScale(0.8, 0.12), Position = UDim2.fromScale(0.1, 0.08), BackgroundTransparency = 1 }, menu)
local sub = mk("TextLabel", { Size = UDim2.fromScale(0.8, 0.05), Position = UDim2.fromScale(0.1, 0.2), BackgroundTransparency = 1 }, menu)
local cards = mk("Frame", { Size = UDim2.fromScale(0.8, 0.5), Position = UDim2.fromScale(0.1, 0.3), BackgroundTransparency = 1 }, menu)
mk("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0.03, 0) }, cards)

local function card(head: string, text: string, ink: Color3, width: number, onClick: () -> ())
	local b = mk("TextButton", { Size = UDim2.fromScale(width, 1), Text = "", AutoButtonColor = true }, cards)
	round(b, ink)
	mk("TextLabel", { Size = UDim2.fromScale(0.9, 0.25), Position = UDim2.fromScale(0.05, 0.08), BackgroundTransparency = 1, Text = head, TextColor3 = ink }, b)
	mk("TextLabel", { Size = UDim2.fromScale(0.86, 0.5), Position = UDim2.fromScale(0.07, 0.4), BackgroundTransparency = 1, Text = text, TextScaled = false, TextSize = 20, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top }, b)
	b.Activated:Connect(onClick)
end
local function clearCards()
	for _, c in cards:GetChildren() do
		if c:IsA("GuiButton") then
			c:Destroy()
		end
	end
end

local function showClasses()
	local team = player:GetAttribute("Bando")
	clearCards()
	title.Text = "Elige tu clase"
	sub.Text = if player.Character then "El cambio se aplica la próxima vez que aparezcas." else "Puedes cambiarla cuando quieras."
	for _, id in Rules.CLASS_ORDER do
		local c = Rules.CLASSES[id]
		local lines = { c.desc, "" }
		for i, s in c.skills do
			table.insert(lines, ("[%s] %s"):format(KEYS[i], s.name))
		end
		card(("%s\n%s"):format(c.name, c.role), table.concat(lines, "\n"), INK[team] or DARK, 0.3, function()
			Remotes.Elegir:FireServer(nil, id)
			menu.Visible = false
		end)
	end
	menu.Visible = true
end
local function showTeams()
	clearCards()
	title.Text = "¿De qué bando eres?"
	sub.Text = "Piénsalo bien: tu bando es para siempre."
	for _, team in { "azul", "rojo" } do
		card("Lapicero " .. NAMES[team], "Pelea por el castillo " .. string.lower(NAMES[team]) .. " y borra el del rival.", INK[team], 0.4, function()
			Remotes.Elegir:FireServer(team, nil)
			player:GetAttributeChangedSignal("Bando"):Wait()
			showClasses()
		end)
	end
	menu.Visible = true
end
local change = mk("TextButton", { Size = UDim2.fromScale(0.12, 0.05), Position = UDim2.fromScale(0.01, 0.94), Text = "Cambiar clase" }, gui)
round(change)
change.Activated:Connect(function()
	if player:GetAttribute("Bando") then
		showClasses()
	end
end)
task.spawn(function()
	while not player:GetAttribute("Listo") do
		task.wait(0.2)
	end
	if not player:GetAttribute("Bando") then
		showTeams()
	end
end)

-- Habilidades
local cds = { 0, 0, 0 }
local buttons = {}
local function aim(root: BasePart): Vector3
	if UserInputService.MouseEnabled then
		mouse.TargetFilter = player.Character
		local d = (mouse.Hit.Position - root.Position) * Vector3.new(1, 0, 1)
		if d.Magnitude > 1 then
			return d.Unit
		end
	end
	local look = root.CFrame.LookVector * Vector3.new(1, 0, 1) -- en celular se apunta hacia donde miras
	return if look.Magnitude > 0.01 then look.Unit else Vector3.xAxis
end
local function use(slot: number)
	local char = player.Character
	local class = char and Rules.CLASSES[char:GetAttribute("Clase")]
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (class and root and hum and hum.Health > 0) or menu.Visible or workspace:GetAttribute("Estado") ~= "pelea" then
		return
	end
	local now = os.clock()
	if now < cds[slot] then
		return
	end
	local skill = class.skills[slot]
	cds[slot] = now + skill.cd
	local dir = aim(root)
	Remotes.Usar:FireServer(slot, dir.X, dir.Z)
	root.CFrame = CFrame.lookAt(root.Position, root.Position + dir)
	if skill.kind == "dash" then
		local lv = Instance.new("LinearVelocity")
		lv.Attachment0 = root:FindFirstChildOfClass("Attachment")
		lv.MaxForce = 1e6
		lv.VectorVelocity = dir * skill.range / 0.2
		lv.Parent = root
		Debris:AddItem(lv, 0.2)
	end
end
local pad = mk("Frame", { Size = UDim2.fromScale(0.3, 0.12), Position = UDim2.fromScale(0.35, 0.86), BackgroundTransparency = 1 }, gui)
mk("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0.04, 0) }, pad)
for i = 1, 3 do
	buttons[i] = mk("TextButton", { Size = UDim2.fromScale(0.28, 1), Text = "" }, pad)
	round(buttons[i])
	buttons[i].Activated:Connect(function()
		use(i)
	end)
end
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		use(1)
	elseif input.KeyCode == Enum.KeyCode.Q then
		use(2)
	elseif input.KeyCode == Enum.KeyCode.E then
		use(3)
	end
end)
player.CharacterAdded:Connect(function()
	cds = { 0, 0, 0 }
end)

-- Trazos de los ataques
local fxFolder = mk("Folder", { Name = "Trazos" }, workspace)
local function fade(p: BasePart, t: number)
	TweenService:Create(p, TweenInfo.new(t), { Transparency = 1 }):Play()
	Debris:AddItem(p, t)
end
Remotes.Fx.OnClientEvent:Connect(function(kind, color, a, b)
	if typeof(a) ~= "Vector3" then
		return
	end
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.Neon
	p.Color = INK[color] or DARK
	if kind == "linea" and typeof(b) == "Vector3" and (b - a).Magnitude > 0.1 then
		p.Size = Vector3.new(0.25, 0.25, (b - a).Magnitude)
		p.CFrame = CFrame.lookAt((a + b) / 2, b)
		p.Parent = fxFolder
		fade(p, 0.25)
	elseif kind == "aro" and type(b) == "number" then
		p.Shape = Enum.PartType.Cylinder
		p.Size = Vector3.new(0.2, b * 2, b * 2)
		p.CFrame = CFrame.new(a.X, 0.3, a.Z) * CFrame.Angles(0, 0, math.pi / 2)
		p.Transparency = 0.5
		p.Parent = fxFolder
		fade(p, 0.35)
	end
end)

-- Cada cuadro: marcador, botones y piernas de los soldados
local npcFolder = workspace:WaitForChild("Palitos")
local lastPos: { [Instance]: Vector3 } = setmetatable({}, { __mode = "k" }) :: any
RunService.RenderStepped:Connect(function()
	local now = os.clock()
	local estado = workspace:GetAttribute("Estado")
	local left = math.max(0, (workspace:GetAttribute("Fin") or 0) - workspace:GetServerTimeNow())
	for team, bar in bars do
		bar.Size = UDim2.fromScale(math.clamp((workspace:GetAttribute("Hp_" .. team) or 0) / Rules.CFG.castleHp, 0, 1), 1)
	end
	clock.Text = ("%d:%02d"):format(left // 60, left % 60)
	local won = workspace:GetAttribute("Ganador")
	if estado == "espera" then
		banner.Text = ("La batalla empieza en %d"):format(math.ceil(left))
		banner.TextColor3 = DARK
	elseif estado == "fin" and won then
		banner.Text = if won == "empate" then "¡EMPATE!" else ("¡GANA " .. NAMES[won] .. "!")
		banner.TextColor3 = INK[won] or DARK
	else
		banner.Text = ""
	end
	wallet.Text = ("%d monedas · nivel %d"):format(player:GetAttribute("Monedas") or 0, player:GetAttribute("Nivel") or 1)

	local char = player.Character
	local class = char and Rules.CLASSES[char:GetAttribute("Clase")]
	pad.Visible = class ~= nil
	if class then
		for i, b in buttons do
			local wait = cds[i] - now
			b.Text = if wait > 0 then ("%.0f"):format(math.ceil(wait)) else ("%s\n[%s]"):format(class.skills[i].name, KEYS[i])
			b.BackgroundTransparency = if wait > 0 then 0.5 else 0
		end
	end

	for _, m in npcFolder:GetChildren() do
		local root = (m :: Model).PrimaryPart
		if root then
			local moved = lastPos[m] and (root.Position - lastPos[m]).Magnitude > 0.01
			lastPos[m] = root.Position
			local s = 1
			for _, d in m:GetDescendants() do
				if d.Name == "Pierna" and d:IsA("Weld") then
					local x = d.C0.Position.X
					d.C0 = CFrame.new(x, -0.4, 0) * CFrame.Angles(if moved then math.sin(now * 9) * 0.7 * s else 0, 0, 0)
					s = -s
				end
			end
		end
	end
end)
