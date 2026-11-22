-- Guardado del progreso de cada jugador (bando, clase, monedas, XP) con DataStore.
-- En un archivo sin publicar (o sin "Enable Studio Access to API Services") no hay DataStore: se juega igual, pero no se guarda.
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local Data = {}
local KEY = "u_%d"
local store = nil
pcall(function()
	store = DataStoreService:GetDataStore("Palitos_v1")
end)

local function default()
	return {
		v = 1,
		coins = 0,
		class = "rayon",
		xp = { rayon = 0, tirachinas = 0, corrector = 0 }, -- cada clase sube de nivel por separado
		stats = { win = 0, ko = 0, play = 0 },
		-- team: "azul" | "rojo" (se elige una sola vez; nil hasta entonces)
	}
end

-- Completa campos que falten (si se agregan cosas nuevas, los datos viejos siguen sirviendo).
local function reconcile(saved, base)
	if type(saved) ~= "table" then
		return base
	end
	for k, v in base do
		if saved[k] == nil then
			saved[k] = v
		elseif type(v) == "table" and type(saved[k]) == "table" and next(v) ~= nil then
			reconcile(saved[k], v)
		end
	end
	return saved
end

local profiles: { [Player]: { data: any, canSave: boolean } } = {}

function Data.load(plr: Player)
	local data, canSave = nil, false
	if store then
		for attempt = 1, 3 do
			local ok, res = pcall(function()
				return store:GetAsync(KEY:format(plr.UserId))
			end)
			if ok then
				data, canSave = reconcile(res, default()), true
				break
			end
			warn(("No se pudo cargar a %s (intento %d): %s"):format(plr.Name, attempt, tostring(res)))
			task.wait(attempt)
		end
	end
	if not data then
		data = default()
		if store then
			-- si no cargó, no se guarda: así no se borran sus datos de verdad
			warn("Se juega sin guardar para " .. plr.Name)
		end
	end
	if plr.Parent == nil then
		return nil -- se fue mientras cargaba: no registrarlo, o el autoguardado pisaría sus datos con unos viejos
	end
	profiles[plr] = { data = data, canSave = canSave }
	return data
end

function Data.get(plr: Player)
	local p = profiles[plr]
	return p and p.data
end

-- Devuelve true solo si quedó guardado de verdad.
function Data.save(plr: Player): boolean
	local p = profiles[plr]
	if not (p and p.canSave and store) then
		return false
	end
	-- shortcut: UpdateAsync sin bloqueo de sesión; si un jugador salta de servidor muy rápido puede perder segundos de progreso. Usar ProfileStore si crece.
	local ok, err = pcall(function()
		store:UpdateAsync(KEY:format(plr.UserId), function()
			return p.data
		end)
	end)
	if not ok then
		warn("No se pudo guardar a " .. plr.Name .. ": " .. tostring(err))
	end
	return ok
end

function Data.release(plr: Player)
	Data.save(plr)
	profiles[plr] = nil
end

-- guardado automático cada 2 minutos y al cerrar el servidor
task.spawn(function()
	while true do
		task.wait(120)
		for plr in profiles do
			task.spawn(Data.save, plr)
		end
	end
end)
game:BindToClose(function()
	if RunService:IsStudio() and not store then
		return
	end
	local pending = 0
	for plr in profiles do
		pending += 1
		task.spawn(function()
			Data.save(plr)
			pending -= 1
		end)
	end
	local t = os.clock()
	while pending > 0 and os.clock() - t < 25 do
		task.wait(0.2)
	end
end)

return Data
