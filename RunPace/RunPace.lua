-- RunPace : rythme de la run + alertes (Azeroth Survivors, WoW 1.12 / Lua 5.0)
-- Lit AZS_RUN : kills, t, xp, xpn, lvl, hp, hpm, en, nb, nbn, ph
--
-- Reglages : Echap > Options > RunPace, ou /rp, ou clic droit sur le cadre
-- Commandes : /rp hp 30 | /rp ennemis 40 | /rp boss 15 | /rp test | /rp debug

RunPaceDB = RunPaceDB or {}

local defaults = { hp = 30, ennemis = 40, boss = 15, sound = 1 }
local function Cfg(k)
  local v = RunPaceDB[k]
  if v == nil then return defaults[k] end
  return v
end

local function Say(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cffffd100RunPace|r : " .. msg)
end

local function Describe(key)
  local v = Cfg(key)
  if key == "hp" then
    if v == 0 then return "alerte vie basse désactivée" end
    return "alerte vie basse : quand ta vie passe sous " .. v .. " %"
  elseif key == "ennemis" then
    if v == 0 then return "alerte ennemis désactivée" end
    return "alerte ennemis : à partir de " .. v .. " ennemis en vie"
  elseif key == "boss" then
    if v == 0 then return "alerte boss désactivée" end
    return "alerte boss : " .. v .. " s avant l'arrivée du boss"
  end
  return key
end

local ToggleConfig  -- defini avec la fenetre de reglages

------------------------------------------------------------
-- Cadre d'affichage
------------------------------------------------------------
local f = CreateFrame("Frame", "RunPaceFrame", UIParent)
f:SetWidth(200)
f:SetHeight(44)
f:SetPoint("TOP", UIParent, "TOP", 0, -140)
f:SetMovable(true)
f:EnableMouse(true)
f:RegisterForDrag("LeftButton")
f:SetBackdrop({
  bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true, tileSize = 16, edgeSize = 12,
  insets = { left = 3, right = 3, top = 3, bottom = 3 }
})
f:SetBackdropColor(0, 0, 0, 0.6)

local text = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
text:SetPoint("CENTER", f, "CENTER", 0, 0)
text:SetWidth(190)
text:SetJustifyH("CENTER")
text:SetText("RunPace")

f:SetScript("OnDragStart", function() this:StartMoving() end)
f:SetScript("OnDragStop", function()
  this:StopMovingOrSizing()
  RunPaceDB.left = this:GetLeft()
  RunPaceDB.top = this:GetTop()
end)
f:SetScript("OnMouseUp", function()
  if arg1 == "RightButton" then ToggleConfig() end
end)

------------------------------------------------------------
-- Bandeau d'alerte
------------------------------------------------------------
local banner = CreateFrame("Frame", "RunPaceBanner", UIParent)
banner:SetWidth(600)
banner:SetHeight(40)
banner:SetPoint("TOP", UIParent, "TOP", 0, -200)
banner:SetFrameStrata("FULLSCREEN_DIALOG")
local btext = banner:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
btext:SetPoint("CENTER", banner, "CENTER", 0, 0)
banner:Hide()

local bTime = 0
banner:SetScript("OnUpdate", function()
  bTime = bTime + arg1
  if bTime > 2.5 then
    this:Hide()
  elseif bTime > 1.5 then
    this:SetAlpha(1 - (bTime - 1.5))
  end
end)

local function Alert(msg, r, g, b)
  btext:SetText(msg)
  btext:SetTextColor(r, g, b)
  bTime = 0
  banner:SetAlpha(1)
  banner:Show()
  if Cfg("sound") == 1 then pcall(PlaySound, "RaidWarning") end
end

------------------------------------------------------------
-- Rythme : echantillons sur 60 s
------------------------------------------------------------
local WINDOW = 60
local samples = {}
local totalXp = 0
local lastLvl, lastXp, lastXpn = nil, nil, nil
local t0 = nil
local lastT = nil

local function Reset()
  samples = {}
  totalXp = 0
  lastLvl, lastXp, lastXpn = nil, nil, nil
  t0 = nil
end

local function TrackXp(r)
  local lvl, xp, xpn = r.lvl, r.xp, r.xpn
  if type(lvl) ~= "number" or type(xp) ~= "number" then return end
  if lastLvl == nil then
    -- premier echantillon : on part de la
  elseif lvl == lastLvl then
    if xp > lastXp then totalXp = totalXp + (xp - lastXp) end
  elseif lvl > lastLvl then
    totalXp = totalXp + ((lastXpn or 0) - lastXp) + xp
  end
  lastLvl, lastXp, lastXpn = lvl, xp, xpn
end

local function Rate(newer, older, field)
  local dt = newer.t - older.t
  if dt < 5 then return nil end
  return (newer[field] - older[field]) / dt * 60
end

local function Fmt(x)
  if x == nil then return "-" end
  return tostring(math.floor(x + 0.5))
end

------------------------------------------------------------
-- Alertes (une seule fois par "episode")
------------------------------------------------------------
local armed = { hp = true, en = true }
local alertedBoss = {}   -- un boss n'est annonce qu'une fois (cle = son nom)
local debugOn = false
local dbgT = 0

local function CheckAlerts(r)
  if r.ph ~= "playing" then return end

  local hp, hpm = r.hp, r.hpm
  local th = Cfg("hp")
  if th > 0 and type(hp) == "number" and type(hpm) == "number" and hpm > 0 then
    local pct = hp / hpm * 100
    if armed.hp and pct < th then
      armed.hp = false
      Alert("VIE BASSE : " .. math.floor(pct) .. " %", 1, 0.2, 0.2)
    elseif (not armed.hp) and pct > th + 20 then
      armed.hp = true
    end
  end

  local en = r.en
  th = Cfg("ennemis")
  if th > 0 and type(en) == "number" then
    if armed.en and en >= th then
      armed.en = false
      Alert("BEAUCOUP D'ENNEMIS : " .. en, 1, 0.6, 0)
    elseif (not armed.en) and en < math.floor(th * 0.75) then
      armed.en = true
    end
  end

  local nb = r.nb
  th = Cfg("boss")
  if th > 0 and type(nb) == "number" and type(r.nbn) == "string" and r.nbn ~= "" then
    if nb > 0 and nb <= th and not alertedBoss[r.nbn] then
      alertedBoss[r.nbn] = true
      Alert("BOSS DANS " .. math.ceil(nb) .. " s : " .. r.nbn, 1, 0.8, 0)
    end
  end
end

-- Apres un changement de reglage : on ne declenche jamais d'alerte.
local function SyncAlerts()
  armed.hp, armed.en = true, true
  local r = AZS_RUN
  if type(r) ~= "table" then return end

  local th = Cfg("hp")
  if th > 0 and type(r.hp) == "number" and type(r.hpm) == "number" and r.hpm > 0 then
    if (r.hp / r.hpm * 100) < th then armed.hp = false end
  end

  th = Cfg("ennemis")
  if th > 0 and type(r.en) == "number" and r.en >= th then armed.en = false end

  th = Cfg("boss")
  if th > 0 and type(r.nb) == "number" and type(r.nbn) == "string" then
    if r.nb > 0 and r.nb <= th then alertedBoss[r.nbn] = true end
  end
end

------------------------------------------------------------
-- Boucle principale
------------------------------------------------------------
local elapsedTotal = 0
f:SetScript("OnUpdate", function()
  elapsedTotal = elapsedTotal + arg1
  if elapsedTotal < 0.5 then return end
  elapsedTotal = 0

  local r = AZS_RUN
  if type(r) ~= "table" or type(r.t) ~= "number" or type(r.kills) ~= "number" then
    text:SetText("RunPace : en attente")
    return
  end

  -- nouvelle run : le temps repart de zero
  if lastT and r.t < lastT - 1 then
    Reset()
    armed.hp, armed.en = true, true
    alertedBoss = {}
  end
  lastT = r.t

  TrackXp(r)
  if not t0 then t0 = r.t end

  table.insert(samples, { t = r.t, k = r.kills, x = totalXp })
  while table.getn(samples) > 1 and (r.t - samples[1].t) > WINDOW do
    table.remove(samples, 1)
  end

  local newest = samples[table.getn(samples)]
  local oldest = samples[1]
  local killsNow = Rate(newest, oldest, "k")
  local xpNow = Rate(newest, oldest, "x")

  local killsAvg = nil
  if r.t > 5 then killsAvg = r.kills / r.t * 60 end
  local xpAvg = nil
  if (r.t - t0) > 5 then xpAvg = totalXp / (r.t - t0) * 60 end

  text:SetText(
    "Kills/min : " .. Fmt(killsNow) .. "  (moy " .. Fmt(killsAvg) .. ")\n" ..
    "XP/min : " .. Fmt(xpNow) .. "  (moy " .. Fmt(xpAvg) .. ")"
  )

  CheckAlerts(r)

  if debugOn then
    dbgT = dbgT + 0.5
    if dbgT >= 2 then
      dbgT = 0
      Say("debug : nb=" .. tostring(r.nb) .. " nbn=" .. tostring(r.nbn) .. " ph=" .. tostring(r.ph))
    end
  end
end)

------------------------------------------------------------
-- Reglages (partage entre la fenetre et la page des options du jeu)
------------------------------------------------------------
local refreshers = {}
local function Refresh()
  for i = 1, table.getn(refreshers) do refreshers[i]() end
end

local function SetCfg(key, n, silent)
  RunPaceDB[key] = n
  SyncAlerts()
  Refresh()
  if not silent then Say(Describe(key)) end
end

local function ResetDefaults()
  RunPaceDB.hp = defaults.hp
  RunPaceDB.ennemis = defaults.ennemis
  RunPaceDB.boss = defaults.boss
  RunPaceDB.sound = defaults.sound
  SyncAlerts()
  Refresh()
end

local HELP_TEXT =
  "|cffffd100Ce que fait RunPace|r\n" ..
  "Il affiche ton rythme de jeu pendant la run et te prévient quand il se passe quelque chose d'important.\n\n" ..
  "|cffffd100Les chiffres du cadre|r\n" ..
  "Kills/min et XP/min : ton rythme sur les 60 dernières secondes.\n" ..
  "Entre parenthèses (moy) : ta moyenne depuis le début de la run (pour l'XP : depuis que l'addon a vu la run pour la première fois).\n\n" ..
  "|cffffd100Le cadre|r\n" ..
  "Clic gauche maintenu : le déplacer. Clic droit : ouvrir la fenêtre de réglages."

local HINT_TEXT =
  "0 = alerte désactivée. Valide avec Entrée. Une alerte ne se déclenche qu'une fois, puis se réarme quand la situation redevient normale. Changer un réglage ne déclenche jamais d'alerte."

local function Commit(box)
  local key = box.key
  local n = tonumber(box:GetText())
  if n == nil then
    box:SetText(tostring(Cfg(key)))
    return
  end
  n = math.floor(n)
  if n < 0 then n = 0 end
  if n > 999 then n = 999 end
  if key == "hp" and n > 100 then n = 100 end
  if n ~= Cfg(key) then
    SetCfg(key, n, true)
  else
    box:SetText(tostring(n))
  end
end

-- une ligne : libelle, champ numerique, unite
local function MakeRow(parent, store, namePrefix, labelX, boxX, y, key, label, unit)
  local l = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  l:SetPoint("TOPLEFT", parent, "TOPLEFT", labelX, y)
  l:SetText(label)

  local e = CreateFrame("EditBox", namePrefix .. key, parent)
  e:SetWidth(50)
  e:SetHeight(22)
  e:SetPoint("TOPLEFT", parent, "TOPLEFT", boxX, y + 5)
  e:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 }
  })
  e:SetBackdropColor(0, 0, 0, 0.8)
  e:SetFontObject(ChatFontNormal)
  e:SetTextInsets(6, 6, 0, 0)
  e:SetJustifyH("CENTER")
  e:SetAutoFocus(false)
  e:SetMaxLetters(4)
  e.key = key
  e:SetScript("OnEnterPressed", function() Commit(this) this:ClearFocus() end)
  e:SetScript("OnEscapePressed", function() this:SetText(tostring(Cfg(this.key))) this:ClearFocus() end)
  e:SetScript("OnEditFocusLost", function() Commit(this) end)
  store[key] = e

  local u = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  u:SetPoint("LEFT", e, "RIGHT", 8, 0)
  u:SetText(unit)
