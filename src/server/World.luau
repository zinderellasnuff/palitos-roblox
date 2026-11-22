-- El mapa: una hoja de cuaderno gigante con un castillo en cada punta. Todo se arma por código.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rules = require(ReplicatedStorage.Shared.Rules)
local CFG = Rules.CFG

local World = {}
World.INK = { azul = Color3.fromRGB(35, 75, 205), rojo = Color3.fromRGB(215, 45, 45) }
local LONG, WIDE, LAYERS = 290, 100, 6
local castles: { [string]: { BasePart } } = {}

local function part(props: { [string]: any }, parent: Instance): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = parent
	return p
end

function World.build()
	local map = Instance.new("Folder")
	map.Name = "Hoja"
	map.Parent = workspace
	part({ Name = "Papel", Size = Vector3.new(LONG, 1, WIDE), Position = Vector3.new(0, -0.5, 0), Color = Color3.fromRGB(250, 248, 240) }, map)
	-- renglones azules y el margen rojo del cuaderno
	for z = -WIDE / 2 + 5, WIDE / 2 - 5, 5 do
		part({ Size = Vector3.new(LONG, 0.05, 0.25), Position = Vector3.new(0, 0.02, z), Color = Color3.fromRGB(150, 190, 235), CanCollide = false, CastShadow = false }, map)
	end
	part({ Size = Vector3.new(LONG, 0.06, 0.35), Position = Vector3.new(0, 0.03, -WIDE / 2 + 12), Color = Color3.fromRGB(235, 120, 120), CanCollide = false, CastShadow = false }, map)
	-- paredes invisibles para no caerse de la hoja
	for _, w in { { LONG, 0, WIDE / 2 }, { LONG, 0, -WIDE / 2 }, { 0, LONG / 2, WIDE }, { 0, -LONG / 2, WIDE } } do
		local alongX = w[1] > 0
		part({
			Size = if alongX then Vector3.new(LONG, 60, 1) else Vector3.new(1, 60, WIDE),
			Position = if alongX then Vector3.new(0, 30, w[3]) else Vector3.new(w[2], 30, 0),
			Transparency = 1,
		}, map)
	end
	-- castillos: bloques apilados que se van borrando desde arriba
	for team, ink in World.INK do
		local x = Rules.side(team) * CFG.castleX
		castles[team] = {}
		for i = 1, LAYERS do
			local s = 17 - i * 1.5
			castles[team][i] = part({ Name = "Castillo", Size = Vector3.new(s, 5, s), Position = Vector3.new(x, i * 5 - 2.5, 0), Color = ink }, map)
		end
		local flag = part({ Size = Vector3.new(0.3, 7, 0.3), Position = Vector3.new(x, LAYERS * 5 + 3.5, 0), Color = Color3.fromRGB(40, 40, 40), CanCollide = false }, map)
		table.insert(castles[team], flag)
	end
end

-- frac: vida que le queda al castillo (1 = entero, 0 = borrado)
function World.setCastle(team: string, frac: number)
	local show = math.ceil(math.clamp(frac, 0, 1) * LAYERS)
	for i, p in castles[team] do
		local on = math.min(i, LAYERS) <= show -- la bandera se va con el último piso
		p.Transparency = if on then 0 else 1
		p.CanCollide = on and i <= LAYERS
	end
end

return World
