local actionSlotWithFlashHeal = 1
local lichtblitzSchwelle = 1
local heiligesLichtSchwelle = 1500
local unitToHeal = "nobody"
local ignoreTime = 10 -- Sekunden
local ignoreList = {}

--TODO prüfen ob auf Slot 1 auch Lichtblitz ist ansonsten fehler ausgeben

function PallyPump()
	if GetActionTexture(actionSlotWithFlashHeal) == "Interface\\Icons\\Spell_Holy_FlashHeal" and ActionHasRange(actionSlotWithFlashHeal) == 1 then
		cleanLosList()
		-- Göttliche Gunst  0 = kein CD
		-- Göttliche Gunst -1 = Buff ist Aktiv (CD wird erst gestartet wenn verbraucht)
		-- Göttliche Gunst >0 = hat noch CD
		local gg = getCooldown("Göttliche Gunst")
	
		setUnitToHeal()
		--if unitToHeal ~= "nobody" then
			--DEFAULT_CHAT_FRAME:AddMessage(UnitName(unitToHeal).." wird geheilt.")
		--else
			--DEFAULT_CHAT_FRAME:AddMessage("Niemand braucht Heilung.")
		--end
	
		if unitToHeal ~= "nobody" then
			local max_health = UnitHealthMax(unitToHeal)
			local health = UnitHealth(unitToHeal)
			local diff = max_health-health
			if diff >= heiligesLichtSchwelle then
				if gg == 0 then
					CastSpellByName("G\195\182ttliche Gunst")
				elseif gg == -1 then
					TargetUnit(unitToHeal)
					CastSpellByName("Heiliges Licht")
					TargetLastTarget()
				else
					TargetUnit(unitToHeal)
					CastSpellByName("Lichtblitz")
					TargetLastTarget()				
				end
			elseif diff >= lichtblitzSchwelle then
				TargetUnit(unitToHeal)
				CastSpellByName("Lichtblitz")
				TargetLastTarget()
			end
		end
	else
		DEFAULT_CHAT_FRAME:AddMessage("PallyPump konnte auf Slot "..actionSlotWithFlashHeal.." kein Lichtblitz finden." , 1.0, 0.0, 0.0)
	end
	--DEFAULT_CHAT_FRAME:AddMessage("Debug")
end

function getCooldown(pSpell)
	local i = 1
	while true do
		local spellName, spellRank = GetSpellName(i, BOOKTYPE_SPELL)
		if not spellName then
			do break end
		end
		if spellName == pSpell then
			local start, duration, enabled = GetSpellCooldown(i, BOOKTYPE_SPELL)
			if enabled == 0 then
				-- Der Zauber ist gerade aktiv. Der CD startet erst wenn er verbraucht wurde.
				return -1
			elseif ( start > 0 and duration > 0) then
				-- Der Zauber hat CD.
				return start + duration - GetTime()
			else
				-- Der Zauber hat keinen CD und kann genutzt werden.
				return 0
			end
		end
		i = i + 1
	end
end

