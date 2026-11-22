-- Reglas puras de Palitos (sin APIs de Roblox): clases, habilidades, soldados de la máquina, castillos y premios.
-- Se prueban con `lune run tests/rules`. Las posiciones son números sueltos (x, z) para que corran fuera de Roblox.
local Rules = {}

Rules.CFG = {
	countdown = 8, -- segundos antes de cada batalla
	roundTime = 420, -- la batalla dura como máximo 7 minutos
	endTime = 10, -- pantalla del ganador
	castleHp = 3000,
	castleX = 110, -- azul en -110, rojo en +110
	castleR = 12,
	towerRange = 60, -- el castillo se defiende (más lejos que cualquier tiro, para que nadie lo ataque gratis)
	towerDmg = 14,
	towerEvery = 1,
	teamSize = 8, -- peleadores por bando; los que no son personas los pone la máquina
	npcEvery = 3, -- segundos entre soldados nuevos de un bando
	respawn = 5,
	aggro = 40, -- a esta distancia un soldado deja el camino y va por un enemigo
	shieldTime = 5,
	winCoins = 30,
	winXp = 60,
	loseCoins = 12,
	loseXp = 25,
	koCoins = 2,
	koXp = 5,
	koPlayerCoins = 5,
	koPlayerXp = 12,
	healXp = 2,
}

export type Skill = {
	name: string,
	kind: string, -- "melee" | "shot" | "dash" | "area"
	cd: number,
	range: number,
	dmg: number?,
	heal: number?,
	shield: number?,
	arc: number?,
	width: number?,
	n: number?,
	spread: number?,
}
export type Target = { x: number, z: number, team: string, r: number, castle: boolean? }
export type Hit = { i: number, dmg: number?, heal: number?, shield: number? }

-- Cada clase: ataque normal (clic), habilidad Q y habilidad E.
Rules.CLASS_ORDER = { "rayon", "tirachinas", "corrector" }
Rules.CLASSES = {
	rayon = {
		name = "Rayón",
		role = "Guerrero",
		desc = "Pega de cerca y aguanta. Carga contra el enemigo.",
		hp = 160,
		speed = 17,
		skills = {
			{ name = "Tajo", kind = "melee", dmg = 22, range = 8, arc = 0.3, cd = 0.5 },
			{ name = "Carga", kind = "dash", dmg = 35, range = 24, width = 4, cd = 6 },
			{ name = "Remolino", kind = "area", dmg = 28, range = 10, cd = 8 },
		},
	},
	tirachinas = {
		name = "Tirachinas",
		role = "Arquero",
		desc = "Dispara de lejos. Poca vida: no dejes que se te acerquen.",
		hp = 100,
		speed = 18,
		skills = {
			{ name = "Piedra", kind = "shot", dmg = 15, range = 45, cd = 0.7 },
			{ name = "Lluvia", kind = "shot", dmg = 15, range = 45, n = 3, spread = 0.2, cd = 6 },
			{ name = "Voltereta", kind = "dash", range = -20, cd = 7 },
		},
	},
	corrector = {
		name = "Corrector",
		role = "Curandero",
		desc = "Cura a sus compañeros y los protege. Un bando con curandero dura más.",
		hp = 110,
		speed = 17,
		skills = {
			{ name = "Gota", kind = "shot", dmg = 9, heal = 14, range = 40, cd = 0.6 },
			{ name = "Charco", kind = "area", heal = 40, range = 16, cd = 9 },
			{ name = "Capa", kind = "area", shield = 30, range = 14, cd = 14 },
		},
	},
}

-- Soldados de la máquina: más débiles que una persona, para que jugar bien se note.
Rules.NPC = {
	rayon = { hp = 70, dmg = 10, range = 6, cd = 1, speed = 11 },
	tirachinas = { hp = 45, dmg = 8, range = 30, cd = 1.4, speed = 11 },
}

function Rules.other(team: string): string
	return if team == "azul" then "rojo" else "azul"
end

-- Lado del mapa: azul a la izquierda (-1), rojo a la derecha (+1).
function Rules.side(team: string): number
	return if team == "azul" then -1 else 1
end

-- Uno de cada tres soldados es Tirachinas.
function Rules.npcKind(i: number): string
	return if i % 3 == 0 then "tirachinas" else "rayon"
end

-- Cuántos soldados pone la máquina: completa el bando hasta `teamSize`, o hasta igualar a las personas del otro bando.
function Rules.npcCount(own: number, enemy: number): number
	return math.max(0, math.max(Rules.CFG.teamSize, enemy) - own)
end

-- Con el tiempo los castillos reciben más daño, para que la batalla no se quede trabada.
function Rules.siege(elapsed: number): number
	return 1 + math.max(0, elapsed - 120) / 120
end

-- El escudo se gasta primero. Devuelve el daño que pasa y el escudo que queda.
function Rules.absorb(dmg: number, shield: number): (number, number)
	local used = math.min(dmg, shield)
	return dmg - used, shield - used
end

function Rules.level(xp: number): number
	return math.floor(math.sqrt(math.max(0, xp) / 50)) + 1
