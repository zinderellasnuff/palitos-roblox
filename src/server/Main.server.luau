-- Palitos: batalla de Azul contra Rojo. El servidor decide todo: quién pega, cuánto, quién gana.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Rules = require(ReplicatedStorage.Shared.Rules)
local Data = require(script.Parent.Data)
local World = require(script.Parent.World)
local Palito = require(script.Parent.Palito)
local CFG = Rules.CFG
local TEAMS = { "azul", "rojo" }

Players.CharacterAutoLoads = false -- nadie aparece hasta elegir bando

local Remotes = Instance.new("Folder")
Remotes.Name = "Remotes"
local function remote(name: string, class: string): any
	local r = Instance.new(class)
	r.Name = name
	r.Parent = Remotes
	return r
end
local Elegir = remote("Elegir", "RemoteEvent") -- cliente → (bando, clase)
local Usar = remote("Usar", "RemoteEvent") -- cliente → (habilidad 1..3, dirX, dirZ)
local Aviso = remote("Aviso", "RemoteEvent") -- servidor → texto
local Fx = remote("Fx", "UnreliableRemoteEvent") -- servidor → ("linea" | "aro", color, desde, hasta | radio)
Remotes.Parent = ReplicatedStorage

World.build()
local npcFolder = Instance.new("Folder")
npcFolder.Name = "Palitos"
npcFolder.Parent = workspace

local state = "espera"
local startT = 0
local castles = {}
for _, team in TEAMS do
	castles[team] = { team = team, x = Rules.side(team) * CFG.castleX, z = 0, r = CFG.castleR, castle = true, hp = CFG.castleHp, next = 0 }
end
local npcs = {} -- { team, kind, x, z, lane, r, hp, model, bar, next, dead }
local npcMade = 0
local nextNpc = { azul = 0, rojo = 0 }
local cds: { [Player]: { number } } = {}
local shields: { [any]: { n: number, t: number } } = {} -- por jugador o por soldado
local spawning: { [Player]: boolean } = {}

local function body(plr: Player): (Humanoid?, BasePart?)
	local char = plr.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if hum and root and hum.Health > 0 then
		return hum, root :: BasePart
	end
	return nil, nil
end

-- Todo lo que se puede golpear o curar ahora mismo: castillos, soldados y jugadores vivos.
local function targets()
	local list: { any } = { castles.azul, castles.rojo }
	for _, n in npcs do
		if not n.dead then
			table.insert(list, n)
		end
	end
	for _, plr in Players:GetPlayers() do
		local team = plr:GetAttribute("Bando")
		local _, root = body(plr)
		if team and root then
			table.insert(list, { x = root.Position.X, z = root.Position.Z, team = team, r = 1.5, plr = plr })
		end
	end
	return list
end

local function setCastle(c)
	workspace:SetAttribute("Hp_" .. c.team, math.ceil(c.hp))
	World.setCastle(c.team, c.hp / CFG.castleHp)
end

local function publish(plr: Player)
	local d = Data.get(plr)
	if d then
		plr:SetAttribute("Monedas", d.coins)
		plr:SetAttribute("Nivel", Rules.level(d.xp[d.class] or 0))
		local ls = plr:FindFirstChild("leaderstats")
		if ls then
			(ls :: any).Bajas.Value = d.stats.ko;
			(ls :: any).Nivel.Value = plr:GetAttribute("Nivel")
		end
	end
end

local function reward(plr: Player, coins: number, xp: number)
	local d = Data.get(plr)
	if d then
		local char = plr.Character
		local class = (char and char:GetAttribute("Clase")) or d.class -- la XP va a la clase con la que estás jugando
		d.coins += coins
		d.xp[class] = (d.xp[class] or 0) + xp
		publish(plr)
	end
end

local function pos(t): Vector3
	return Vector3.new(t.x, 3, t.z)
end

local function hurt(t, dmg: number, by: Player?)
	if state ~= "pelea" or t.dead then
		return
	end
	local sh = shields[t.plr or t]
	if sh and sh.t > os.clock() then
		dmg, sh.n = Rules.absorb(dmg, sh.n)
	end
	if dmg <= 0 then
		return
	end
	if t.castle then
		t.hp = math.max(0, t.hp - dmg * Rules.siege(os.clock() - startT))
		setCastle(t)
	elseif t.plr then
		local hum = body(t.plr)
		if hum then
			if by and hum.Health <= dmg then
				local d = Data.get(by)
				if d then
					d.stats.ko += 1
				end
				reward(by, CFG.koPlayerCoins, CFG.koPlayerXp)
			end
			hum:TakeDamage(dmg)
		end
	else
		t.hp -= dmg
		if t.hp <= 0 then
			t.dead = true
			shields[t] = nil
			t.model:Destroy()
			if by then
				local d = Data.get(by)
				if d then
					d.stats.ko += 1
				end
				reward(by, CFG.koCoins, CFG.koXp)
			end
		else
			t.bar.Size = UDim2.fromScale(t.hp / t.maxHp, 1)
		end
	end
end