function setUnitToHeal()
	unitToHeal = "nobody"
	local healthToHeal = 0
	if UnitInRaid("player") then
		-- Der Spieler ist in einem Raid.
		for raidIndex = 1, MAX_RAID_MEMBERS do
			if GetRaidRosterInfo(raidIndex) then
				local max_health = UnitHealthMax("raid"..raidIndex)
				local health = UnitHealth("raid"..raidIndex)
				--local name = UnitName("raid"..raidIndex)
				TargetUnit("raid"..raidIndex)
				inRange = IsActionInRange(actionSlotWithFlashHeal)
				if max_health-health > healthToHeal and not UnitIsDead("raid"..raidIndex) and not UnitIsGhost("raid"..raidIndex) and UnitIsConnected("raid"..raidIndex) and UnitIsVisible("raid"..raidIndex) and inRange == 1 and ignoreList[UnitName("raid"..raidIndex)] == nil then
					healthToHeal = max_health-health
					unitToHeal = "raid"..raidIndex
				end
				TargetLastTarget()
				--DEFAULT_CHAT_FRAME:AddMessage(raidIndex..": "..name.." ("..health.."/"..max_health..") = "..max_health-health)			
			end
		end
	elseif GetNumPartyMembers() > 0 then
		-- Der Spieler ist in einer Gruppe.
		for groupIndex = 1, MAX_PARTY_MEMBERS do
			if GetPartyMember(groupIndex) then
				local max_health = UnitHealthMax("party"..groupIndex)
				local health = UnitHealth("party"..groupIndex)
				--local name = UnitName("party"..groupIndex)
				TargetUnit("party"..groupIndex)
				inRange = IsActionInRange(actionSlotWithFlashHeal)
				if max_health-health > healthToHeal and not UnitIsDead("party"..groupIndex) and not UnitIsGhost("party"..groupIndex) and UnitIsConnected("party"..groupIndex) and UnitIsVisible("party"..groupIndex) and inRange == 1 and ignoreList[UnitName("party"..groupIndex)] == nil then
					healthToHeal = max_health-health
					unitToHeal = "party"..groupIndex
				end
				TargetLastTarget()
				--DEFAULT_CHAT_FRAME:AddMessage(groupIndex..": "..name.." ("..health.."/"..max_health..") = "..max_health-health)
			end
		end
		-- Man muss sich selbst noch überprüfen, weil man mit getPartyMember nur alle anderen Mitglieder der Gruppe bekommt
		local max_health = UnitHealthMax("player")
		local health = UnitHealth("player")
		--local name = UnitName("player")
		if max_health-health > healthToHeal then
			healthToHeal = max_health-health
			unitToHeal = "player"
		end
		--DEFAULT_CHAT_FRAME:AddMessage("?: "..name.." ("..health.."/"..max_health..") = "..max_health-health)
	else
		-- Der Spieler ist allein.
		if UnitHealthMax("player")-UnitHealth("player") > 0 then
			unitToHeal = "player"
		end
	end
end

function PallyPump_OnEvent()
	if event == "UI_ERROR_MESSAGE" and arg1 == "Ziel ist nicht im Sichtfeld." then
		--DEFAULT_CHAT_FRAME:AddMessage(UnitName(unitToHeal).." - "..arg1)
		SendChatMessage("Du bist nicht im Sichtfeld und somit 10 Sekunden auf Heal-Ignore", "WHISPER", nil, UnitName(unitToHeal))
		ignoreList[UnitName(unitToHeal)] = time()
		DEFAULT_CHAT_FRAME:AddMessage(UnitName(unitToHeal).." wird für "..ignoreTime.." Sekunden ignoriert.")
	end
end

function cleanLosList()
	local i = 0
	for key,value in pairs(ignoreList) do
		-- Wenn der Spieler seit x Sekunden oder mehr auf der Ignoreliste war wird er von dieser entfernt
		if time() - value >= ignoreTime then
			ignoreList[key] = nil
			DEFAULT_CHAT_FRAME:AddMessage(key.." wird nun nicht mehr ignoriert.")
		end
		i = i + 1
	end
end

local PallyPumpFrame = CreateFrame("FRAME", nil, UIParent)
PallyPumpFrame:Hide()
PallyPumpFrame:SetScript("OnEvent", PallyPump_OnEvent)
PallyPumpFrame:RegisterEvent("UNIT_SPELLCAST_SENT")
PallyPumpFrame:RegisterEvent("UNIT_SPELLCAST_FAILED")
PallyPumpFrame:RegisterEvent("UNIT_SPELLCAST_FAILED_QUIET")
PallyPumpFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
PallyPumpFrame:RegisterEvent("UNIT_SPELLCAST_STOP")
PallyPumpFrame:RegisterEvent("UNIT_SPELLCAST_CHANNELED_STOP")
PallyPumpFrame:RegisterEvent("UI_ERROR_MESSAGE")