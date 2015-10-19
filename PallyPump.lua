local actionSlotWithFlashHeal = 0
local actionSlotWithHolyLight = 0
local lichtblitzSchwelle = 1
local heiligesLichtSchwelle = 1500
local unitToHeal = "nobody"
local ignoreTime = 10 -- Sekunden
local ignoreList = {}
local debugMode = true
local isWorking = false
local isCasting = false

function PallyPump()
	for i = 1, 108 do
		if GetActionTexture(i) == "Interface\\Icons\\Spell_Holy_FlashHeal" and GetActionText(i) == nil then
			actionSlotWithFlashHeal = i
		end
		if GetActionTexture(i) == "Interface\\Icons\\Spell_Holy_HolyBolt" and GetActionText(i) == nil then
			actionSlotWithHolyLight = i
		end
	end
	if actionSlotWithFlashHeal == 0 then
		DEFAULT_CHAT_FRAME:AddMessage("PallyPump konnte Lichtblitz nicht in der Aktionsleiste finden.", 1.0, 0.0, 0.0)
	end
	if actionSlotWithHolyLight == 0 then
		DEFAULT_CHAT_FRAME:AddMessage("PallyPump konnte Heiliges Licht nicht in der Aktionsleiste finden.", 1.0, 0.0, 0.0)
	end	
	isFlashHealCurrent = IsCurrentAction(actionSlotWithFlashHeal)
	isHolyLightCurrent = IsCurrentAction(actionSlotWithHolyLight)
	if isFlashHealCurrent == 1 or isHolyLightCurrent == 1 then
		isCasting = true
	else
		isCasting = false
	end
	if isWorking == false and isCasting == false then
		isWorking = true
	else
		return
	end

	cleanLosList()
	-- Göttliche Gunst  0 = kein CD
	-- Göttliche Gunst -1 = Buff ist Aktiv (CD wird erst gestartet wenn verbraucht)
	-- Göttliche Gunst >0 = hat noch CD
	local gg = getCooldown("Göttliche Gunst")
	
	setUnitToHeal()
	if unitToHeal == "nobody" and debugMode then
		UIErrorsFrame:AddMessage("Niemand braucht Heilung.", 1.0, 1.0, 1.0, nil, 5)
		PlaySound("igAbilityIconDrop", "master")
	end
	
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
			if gg == -1 then
				TargetUnit(unitToHeal)
				CastSpellByName("Heiliges Licht")
				TargetLastTarget()
			else
				TargetUnit(unitToHeal)
				CastSpellByName("Lichtblitz")
				TargetLastTarget()
			end
		end
	end
	isWorking = false
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

function cleanLosList()
	for key,value in pairs(ignoreList) do
		-- Wenn der Spieler seit x Sekunden oder mehr auf der Ignoreliste war wird er von dieser entfernt
		if time() - value >= ignoreTime then
			ignoreList[key] = nil
			UIErrorsFrame:AddMessage(key.." wird nun nicht mehr ignoriert.", 0.0, 1.0, 0.0, nil, 5)
		end
	end
end

function deleteAllPlayerFromIgnoreList()
	for key,value in pairs(ignoreList) do
		ignoreList[key] = nil
		UIErrorsFrame:AddMessage(key.." wird nun nicht mehr ignoriert.", 0.0, 1.0, 0.0, nil, 5)
	end
end