end

local function NewButton(parent, name, width, label, onclick)
  local b = CreateFrame("Button", name, parent, "UIPanelButtonTemplate")
  b:SetWidth(width)
  b:SetHeight(24)
  b:SetText(label)
  b:SetScript("OnClick", onclick)
  return b
end

------------------------------------------------------------
-- Fenetre de reglages (/rp ou clic droit sur le cadre)
------------------------------------------------------------
local cfg = CreateFrame("Frame", "RunPaceConfig", UIParent)
cfg:SetWidth(480)
cfg:SetHeight(440)
cfg:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
cfg:SetFrameStrata("DIALOG")
cfg:SetBackdrop({
  bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
  edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
  tile = true, tileSize = 32, edgeSize = 32,
  insets = { left = 11, right = 12, top = 12, bottom = 11 }
})
cfg:EnableMouse(true)
cfg:SetMovable(true)
cfg:RegisterForDrag("LeftButton")
cfg:SetScript("OnDragStart", function() this:StartMoving() end)
cfg:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
cfg:Hide()
tinsert(UISpecialFrames, "RunPaceConfig")

local title = cfg:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOP", cfg, "TOP", 0, -18)
title:SetText("RunPace - réglages")

local closeBtn = CreateFrame("Button", nil, cfg, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", cfg, "TOPRIGHT", -5, -5)

local help = cfg:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
help:SetPoint("TOPLEFT", cfg, "TOPLEFT", 24, -48)
help:SetWidth(432)
help:SetJustifyH("LEFT")
help:SetJustifyV("TOP")
help:SetText(HELP_TEXT)

local boxes = {}
MakeRow(cfg, boxes, "RunPaceBox", 24, 290, -232, "hp", "Vie basse : alerte sous", "% de vie")
MakeRow(cfg, boxes, "RunPaceBox", 24, 290, -266, "ennemis", "Beaucoup d'ennemis : alerte à partir de", "ennemis")
MakeRow(cfg, boxes, "RunPaceBox", 24, 290, -300, "boss", "Boss : prévenir", "s avant son arrivée")

local hint = cfg:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
hint:SetPoint("TOPLEFT", cfg, "TOPLEFT", 24, -336)
hint:SetWidth(432)
hint:SetJustifyH("LEFT")
hint:SetJustifyV("TOP")
hint:SetText(HINT_TEXT)

local soundBtn = NewButton(cfg, "RunPaceSoundBtn", 140, "Son", function()
  if Cfg("sound") == 1 then RunPaceDB.sound = 0 else RunPaceDB.sound = 1 end
  Refresh()
end)
soundBtn:SetPoint("BOTTOM", cfg, "BOTTOM", -150, 22)

local testBtn = NewButton(cfg, "RunPaceTestBtn", 140, "Tester l'alerte", function()
  Alert("ALERTE DE TEST", 1, 0.8, 0)
end)
testBtn:SetPoint("BOTTOM", cfg, "BOTTOM", 0, 22)

local defBtn = NewButton(cfg, "RunPaceDefaultsBtn", 140, "Valeurs par défaut", function()
  ResetDefaults()
end)
defBtn:SetPoint("BOTTOM", cfg, "BOTTOM", 150, 22)

table.insert(refreshers, function()
  for key, e in pairs(boxes) do
    e:SetText(tostring(Cfg(key)))
  end
  soundBtn:SetText("Son : " .. (Cfg("sound") == 1 and "activé" or "désactivé"))
end)

cfg:SetScript("OnShow", function() Refresh() end)

ToggleConfig = function()
  if cfg:IsVisible() then cfg:Hide() else cfg:Show() end
end

------------------------------------------------------------
-- Categorie "RunPace" dans les options du jeu (Echap > Options)
-- Le jeu construit ses options avec des cadres nommes
-- BenillaOptionsFrameCategoryListRow<Cle> (bouton de la liste) et
-- BenillaOptionsFrameContainerBody<Cle> (page). On ajoute les notres
-- sans toucher aux tables du jeu, et on gere nous-memes l'affichage.
------------------------------------------------------------
local function BuildOptionsCategory()
  local list = BenillaOptionsFrameCategoryList
  local body = BenillaOptionsFrameContainerBody
  local keys = BENILLA_OPTIONS_CATEGORY_KEYS
  if type(list) ~= "table" or type(body) ~= "table" or type(keys) ~= "table" then
    return false, "interface des options du jeu introuvable"
  end
  local nKeys = table.getn(keys)
  if nKeys < 1 then return false, "liste des catégories vide" end

  local lastKey = keys[nKeys]
  local lastRow = getglobal("BenillaOptionsFrameCategoryListRow" .. lastKey)
  local srcBg = getglobal("BenillaOptionsFrameCategoryListRow" .. lastKey .. "Bg")
  local srcText = getglobal("BenillaOptionsFrameCategoryListRow" .. lastKey .. "Text")
  if not lastRow or not srcBg or not srcText then
    return false, "bouton de catégorie modèle introuvable"
  end

  -- la selection d'une categorie = son fond (Bg) affiche ?
  local shownCount = 0
  for i = 1, nKeys do
    local b = getglobal("BenillaOptionsFrameCategoryListRow" .. keys[i] .. "Bg")
    if b and b:IsShown() then shownCount = shownCount + 1 end
  end
  local showHide = (shownCount <= 1)

  local function CopyAnchors(dst, src, oldOwner, newOwner)
    local n = 0
    for i = 1, 6 do
      local ok, p, rel, rp, x, y = pcall(src.GetPoint, src, i)
      if not ok or p == nil then break end
      if rel == nil or rel == oldOwner then rel = newOwner end
      dst:SetPoint(p, rel, rp, x, y)
      n = n + 1
    end
    return n
  end

  ---------------- bouton dans la liste ----------------
  local row = CreateFrame("Button", "BenillaOptionsFrameCategoryListRowRunPace", list)
  row:SetWidth(lastRow:GetWidth())
  row:SetHeight(lastRow:GetHeight())
  row:SetPoint("TOPLEFT", lastRow, "BOTTOMLEFT", 0, -2)
  row.categoryKey = "RunPace"
  row.pageTitle = "RunPace"

  local bg = row:CreateTexture("BenillaOptionsFrameCategoryListRowRunPaceBg", "BACKGROUND")
  if CopyAnchors(bg, srcBg, lastRow, row) == 0 then bg:SetAllPoints(row) end
  local tex = srcBg:GetTexture()
  if type(tex) ~= "string" or tex == "Solid Texture" then
    tex = "Interface\\QuestFrame\\UI-QuestLogTitleHighlight"
  end
  bg:SetTexture(tex)
  local r, g, b, a = srcBg:GetVertexColor()
  if r then bg:SetVertexColor(r, g, b, a) end
  pcall(bg.SetBlendMode, bg, "ADD")
  if showHide then bg:Hide() else bg:Show() end

  local label = row:CreateFontString("BenillaOptionsFrameCategoryListRowRunPaceText", "ARTWORK")
  local font, size, flags = srcText:GetFont()
  if font then label:SetFont(font, size, flags) else label:SetFontObject(GameFontNormal) end
  local tr, tg, tb, ta = srcText:GetTextColor()
  if tr then label:SetTextColor(tr, tg, tb, ta) end
  if srcText.GetJustifyH then
    local okj, jh = pcall(srcText.GetJustifyH, srcText)
    if okj and jh then pcall(label.SetJustifyH, label, jh) end
  end
  if CopyAnchors(label, srcText, lastRow, row) == 0 then
    label:SetPoint("LEFT", row, "LEFT", 8, 0)
  end
  label:SetText("RunPace")

  ---------------- page ----------------
  local page = CreateFrame("Frame", "BenillaOptionsFrameContainerBodyRunPace", body)
  page:SetPoint("TOPLEFT", body, "TOPLEFT", 0, 0)
  page:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", 0, 0)
  page:Hide()

  local pageBoxes = {}
  MakeRow(page, pageBoxes, "RunPacePageBox", 14, 300, -14, "hp", "Vie basse : alerte sous", "% de vie")
  MakeRow(page, pageBoxes, "RunPacePageBox", 14, 300, -48, "ennemis", "Beaucoup d'ennemis : alerte à partir de", "ennemis")
  MakeRow(page, pageBoxes, "RunPacePageBox", 14, 300, -82, "boss", "Boss : prévenir", "s avant son arrivée")

  local soundLabel = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  soundLabel:SetPoint("TOPLEFT", page, "TOPLEFT", 14, -122)
  soundLabel:SetText("Son des alertes")

  local cb = CreateFrame("CheckButton", "RunPacePageSound", page)
  cb:SetWidth(30)
  cb:SetHeight(29)
  cb:SetPoint("TOPLEFT", page, "TOPLEFT", 290, -116)
  cb:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
  cb:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
  cb:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
  cb:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
  cb:SetDisabledCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check-Disabled")
  cb:SetScript("OnClick", function()
    if this:GetChecked() then RunPaceDB.sound = 1 else RunPaceDB.sound = 0 end
    Refresh()
  end)

  local pageTest = NewButton(page, "RunPacePageTestBtn", 140, "Tester l'alerte", function()
    Alert("ALERTE DE TEST", 1, 0.8, 0)
  end)
  pageTest:SetPoint("TOPLEFT", page, "TOPLEFT", 14, -164)

  local pageDef = NewButton(page, "RunPacePageDefaultsBtn", 170, "Valeurs par défaut", function()
    ResetDefaults()
  end)
  pageDef:SetPoint("TOPLEFT", page, "TOPLEFT", 164, -164)

  local pageHint = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  pageHint:SetPoint("TOPLEFT", page, "TOPLEFT", 14, -204)
  pageHint:SetWidth(540)
  pageHint:SetJustifyH("LEFT")
  pageHint:SetJustifyV("TOP")
  pageHint:SetText(HINT_TEXT)

  local pageHelp = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  pageHelp:SetPoint("TOPLEFT", page, "TOPLEFT", 14, -262)
  pageHelp:SetWidth(540)
  pageHelp:SetJustifyH("LEFT")
  pageHelp:SetJustifyV("TOP")
  pageHelp:SetText(HELP_TEXT)

  table.insert(refreshers, function()
    for key, e in pairs(pageBoxes) do
      e:SetText(tostring(Cfg(key)))
    end
    if Cfg("sound") == 1 then cb:SetChecked(1) else cb:SetChecked(nil) end
  end)
  Refresh()

  ---------------- selection ----------------
  local selected = false
  local defaultsWasShown, unbindWasShown = false, false

  local function KeybindingsShown()
    local p = getglobal("BenillaOptionsFrameContainerBodyKeybindings")
    return p and p:IsShown()
  end

  local function LeavePage()
    if not selected then return end
    selected = false
    page:Hide()
    if showHide then bg:Hide() end
    local d = BenillaOptionsFrameContainerDefaults
    local u = BenillaOptionsFrameContainerUnbind
    if d and defaultsWasShown and not KeybindingsShown() and not d:IsShown() then d:Show() end
    if u and unbindWasShown and KeybindingsShown() and not u:IsShown() then u:Show() end
  end

  local function SelectPage()
    if selected then return end

    -- 1. on laisse le jeu faire son menage (il selectionne la derniere categorie)
    if BenillaOptionsFrame_SelectCategory then
      pcall(BenillaOptionsFrame_SelectCategory, lastKey)
    end

    -- 2. on masque toutes les pages du jeu
    for i = 1, nKeys do
      local p = getglobal("BenillaOptionsFrameContainerBody" .. keys[i])
      if p then p:Hide() end
    end

    -- 3. apparence : notre bouton selectionne, l'ancien deselectionne
    if showHide then
      srcBg:Hide()
      bg:Show()
    end

    -- 4. titre et boutons de la page (ceux du jeu ne s'appliquent pas a notre page)
    if BenillaOptionsFrameContainerTitle then
      BenillaOptionsFrameContainerTitle:SetText("RunPace")
    end
    local d = BenillaOptionsFrameContainerDefaults
    local u = BenillaOptionsFrameContainerUnbind
    defaultsWasShown = d and d:IsShown() or false
    unbindWasShown = u and u:IsShown() or false
    if d then d:Hide() end
    if u then u:Hide() end

    Refresh()
    page:Show()
    selected = true
  end

  row:SetScript("OnClick", function() SelectPage() end)
  row:SetScript("OnEnter", function() if showHide then bg:Show() end end)
  row:SetScript("OnLeave", function() if showHide and not selected then bg:Hide() end end)

  -- si le jeu affiche une autre page, on s'efface
  local pollT = 0
  page:SetScript("OnUpdate", function()
    pollT = pollT + arg1
    if pollT < 0.2 then return end
    pollT = 0
    if not selected then return end
    for i = 1, nKeys do
      local p = getglobal("BenillaOptionsFrameContainerBody" .. keys[i])
      if p and p:IsShown() then
        LeavePage()
        return
      end
    end
  end)

  return true
end

------------------------------------------------------------
-- Commandes
------------------------------------------------------------
SLASH_RUNPACE1 = "/rp"
SLASH_RUNPACE2 = "/runpace"
SlashCmdList["RUNPACE"] = function(msg)
  msg = string.lower(msg or "")
  local _, _, cmd, num = string.find(msg, "^(%a+)%s*(%d*)")
  if cmd == nil or cmd == "config" or cmd == "options" then
    ToggleConfig()
  elseif cmd == "test" then
    Alert("ALERTE DE TEST", 1, 0.8, 0)
  elseif cmd == "debug" then
    debugOn = not debugOn
    Say("debug " .. (debugOn and "activé" or "désactivé"))
  elseif (cmd == "hp" or cmd == "ennemis" or cmd == "boss") and num ~= "" then
    local n = tonumber(num)
    if cmd == "hp" and n > 100 then n = 100 end
    SetCfg(cmd, n)
  else
    Say("réglages : Échap > Options > RunPace, ou /rp, ou clic droit sur le cadre")
    Say("raccourcis : /rp hp 30, /rp ennemis 40, /rp boss 15 (0 = désactivé), /rp test")
  end
end

local optionsBuilt = false
f:RegisterEvent("VARIABLES_LOADED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function()
  if event == "VARIABLES_LOADED" then
    if RunPaceDB.left and RunPaceDB.top then
      this:ClearAllPoints()
      this:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", RunPaceDB.left, RunPaceDB.top)
    end
  elseif event == "PLAYER_ENTERING_WORLD" and not optionsBuilt then
    optionsBuilt = true
    local ok, res, why = pcall(BuildOptionsCategory)
    if not ok then
      Say("impossible d'ajouter RunPace aux options du jeu (" .. tostring(res) .. "). La fenêtre /rp reste disponible.")
    elseif res == false then
      Say("impossible d'ajouter RunPace aux options du jeu (" .. tostring(why) .. "). La fenêtre /rp reste disponible.")
    end
  end
end)