local function heal(t, n: number)
	if t.plr then
		local hum = body(t.plr)
		if hum then
			hum.Health = math.min(hum.MaxHealth, hum.Health + n)
		end
	elseif not t.dead then
		t.hp = math.min(t.maxHp, t.hp + n)
		t.bar.Size = UDim2.fromScale(t.hp / t.maxHp, 1)
	end
end

Usar.OnServerEvent:Connect(function(plr, slot, dx, dz)
	if state ~= "pelea" or type(slot) ~= "number" or type(dx) ~= "number" or type(dz) ~= "number" then
		return
	end
	local len = math.sqrt(dx * dx + dz * dz)
	local hum, root = body(plr)
	local team = plr:GetAttribute("Bando")
	local class = root and Rules.CLASSES[(plr.Character :: Model):GetAttribute("Clase")]
	local skill = class and class.skills[slot]
	local cd = cds[plr]
	if not (hum and root and team and skill and cd) or len ~= len or len < 0.001 then
		return
	end
	local now = os.clock()
	if now < (cd[slot] or 0) - 0.1 then -- 0.1 s de gracia por el retraso de la red
		return
	end
	cd[slot] = now + skill.cd
	dx, dz = dx / len, dz / len

	local list = targets()
	local me = 0
	for i, t in list do
		if t.plr == plr then
			me = i
		end
	end
	local o = root.Position
	local hits, rays = Rules.resolve(skill, o.X, o.Z, dx, dz, team, list, me)
	for _, h in hits do
		local t = list[h.i]
		if h.dmg then
			hurt(t, h.dmg, plr)
		end
		if h.heal then
			heal(t, h.heal)
			if t.plr ~= plr then
				reward(plr, 0, CFG.healXp)
			end
		end
		if h.shield then
			shields[t.plr or t] = { n = h.shield, t = now + CFG.shieldTime }
		end
	end

	local color = if skill.dmg then team else "cura"
	local dir = Vector3.new(dx, 0, dz)
	if skill.kind == "shot" then
		for _, r in rays do
			Fx:FireAllClients("linea", color, o, o + Vector3.new(r[1], 0, r[2]) * r[3])
		end
	elseif skill.kind == "dash" then
		Fx:FireAllClients("linea", color, o, o + dir * skill.range)
	elseif skill.kind == "melee" then
		Fx:FireAllClients("aro", color, o + dir * skill.range / 2, skill.range / 2)
	else
		Fx:FireAllClients("aro", color, o, skill.range)
	end
end)

local function aparecer(plr: Player)
	local d = Data.get(plr)
	if not (d and d.team) or spawning[plr] then
		return
	end
	spawning[plr] = true
	-- cuerpo en blanco (sin ropa ni accesorios): encima van los trazos del palito
	local ok, err = pcall(plr.LoadCharacterWithHumanoidDescriptionAsync, plr, Instance.new("HumanoidDescription"))
	spawning[plr] = nil
	local char = plr.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (ok and char and hum) then
		warn("No se pudo crear el palito de " .. plr.Name .. ": " .. tostring(err))
		return
	end
	local class = if Rules.CLASSES[d.class] then d.class else "rayon"
	local c = Rules.CLASSES[class]
	Palito.dress(char, d.team, class)
	char:SetAttribute("Clase", class)
	hum.MaxHealth, hum.Health, hum.WalkSpeed = c.hp, c.hp, c.speed
	local at = Vector3.new(Rules.side(d.team) * (CFG.castleX - 22), 4, math.random(-20, 20))
	char:PivotTo(CFrame.lookAt(at, Vector3.new(0, 4, at.Z)))
	cds[plr] = {}
	shields[plr] = nil
	publish(plr)
	hum.Died:Once(function()
		task.wait(CFG.respawn)
		if plr.Parent and plr.Character == char then
			aparecer(plr)
		end
	end)
end

Elegir.OnServerEvent:Connect(function(plr, team, class)
	local d = Data.get(plr)
	if not d then
		return
	end
	if not d.team and (team == "azul" or team == "rojo") then
		d.team = team -- el bando se elige una sola vez
		plr:SetAttribute("Bando", team)
	end
	if type(class) == "string" and Rules.CLASSES[class] then
		d.class = class -- se aplica la próxima vez que aparezcas
		plr:SetAttribute("ClaseSig", class)
	end
	if d.team and not plr.Character then
		aparecer(plr)
	end
end)

local function onPlayer(plr: Player)
	local d = Data.load(plr)
	if not d then
		return
	end
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	for _, name in { "Bajas", "Nivel" } do
		local v = Instance.new("IntValue")
		v.Name = name
		v.Parent = ls
	end
	ls.Parent = plr
	plr:SetAttribute("Bando", d.team)
	plr:SetAttribute("ClaseSig", d.class)
	publish(plr)
	plr:SetAttribute("Listo", true)
	if d.team then
		aparecer(plr) -- el que ya tiene bando entra directo a pelear
	end
end
Players.PlayerAdded:Connect(onPlayer)
for _, plr in Players:GetPlayers() do
	task.spawn(onPlayer, plr)
end
Players.PlayerRemoving:Connect(function(plr)
	cds[plr], shields[plr], spawning[plr] = nil, nil, nil
	Data.release(plr)
end)