function skillHoly()
	-- Heilig
	-- Göttliche Weisheit 5/5
	name, iconPath, tier, column, currentRank, maxRank, isExceptional, meetsPrereq = GetTalentInfo(1, 2)
	if currentRank < 5 then LearnTalent(1, 2) end
	-- Spiritueller Fokus 5/5
	name, iconPath, tier, column, currentRank, maxRank, isExceptional, meetsPrereq = GetTalentInfo(1, 3)
	if currentRank < 5 then LearnTalent(1, 3) end
	-- Heilendes Licht 3/3
	name, iconPath, tier, column, currentRank, maxRank, isExceptional, meetsPrereq = GetTalentInfo(1, 5)
	if currentRank < 3 then LearnTalent(1, 5) end
	-- Weihe 1/1
	name, iconPath, tier, column, currentRank, maxRank, isExceptional, meetsPrereq = GetTalentInfo(1, 6)
	if currentRank < 1 then LearnTalent(1, 6) end
	-- Unumstößlicher Glaube 2/2
	name, iconPath, tier, column, currentRank, maxRank, isExceptional, meetsPrereq = GetTalentInfo(1, 8)
	if currentRank < 2 then LearnTalent(1, 8) end
	-- Illumination 5/5
	name, iconPath, tier, column, currentRank, maxRank, isExceptional, meetsPrereq = GetTalentInfo(1, 9)
	if currentRank < 5 then LearnTalent(1, 9) end
	-- Verbesserter Segen der Weisheit 2/2
	name, iconPath, tier, column, currentRank, maxRank, isExceptional, meetsPrereq = GetTalentInfo(1, 10)
	if currentRank < 2 then LearnTalent(1, 10) end
	-- Göttliche Gunst 1/1
	name, iconPath, tier, column, currentRank, maxRank, isExceptional, meetsPrereq = GetTalentInfo(1, 11)
	if currentRank < 1 then LearnTalent(1, 11) end
	-- Dauerhaftes Richturteil 3/3
	name, iconPath, tier, column, currentRank, maxRank, isExceptional, meetsPrereq = GetTalentInfo(1, 12)
	if currentRank < 3 then LearnTalent(1, 12) end
	-- Heilige Macht 5/5
	name, iconPath, tier, column, currentRank, maxRank, isExceptional, meetsPrereq = GetTalentInfo(1, 13)
	if currentRank < 5 then LearnTalent(1, 13) end
	-- Heiliger Schock 1/1
	name, iconPath, tier, column, currentRank, maxRank, isExceptional, meetsPrereq = GetTalentInfo(1, 14)
	if currentRank < 1 then LearnTalent(1, 14) end
	
	-- Schutz
	-- Verbesserte Aura der Hingabe 5/5
	name, iconPath, tier, column, currentRank, maxRank, isExceptional, meetsPrereq = GetTalentInfo(2, 1)
	if currentRank < 5 then LearnTalent(2, 1) end
	-- Präzision 3/3
	name, iconPath, tier, column, currentRank, maxRank, isExceptional, meetsPrereq = GetTalentInfo(2, 3)
	if currentRank < 3 then LearnTalent(2, 3) end
	-- Gunst des Hüters 2/2
	name, iconPath, tier, column, currentRank, maxRank, isExceptional, meetsPrereq = GetTalentInfo(2, 4)
	if currentRank < 2 then LearnTalent(2, 4) end
	-- Segen der Könige 1/1
	name, iconPath, tier, column, currentRank, maxRank, isExceptional, meetsPrereq = GetTalentInfo(2, 6)
	if currentRank < 1 then LearnTalent(2, 6) end
	
	-- Vergeltung
	-- Verbesserter Segen der Macht 5/5
	name, iconPath, tier, column, currentRank, maxRank, isExceptional, meetsPrereq = GetTalentInfo(3, 1)
	if currentRank < 5 then LearnTalent(3, 1) end
	-- Verbessertes Richturteil 2/2
	name, iconPath, tier, column, currentRank, maxRank, isExceptional, meetsPrereq = GetTalentInfo(3, 3)
	if currentRank < 2 then LearnTalent(3, 3) end
	
	-- Skills in die Leiste packen
	-- Weihe Rang 5
	name, iconPath, tier, column, currentRank, maxRank, isExceptional, meetsPrereq = GetTalentInfo(1, 6)
	if currentRank == 1 and HasAction(27) == nil then
		PickupSpell(getSpellId("Weihe", "Rang 5"), BOOKTYPE_SPELL)
		PlaceAction(27)
	end
	-- Heiliger Schock
	name, iconPath, tier, column, currentRank, maxRank, isExceptional, meetsPrereq = GetTalentInfo(1, 14)
	if currentRank == 1 and HasAction(4) == nil then
		PickupSpell(getSpellId("Heiliger Schock", "Rang 3"), BOOKTYPE_SPELL)
		PlaceAction(4)
	end
	-- Segen der Könige und Großer Segen der Könige
	name, iconPath, tier, column, currentRank, maxRank, isExceptional, meetsPrereq = GetTalentInfo(2, 6)
	if currentRank == 1 then
		if HasAction(12) == nil then
			PickupSpell(getSpellId("Segen der K\195\182nige", ""), BOOKTYPE_SPELL)
			PlaceAction(12)
		end
		if HasAction(22) == nil then
			PickupSpell(getSpellId("Gro\195\159er Segen der K\195\182nige", ""), BOOKTYPE_SPELL)
			PlaceAction(22)
		end
	end
