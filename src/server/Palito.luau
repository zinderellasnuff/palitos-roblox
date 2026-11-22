-- Cómo se ve un palito: trazos de lapicero (cilindros) y una cabeza redonda, del color de su bando.
-- Los jugadores usan el cuerpo normal de Roblox (R15) vuelto invisible, con los trazos pegados encima: así las animaciones de caminar y saltar salen gratis.
local World = require(script.Parent.World)

local Palito = {}
local UP = CFrame.Angles(0, 0, math.pi / 2) -- el cilindro nace echado: esto lo para
local LIMBS = { "UpperTorso", "LowerTorso", "LeftUpperArm", "LeftLowerArm", "RightUpperArm", "RightLowerArm", "LeftUpperLeg", "LeftLowerLeg", "RightUpperLeg", "RightLowerLeg" }

local function piece(shape: Enum.PartType, size: Vector3, color: Color3): Part
	local p = Instance.new("Part")
	p.Shape = shape
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = false, false, false, true
	return p
end

local function weld(p: BasePart, to: BasePart, c0: CFrame, name: string?): Weld
	local w = Instance.new("Weld")
	w.Name = name or "Weld"
	w.Part0, w.Part1, w.C0 = to, p, c0
	w.Parent = p
	p.Parent = to.Parent
	return w
end

-- Lo que lleva en la mano dice su clase: lápiz (Rayón), horqueta (Tirachinas), frasco blanco (Corrector).
local function weapon(class: string): (Part, CFrame)
	if class == "tirachinas" then
		return piece(Enum.PartType.Block, Vector3.new(0.9, 1.3, 0.25), Color3.fromRGB(140, 95, 50)), CFrame.new(0, 0.2, -0.5)
	elseif class == "corrector" then
		return piece(Enum.PartType.Block, Vector3.new(0.7, 1.2, 0.7), Color3.fromRGB(255, 255, 255)), CFrame.new(0, 0, -0.5)
	end
	return piece(Enum.PartType.Block, Vector3.new(0.3, 0.3, 3.4), Color3.fromRGB(245, 200, 60)), CFrame.new(0, 0, -1.5)
end

function Palito.dress(char: Model, team: string, class: string)
	local ink = World.INK[team]
	for _, d in char:GetDescendants() do
		if d:IsA("BasePart") then
			d.Transparency = 1
		elseif d:IsA("Decal") then
			d:Destroy()
		end
	end
	for _, name in LIMBS do
		local limb = char:FindFirstChild(name)
		if limb and limb:IsA("BasePart") then
			weld(piece(Enum.PartType.Cylinder, Vector3.new(limb.Size.Y + 0.25, 0.32, 0.32), ink), limb, UP)
		end
	end
	local head = char:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		weld(piece(Enum.PartType.Ball, Vector3.new(1.5, 1.5, 1.5), ink), head, CFrame.new())
	end
	local hand = char:FindFirstChild("RightHand")
	if hand and hand:IsA("BasePart") then
		local w, c0 = weapon(class)
		weld(w, hand, c0)
	end
end

-- Soldado de la máquina: sin Humanoid (son muchos); el servidor mueve la raíz y el cliente le mueve las piernas.
-- Devuelve el modelo y la barra de vida.
function Palito.npc(team: string, kind: string): (Model, Frame)
	local ink = World.INK[team]
	local model = Instance.new("Model")
	model.Name = team
	local root = Instance.new("Part")
	root.Name = "Raiz"
	root.Size = Vector3.new(2, 5.2, 1)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.Parent = model
	model.PrimaryPart = root
	weld(piece(Enum.PartType.Ball, Vector3.new(1.3, 1.3, 1.3), ink), root, CFrame.new(0, 1.85, 0))
	weld(piece(Enum.PartType.Cylinder, Vector3.new(1.6, 0.3, 0.3), ink), root, CFrame.new(0, 0.4, 0) * UP)
	for s = -1, 1, 2 do
		weld(piece(Enum.PartType.Cylinder, Vector3.new(1.5, 0.26, 0.26), ink), root, CFrame.new(s * 0.45, 0.45, 0) * CFrame.Angles(0, 0, s * 0.5) * UP)
		-- la pierna cuelga de la cadera: el cliente gira C0 para que camine
		local leg = weld(piece(Enum.PartType.Cylinder, Vector3.new(2.2, 0.28, 0.28), ink), root, CFrame.new(s * 0.3, -0.4, 0), "Pierna")
		leg.C1 = (CFrame.new(0, -1.1, 0) * UP):Inverse()
	end
	local w, c0 = weapon(kind)
	weld(w, root, CFrame.new(0.9, 0.1, 0) * c0)

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(3, 0.3)
	gui.StudsOffset = Vector3.new(0, 3.4, 0)
	gui.MaxDistance = 90
	gui.Parent = root
	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	back.BorderSizePixel = 0
	back.Parent = gui
	local bar = Instance.new("Frame")
	bar.Size = UDim2.fromScale(1, 1)
	bar.BackgroundColor3 = ink
	bar.BorderSizePixel = 0
	bar.Parent = back
	return model, bar
end

return Palito