end

-- nil mientras siga la batalla. Si se acaba el tiempo gana el castillo más entero.
function Rules.winner(hpAzul: number, hpRojo: number, timeLeft: number): string?
	if hpAzul <= 0 and hpRojo <= 0 then
		return "empate"
	elseif hpAzul <= 0 then
		return "rojo"
	elseif hpRojo <= 0 then
		return "azul"
	elseif timeLeft <= 0 then
		return if hpAzul > hpRojo then "azul" elseif hpRojo > hpAzul then "rojo" else "empate"
	end
	return nil
end

-- A quién le pega (o cura) una habilidad lanzada desde (ox, oz) hacia (dx, dz), que ya viene con largo 1.
-- `me` es el puesto del que la lanza dentro de `targets` (0 si no está).
-- Devuelve los golpes y, para los disparos, cada tiro como { dirX, dirZ, largo } para dibujarlo.
function Rules.resolve(skill: Skill, ox: number, oz: number, dx: number, dz: number, team: string, targets: { Target }, me: number): ({ Hit }, { { number } })
	local hits: { Hit } = {}
	local rays = {}
	local helps = skill.heal ~= nil or skill.shield ~= nil
	local function wants(t: Target): boolean
		if t.team ~= team then
			return skill.dmg ~= nil
		end
		return helps and not t.castle
	end
	local function effect(i: number)
		if targets[i].team ~= team then
			table.insert(hits, { i = i, dmg = skill.dmg })
		else
			table.insert(hits, { i = i, heal = skill.heal, shield = skill.shield })
		end
	end

	if skill.kind == "shot" then
		local n = skill.n or 1
		for k = 1, n do
			local a = ((k - 1) - (n - 1) / 2) * (skill.spread or 0)
			local rx, rz = dx * math.cos(a) - dz * math.sin(a), dx * math.sin(a) + dz * math.cos(a)
			local best, bestAt = 0, skill.range
			for i, t in targets do
				if i ~= me and wants(t) then
					local px, pz = t.x - ox, t.z - oz
					local along = px * rx + pz * rz
					local at = math.max(0, along - t.r) -- donde el tiro lo toca
					if along > 0 and math.abs(px * rz - pz * rx) <= t.r + 1 and at <= bestAt then
						best, bestAt = i, at
					end
				end
			end
			if best > 0 then
				effect(best)
			end
			rays[k] = { rx, rz, bestAt }
		end
	elseif skill.kind == "melee" then
		for i, t in targets do
			if i ~= me and wants(t) then
				local px, pz = t.x - ox, t.z - oz
				local d = math.sqrt(px * px + pz * pz)
				if d <= skill.range + t.r and (d <= t.r + 2 or (px * dx + pz * dz) / d >= (skill.arc or 0)) then
					effect(i)
				end
			end
		end
	elseif skill.kind == "dash" then
		if skill.dmg then
			local len = math.abs(skill.range)
			local sx, sz = dx * (skill.range / len), dz * (skill.range / len)
			for i, t in targets do
				if i ~= me and wants(t) then
					local px, pz = t.x - ox, t.z - oz
					local along = math.clamp(px * sx + pz * sz, 0, len)
					local qx, qz = px - sx * along, pz - sz * along
					if math.sqrt(qx * qx + qz * qz) <= (skill.width or 3) + t.r then
						effect(i)
					end
				end
			end
		end
	elseif skill.kind == "area" then
		for i, t in targets do
			if wants(t) then
				local px, pz = t.x - ox, t.z - oz
				if math.sqrt(px * px + pz * pz) <= skill.range + t.r then
					effect(i)
				end
			end
		end
	end
	return hits, rays
end

-- Qué hace un soldado de la máquina: va por el enemigo más cercano, y si no hay ninguno cerca, por el castillo rival.
-- Devuelve hacia dónde camina (largo 1, o 0 si se queda quieto) y a quién ataca (0 = a nadie).
function Rules.npcThink(n: { x: number, z: number, team: string, kind: string, lane: number }, targets: { Target }): (number, number, number)
	local best, bd, castle = 0, Rules.CFG.aggro, 0
	for i, t in targets do
		if t.team ~= n.team then
			if t.castle then
				castle = i
			else
				local d = math.sqrt((t.x - n.x) ^ 2 + (t.z - n.z) ^ 2) - t.r
				if d < bd then
					best, bd = i, d
				end
			end
		end
	end
	local gx, gz
	if best > 0 then
		gx, gz = targets[best].x, targets[best].z
	elseif castle > 0 then
		local c = targets[castle]
		best, gx, gz = castle, c.x, n.lane
		bd = math.sqrt((c.x - n.x) ^ 2 + (c.z - n.z) ^ 2) - c.r
	else
		return 0, 0, 0
	end
	if bd <= Rules.NPC[n.kind].range then
		return 0, 0, best
	end
	local vx, vz = gx - n.x, gz - n.z
	local len = math.sqrt(vx * vx + vz * vz)
	if len < 0.001 then
		return 0, 0, 0
	end
	return vx / len, vz / len, 0
end

return Rules
