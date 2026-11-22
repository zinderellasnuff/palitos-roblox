-- Pruebas de las reglas: `lune run tests/rules`
local Rules = require("../src/shared/Rules")
local CFG, C = Rules.CFG, Rules.CLASSES

local passed = 0
local function check(name: string, cond: boolean)
	if not cond then
		error("FALLÓ: " .. name, 2)
	end
	passed += 1
end
local function T(x, z, team, castle)
	return { x = x, z = z, team = team, r = if castle then CFG.castleR else 1.5, castle = castle }
end

check("bandos", Rules.other("azul") == "rojo" and Rules.side("azul") == -1 and Rules.side("rojo") == 1)
check("máquina completa el bando", Rules.npcCount(0, 0) == 8 and Rules.npcCount(3, 1) == 5)
check("máquina iguala a un bando lleno de gente", Rules.npcCount(2, 12) == 10 and Rules.npcCount(12, 2) == 0)
check("escudo", select(1, Rules.absorb(20, 30)) == 0 and select(2, Rules.absorb(20, 30)) == 10 and select(1, Rules.absorb(50, 30)) == 20)
check("nivel", Rules.level(0) == 1 and Rules.level(49) == 1 and Rules.level(50) == 2 and Rules.level(200) == 3)
check("asedio", Rules.siege(0) == 1 and Rules.siege(120) == 1 and Rules.siege(240) == 2)
check("ganador", Rules.winner(100, 100, 50) == nil and Rules.winner(0, 5, 50) == "rojo" and Rules.winner(5, 0, 50) == "azul")
check("ganador por tiempo", Rules.winner(900, 500, 0) == "azul" and Rules.winner(5, 5, 0) == "empate")