end

function skillRetribution()
end

function skillProtection()
end

function getSpellId(pSpellName, pSpellRank)
	local i = 1
	while true do
		local spellName, spellRank = GetSpellName(i, BOOKTYPE_SPELL)
		if not spellName then
			do break end
		end
		if spellName == pSpellName and spellRank == pSpellRank then
			return i
		end
		i = i + 1
	end
end

function PallyPump_OnEvent()
	if event == "UI_ERROR_MESSAGE" and arg1 == "Ziel ist nicht im Sichtfeld." and unitToHeal ~= "nobody" then
		--DEFAULT_CHAT_FRAME:AddMessage(UnitName(unitToHeal).." - "..arg1)
		--SendChatMessage("Du bist nicht im Sichtfeld und somit 10 Sekunden auf Heal-Ignore", "WHISPER", nil, UnitName(unitToHeal))
		ignoreList[UnitName(unitToHeal)] = time()
		UIErrorsFrame:AddMessage(UnitName(unitToHeal).." wird für "..ignoreTime.." Sekunden ignoriert.", 1.0, 0.0, 0.0, nil, 5)
		PlaySound("igQuestFailed", "master")
	end
end

local PallyPumpFrame = CreateFrame("FRAME", nil, UIParent)
PallyPumpFrame:Hide()
PallyPumpFrame:SetScript("OnEvent", PallyPump_OnEvent)
PallyPumpFrame:RegisterEvent("UI_ERROR_MESSAGE")

function PallyLog_OnEvent()
	local value = 0
	for attacktype, creaturename, damage in string.gfind(arg1, "Kritische Heilung: (.+) heilt (.+) um (%d+) Punkte.") do
		value = damage
	end
	for attacktype, creaturename, damage in string.gfind(arg1, "(.+) heilt (.+) um (%d+) Punkte.") do
		value = damage
	end
	if unitToHeal ~= "nobody" and debugMode then
		local need = UnitHealthMax(unitToHeal)-UnitHealth(unitToHeal)
		if need > tonumber(value) then
			DEFAULT_CHAT_FRAME:AddMessage(UnitName(unitToHeal).." braucht "..need.." HP. "..value.." geheilt. Er braucht noch "..need-value.." HP.", 0.0, 1.0, 0.0)
		elseif need < tonumber(value) then
			DEFAULT_CHAT_FRAME:AddMessage(UnitName(unitToHeal).." braucht "..need.." HP. "..value.." geheilt. "..value-need.." HP überheilt.", 0.0, 1.0, 0.0)
		else
			DEFAULT_CHAT_FRAME:AddMessage(UnitName(unitToHeal).." braucht "..need.." HP. "..value.." geheilt.", 0.0, 1.0, 0.0)
		end
	end
end

local PallyLogFrame = CreateFrame("FRAME", nil, UIParent)
PallyLogFrame:Hide()
PallyLogFrame:SetScript("OnEvent", PallyLog_OnEvent)
PallyLogFrame:RegisterEvent("CHAT_MSG_SPELL_SELF_BUFF")