local function addNpc(team: string)
	npcMade += 1
	local kind = Rules.npcKind(npcMade)
	local st = Rules.NPC[kind]
	local model, bar = Palito.npc(team, kind)
	local n = {
		team = team,
		kind = kind,
		x = Rules.side(team) * (CFG.castleX - 16),
		z = math.random(-25, 25),
		lane = math.random(-8, 8),
		r = 1.5,
		hp = st.hp,
		maxHp = st.hp,
		model = model,
		bar = bar,
		next = 0,
		dead = false,
	}
	model:PivotTo(CFrame.new(n.x, 2.6, n.z))
	model.Parent = npcFolder
	table.insert(npcs, n)
end

RunService.Heartbeat:Connect(function(dt)
	if state ~= "pelea" then
		return
	end
	local now = os.clock()
	-- la máquina completa cada bando
	local people = { azul = 0, rojo = 0 }
	for _, plr in Players:GetPlayers() do
		local team = plr:GetAttribute("Bando")
		if team then
			people[team] += 1
		end
	end
	local alive = { azul = 0, rojo = 0 }
	for i = #npcs, 1, -1 do
		if npcs[i].dead then
			table.remove(npcs, i)
		else
			alive[npcs[i].team] += 1
		end
	end
	for _, team in TEAMS do
		if alive[team] < Rules.npcCount(people[team], people[Rules.other(team)]) and now >= nextNpc[team] then
			nextNpc[team] = now + CFG.npcEvery
			addNpc(team)
		end
	end

	local list = targets()
	for _, n in npcs do
		if not n.dead then
			local st = Rules.NPC[n.kind]
			local mx, mz, atk = Rules.npcThink(n, list)
			local face = Vector3.new(mx, 0, mz)
			if atk > 0 then
				local t = list[atk]
				face = Vector3.new(t.x - n.x, 0, t.z - n.z)
				if now >= n.next then
					n.next = now + st.cd
					Fx:FireAllClients("linea", n.team, pos(n), pos(t))
					hurt(t, st.dmg)
				end
			else
				n.x += mx * st.speed * dt
				n.z += mz * st.speed * dt
			end
			local at = Vector3.new(n.x, 2.6, n.z)
			n.model.PrimaryPart.CFrame = if face.Magnitude > 0.01 then CFrame.lookAt(at, at + face) else CFrame.new(at)
		end
	end

	-- cada castillo se defiende: le tira al enemigo más cercano
	for _, c in castles do
		if c.hp > 0 and now >= c.next then
			c.next = now + CFG.towerEvery
			local best, bd = nil, CFG.towerRange
			for _, t in list do
				local d = math.sqrt((t.x - c.x) ^ 2 + (t.z - c.z) ^ 2)
				if t.team ~= c.team and not t.castle and not t.dead and d < bd then
					best, bd = t, d
				end
			end
			if best then
				Fx:FireAllClients("linea", c.team, Vector3.new(c.x, 22, 0), pos(best))
				hurt(best, CFG.towerDmg)
			end
		end
	end
end)

local NAMES = { azul = "AZUL", rojo = "ROJO" }
while true do
	state = "espera"
	for _, n in npcs do
		n.model:Destroy()
	end
	table.clear(npcs)
	table.clear(shields)
	for _, c in castles do
		c.hp = CFG.castleHp
		setCastle(c)
	end
	workspace:SetAttribute("Ganador", nil)
	workspace:SetAttribute("Fin", workspace:GetServerTimeNow() + CFG.countdown)
	workspace:SetAttribute("Estado", state)
	task.wait(CFG.countdown)

	state, startT = "pelea", os.clock()
	workspace:SetAttribute("Fin", workspace:GetServerTimeNow() + CFG.roundTime)
	workspace:SetAttribute("Estado", state)
	local won
	repeat
		task.wait(0.25)
		won = Rules.winner(castles.azul.hp, castles.rojo.hp, CFG.roundTime - (os.clock() - startT))
	until won

	state = "fin"
	workspace:SetAttribute("Ganador", won)
	workspace:SetAttribute("Fin", workspace:GetServerTimeNow() + CFG.endTime)
	workspace:SetAttribute("Estado", state)
	print("fin de la batalla:", won, math.floor(os.clock() - startT), "s")
	for _, plr in Players:GetPlayers() do
		local d = Data.get(plr)
		local team = plr:GetAttribute("Bando")
		if d and team then
			local win = won == team
			d.stats.play += 1
			d.stats.win += if win then 1 else 0
			local coins, xp = if win then CFG.winCoins else CFG.loseCoins, if win then CFG.winXp else CFG.loseXp
			reward(plr, coins, xp)
			local head = if won == "empate" then "Empate." elseif win then "¡Ganó tu bando!" else ("Ganó " .. NAMES[won] .. ".")
			Aviso:FireClient(plr, ("%s +%d monedas, +%d XP"):format(head, coins, xp))
		end
	end
	task.wait(CFG.endTime)
	for _, plr in Players:GetPlayers() do
		if plr.Character then
			task.spawn(aparecer, plr) -- todos vuelven a su castillo
		end
	end
end