-- Tajo: pega al de adelante, no al de atrás, no al compañero, sí al castillo pegado
local tajo = C.rayon.skills[1]
local list = { T(0, 0, "azul"), T(6, 0, "rojo"), T(-6, 0, "rojo"), T(5, 1, "azul"), T(30, 0, "rojo") }
local hits = Rules.resolve(tajo, 0, 0, 1, 0, "azul", list, 1)
check("tajo solo al de adelante", #hits == 1 and hits[1].i == 2 and hits[1].dmg == 22)
hits = Rules.resolve(tajo, 92, 0, 1, 0, "azul", { T(110, 0, "rojo", true) }, 0)
check("tajo al castillo", #hits == 1)
hits = Rules.resolve(tajo, 92, 0, 1, 0, "rojo", { T(110, 0, "rojo", true) }, 0)
check("no pegas a tu castillo", #hits == 0)

-- Piedra: el primero en la línea; atraviesa compañeros; no llega más allá del alcance
local piedra = C.tirachinas.skills[1]
local rays
hits, rays = Rules.resolve(piedra, 0, 0, 1, 0, "azul", { T(0, 0, "azul"), T(10, 0, "azul"), T(30, 0, "rojo"), T(20, 0.5, "rojo") }, 1)
check("piedra al primero", #hits == 1 and hits[1].i == 4 and math.abs(rays[1][3] - 18.5) < 0.01)
hits, rays = Rules.resolve(piedra, 0, 0, 1, 0, "azul", { T(60, 0, "rojo"), T(-10, 0, "rojo"), T(20, 6, "rojo") }, 0)
check("piedra falla", #hits == 0 and rays[1][3] == 45)
hits, rays = Rules.resolve(C.tirachinas.skills[2], 0, 0, 1, 0, "azul", { T(20, 0, "rojo"), T(20, 4, "rojo"), T(20, -4, "rojo") }, 0)
check("lluvia: 3 tiros, 3 blancos", #hits == 3 and #rays == 3)
check("voltereta no pega", #Rules.resolve(C.tirachinas.skills[3], 0, 0, 1, 0, "azul", { T(-5, 0, "rojo") }, 0) == 0)

-- Carga: todos los del camino
hits = Rules.resolve(C.rayon.skills[2], 0, 0, 1, 0, "azul", { T(5, 2, "rojo"), T(20, -3, "rojo"), T(40, 0, "rojo"), T(10, 9, "rojo") }, 0)
check("carga pega en el camino", #hits == 2)

-- Corrector: la gota cura al compañero o daña al enemigo; charco y capa solo a los suyos (incluido él), nunca al castillo
local gota = C.corrector.skills[1]
hits = Rules.resolve(gota, 0, 0, 1, 0, "azul", { T(0, 0, "azul"), T(10, 0, "azul"), T(20, 0, "rojo") }, 1)
check("gota cura", #hits == 1 and hits[1].i == 2 and hits[1].heal == 14 and hits[1].dmg == nil)
hits = Rules.resolve(gota, 0, 0, 1, 0, "azul", { T(0, 0, "azul"), T(20, 0, "rojo") }, 1)
check("gota daña", #hits == 1 and hits[1].dmg == 9 and hits[1].heal == nil)
list = { T(0, 0, "azul"), T(5, 5, "azul"), T(3, 0, "rojo"), T(40, 0, "azul"), T(10, 0, "azul", true) }
hits = Rules.resolve(C.corrector.skills[2], 0, 0, 1, 0, "azul", list, 1)
check("charco cura a los suyos", #hits == 2 and hits[1].heal == 40)
hits = Rules.resolve(C.corrector.skills[3], 0, 0, 1, 0, "azul", list, 1)
check("capa da escudo", #hits == 2 and hits[1].shield == 30)

-- Soldados
local n = { x = 0, z = 0, team = "azul", kind = "rayon", lane = 5 }
local mx, mz, atk = Rules.npcThink(n, { T(110, 0, "rojo", true), T(-110, 0, "azul", true) })
check("soldado va al castillo rival", mx > 0.9 and atk == 0)
mx, mz, atk = Rules.npcThink(n, { T(110, 0, "rojo", true), T(0, 20, "rojo") })
check("soldado va por el enemigo cercano", mz > 0.9 and atk == 0)
mx, mz, atk = Rules.npcThink(n, { T(110, 0, "rojo", true), T(4, 0, "rojo") })
check("soldado ataca", mx == 0 and atk == 2)
n.x = 93
mx, mz, atk = Rules.npcThink(n, { T(110, 0, "rojo", true) })
check("soldado ataca el castillo", atk == 1)
n.x, n.kind = 60, "tirachinas"
check("ningún tiro alcanza más que el castillo", select(3, Rules.npcThink(n, { T(110, 0, "rojo", true) })) == 0)
for _, c in C do
	for _, s in c.skills do
		check("alcance de " .. s.name, s.kind ~= "shot" or s.range + CFG.castleR < CFG.towerRange)
	end
end
check("soldado no ataca fuera de la torre", Rules.NPC.tirachinas.range + CFG.castleR < CFG.towerRange)

-- Batalla entera solo con soldados de la máquina (sin personas): debe durar y no trabarse.
local function battle(seed: number, bonus: number): (string, number)
	math.randomseed(seed)
	local castles = { T(-CFG.castleX, 0, "azul", true), T(CFG.castleX, 0, "rojo", true) }
	local hp = { azul = CFG.castleHp, rojo = CFG.castleHp }
	local npcs, nextNpc, made = {}, { azul = 0, rojo = 0 }, 0
	local dt, t = 0.1, 0
	while true do
		local w = Rules.winner(hp.azul, hp.rojo, CFG.roundTime - t)
		if w then
			return w, t
		end
		local alive = {}
		for _, x in npcs do
			if x.hp > 0 then
				table.insert(alive, x)
			end
		end
		npcs = alive
		for _, team in { "azul", "rojo" } do
			local own = 0
			for _, x in npcs do
				own += if x.team == team then 1 else 0
			end
			if own < CFG.teamSize and t >= nextNpc[team] then
				made += 1
				local kind = Rules.npcKind(made)
				table.insert(npcs, { x = Rules.side(team) * (CFG.castleX - 16), z = math.random(-25, 25), lane = math.random(-8, 8), team = team, kind = kind, hp = Rules.NPC[kind].hp, r = 1.5, next = 0 })
				nextNpc[team] = t + CFG.npcEvery
			end
		end
		local targets = { castles[1], castles[2], table.unpack(npcs) }
		for _, x in npcs do
			local st = Rules.NPC[x.kind]
			local vx, vz, a = Rules.npcThink(x, targets)
			if a > 0 then
				if t >= x.next then
					x.next = t + st.cd
					local tg = targets[a]
					local dmg = st.dmg * (if x.team == "azul" then bonus else 1)
					if tg.castle then
						hp[tg.team] -= dmg * Rules.siege(t)
					else
						tg.hp -= dmg
					end
				end
			else
				x.x += vx * st.speed * dt
				x.z += vz * st.speed * dt
			end
		end
		if math.floor(t / CFG.towerEvery) ~= math.floor((t + dt) / CFG.towerEvery) then
			for _, c in castles do
				local best, bd = nil, CFG.towerRange
				for _, x in npcs do
					local d = math.sqrt((x.x - c.x) ^ 2 + (x.z - c.z) ^ 2)
					if x.team ~= c.team and x.hp > 0 and d < bd then
						best, bd = x, d
					end
				end
				if best then
					best.hp -= CFG.towerDmg
				end
			end
		end
		t += dt
	end
end
local min, max = 1e9, 0
for seed = 1, 6 do
	local w, t = battle(seed, 1)
	min, max = math.min(min, t), math.max(max, t)
	print(("batalla pareja %d: %s en %d s"):format(seed, w, t))
end
check("pareja: dura al menos 3 minutos", min >= 180)
local wins = 0
for seed = 1, 6 do
	local w, t = battle(seed, 1.6)
	wins += if w == "azul" then 1 else 0
	print(("azul con ventaja %d: %s en %d s"):format(seed, w, t))
end
check("el bando que pega más gana", wins >= 5)

print(("OK: %d pruebas"):format(passed))
