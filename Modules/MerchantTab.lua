-- ------------------------------------------------------------------------------ --
--                          TradeSkillMaster_Merchant                             --
--                                                                               --
--             MerchantTab: Frame creation, hooking, Default UI toggle            --
-- ------------------------------------------------------------------------------ --

local TSM = select(2, ...)
local MerchantTab = TSM:NewModule("MerchantTab", "AceEvent-3.0", "AceHook-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("TradeSkillMaster_Merchant")

local private = {}

-- Default MerchantFrame elements to hide/show when toggling
local defaultElements = {
	-- Item slots
	"MerchantItem1", "MerchantItem2", "MerchantItem3", "MerchantItem4",
	"MerchantItem5", "MerchantItem6", "MerchantItem7", "MerchantItem8",
	"MerchantItem9", "MerchantItem10", "MerchantItem11", "MerchantItem12",
	-- Navigation
	"MerchantNextPageButton", "MerchantPrevPageButton",
	-- Repair
	"MerchantRepairItemButton", "MerchantRepairAllIcon", "MerchantGuildBankRepairButton",
	-- Buyback
	"MerchantBuyBackItem",
	-- Text/UI
	"MerchantPageText", "MerchantNameText", "MerchantRepairText",
	-- Money
	"MerchantMoneyFrame",
	-- Close button
	"MerchantFrameCloseButton",
	-- Portrait
	"MerchantFramePortrait",
}

function MerchantTab:OnEnable()
	MerchantTab:RegisterEvent("MERCHANT_SHOW", function()
		TSMAPI:CreateTimeDelay("merchantShowDelay", 0, private.OnMerchantShow)
	end)
	MerchantTab:RegisterEvent("MERCHANT_CLOSED", function()
		if private.frame and private.frame.searchBox then
			private.frame.searchBox:SetText("")
		end
		TSM.ItemList:SetSearchFilter("")
		-- Reset MerchantFrame to default size so the default UI isn't permanently resized
		if private.defaultWidth and private.defaultHeight then
			MerchantFrame:SetWidth(private.defaultWidth)
			MerchantFrame:SetHeight(private.defaultHeight)
		end
	end)
end

function private:OnMerchantShow()
	private.frame = private.frame or private:CreateMerchantTab()
	if TSM.db.global.defaultMerchantTab then
		for i = 1, MerchantFrame.numTabs do
			if _G["MerchantFrameTab" .. i] and _G["MerchantFrameTab" .. i].isTSMTab then
				_G["MerchantFrameTab" .. i]:Click()
				break
			end
		end
	end
end

function private:HideDefaultElements()
	for _, name in ipairs(defaultElements) do
		local element = _G[name]
		if element then element:Hide() end
	end
end

function private:ShowDefaultElements()
	for _, name in ipairs(defaultElements) do
		local element = _G[name]
		if element then element:Show() end
	end
end

function private:CreateMerchantTab()
	local frame = CreateFrame("Frame", nil, MerchantFrame)
	TSMAPI.Design:SetFrameBackdropColor(frame)
	frame:Hide()
	frame:SetPoint("TOPLEFT")
	frame:SetPoint("BOTTOMRIGHT")
	frame:SetFrameLevel(MerchantFrame:GetFrameLevel() + 10)
	frame:EnableMouse(true)

	-- Tab switching callbacks
	local function OnTabClick(self)
		PanelTemplates_SetTab(MerchantFrame, self:GetID())
		-- Hide default merchant content
		MerchantFrameTab1:Hide()
		MerchantFrameTab2:Hide()
		self:Hide()
		private:HideDefaultElements()
		private.frame:Show()
	end

	local function OnOtherTabClick()
		if not private.frame then return end
		private.frame:Hide()
		private.frame.tab:Show()
		MerchantFrameTab1:Show()
		MerchantFrameTab2:Show()
		private:ShowDefaultElements()
		-- Reset size for default UI
		if private.defaultWidth and private.defaultHeight then
			MerchantFrame:SetWidth(private.defaultWidth)
			MerchantFrame:SetHeight(private.defaultHeight)
		end
		MerchantFrameTab1:Click()
	end

	-- Add TSM tab to MerchantFrame
	local n = MerchantFrame.numTabs + 1
	local tab = CreateFrame("Button", "MerchantFrameTab" .. n, MerchantFrame, "FriendsFrameTabTemplate")
	tab:Hide()
	tab:SetID(n)
	tab:SetText(TSMAPI.Design:GetInlineColor("link2") .. "TSM_Merchant|r")
	tab:SetNormalFontObject(GameFontHighlightSmall)
	tab.isTSMTab = true
	tab:SetPoint("LEFT", _G["MerchantFrameTab" .. (n - 1)], "RIGHT", -8, 0)
	tab:Show()
	tab:SetScript("OnClick", OnTabClick)
	PanelTemplates_SetNumTabs(MerchantFrame, n)
	PanelTemplates_EnableTab(MerchantFrame, n)
	frame.tab = tab

	-- Header: Title
	local title = TSMAPI.GUI:CreateLabel(frame)
	title:SetPoint("TOPLEFT", 5, -5)
	title:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", -5, -25)
	title:SetJustifyH("CENTER")
	title:SetJustifyV("CENTER")
	title:SetText("TSM_Merchant - v" .. TSM._version)

	-- Header: Close button (X)
	local closeBtn = TSMAPI.GUI:CreateButton(frame, 19)
	closeBtn:SetPoint("TOPRIGHT", -5, -5)
	closeBtn:SetWidth(20)
	closeBtn:SetHeight(20)
	closeBtn:SetText("X")
	closeBtn:SetScript("OnClick", CloseMerchant)

	-- Header: Default UI switch button
	local switchBtn = TSMAPI.GUI:CreateButton(frame, 15)
	switchBtn:SetPoint("TOPRIGHT", closeBtn, "TOPLEFT", -4, 0)
	switchBtn:SetHeight(20)
	switchBtn:SetWidth(85)
	switchBtn:SetText(L["Default UI"])
	switchBtn:SetScript("OnClick", OnOtherTabClick)
	frame.switchBtn = switchBtn

	-- Header decorative lines
	local line = TSMAPI.GUI:CreateVerticalLine(frame, 0)
	line:ClearAllPoints()
	line:SetPoint("TOPRIGHT", -30, -1)
	line:SetWidth(2)
	line:SetHeight(30)
	TSMAPI.GUI:CreateHorizontalLine(frame, -30)

	-- Make MerchantFrame resizable
	MerchantFrame:SetResizable(true)
	MerchantFrame:SetMinResize(336, 357)
	MerchantFrame:SetMaxResize(800, 600)
	private.defaultWidth = MerchantFrame:GetWidth()
	private.defaultHeight = MerchantFrame:GetHeight()

	-- Resize handle (bottom-right corner, only visible on TSM tab)
	local resizeHandle = CreateFrame("Frame", nil, frame)
	resizeHandle:SetSize(16, 16)
	resizeHandle:SetPoint("BOTTOMRIGHT", -1, 1)
	resizeHandle:EnableMouse(true)
	resizeHandle:SetScript("OnMouseDown", function()
		MerchantFrame:StartSizing("BOTTOMRIGHT")
	end)
	resizeHandle:SetScript("OnMouseUp", function()
		MerchantFrame:StopMovingOrSizing()
	end)
	local gripTex = resizeHandle:CreateTexture(nil, "OVERLAY")
	gripTex:SetAllPoints()
	gripTex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
	resizeHandle:SetScript("OnEnter", function()
		gripTex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
	end)
	resizeHandle:SetScript("OnLeave", function()
		gripTex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
	end)

	-- Placeholder buttons
	private:CreatePlaceholderButtons(frame)

	return frame
end

function private:CreatePlaceholderButtons(frame)
	-- btn1: Open Wishlist (unchanged)
	local btn1 = TSMAPI.GUI:CreateButton(frame, 15)
	btn1:SetPoint("TOPLEFT", 5, -40)
	btn1:SetHeight(20)
	btn1:SetWidth(100)
	btn1:SetText(L["Open Wishlist"])
	btn1:SetScript("OnClick", function() TSM:ToggleWishlistWindow() end)
	frame.btn1 = btn1

	-- btn2: Filters toggle (opens side panel)
	local btn2 = TSMAPI.GUI:CreateButton(frame, 15)
	btn2:SetPoint("TOPLEFT", btn1, "TOPRIGHT", 5, 0)
	btn2:SetHeight(20)
	btn2:SetWidth(90)
	btn2:SetText(L["Filters"])
	btn2:SetScript("OnClick", function()
		private:ToggleFiltersPanel(frame)
	end)
	frame.btn2 = btn2

	-- btn3: Search input
	local searchBox = TSMAPI.GUI:CreateInputBox(frame)
	searchBox:SetPoint("TOPLEFT", btn2, "TOPRIGHT", 5, 0)
	searchBox:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -40)
	searchBox:SetHeight(20)
	searchBox:SetTextInsets(5, 5, 0, 0)
	searchBox:SetScript("OnTextChanged", function(self)
		TSM.ItemList:SetSearchFilter(self:GetText())
	end)
	searchBox:SetScript("OnEscapePressed", function(self)
		self:SetText("")
		self:ClearFocus()
	end)
	local placeholder = searchBox:CreateFontString(nil, "OVERLAY")
	placeholder:SetFont(TSMAPI.Design:GetContentFont("small"))
	placeholder:SetPoint("LEFT", 5, 0)
	placeholder:SetText(L["Search..."])
	placeholder:SetTextColor(0.5, 0.5, 0.5, 0.8)
	searchBox.placeholder = placeholder
	searchBox:SetScript("OnEditFocusGained", function(self)
		self.placeholder:Hide()
	end)
	searchBox:SetScript("OnEditFocusLost", function(self)
		if self:GetText() == "" then self.placeholder:Show() end
	end)
	frame.searchBox = searchBox

	TSMAPI.GUI:CreateHorizontalLine(frame, -70)

	-- Content area for the item list
	local content = CreateFrame("Frame", nil, frame)
	content:SetPoint("TOPLEFT", 0, -70)
	content:SetPoint("BOTTOMRIGHT")

	frame.itemListTab = TSM.ItemList:CreateTab(content)
end

function private:ToggleFiltersPanel(frame)
	if not private.filtersPanel then
		private:CreateFiltersPanel(frame)
	end
	if private.filtersPanel:IsShown() then
		private.filtersPanel:Hide()
	else
		private:SyncFiltersPanelState()
		private.filtersPanel:Show()
	end
end

function private:CreateFiltersPanel(parent)
	local panel = CreateFrame("Frame", nil, parent)
	panel:SetFrameStrata("HIGH")
	panel:SetFrameLevel(parent:GetFrameLevel() + 20)
	panel:SetWidth(220)
	panel:SetHeight(175)
	panel:SetPoint("TOPLEFT", parent, "TOPRIGHT", 2, 0)
	TSMAPI.Design:SetFrameBackdropColor(panel)

	-- Title
	local title = TSMAPI.GUI:CreateLabel(panel)
	title:SetPoint("TOPLEFT", 5, -5)
	title:SetPoint("TOPRIGHT", -5, -5)
	title:SetHeight(20)
	title:SetJustifyH("CENTER")
	title:SetText(L["Filters"])

	TSMAPI.GUI:CreateHorizontalLine(panel, -28)

	-- Show Out of Stock checkbox
	local cbStock = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
	cbStock:SetSize(22, 22)
	cbStock:SetPoint("TOPLEFT", 8, -38)
	cbStock:SetHitRectInsets(0, -150, 0, 0)
	cbStock:SetChecked(TSM.db.global.showOutOfStock)
	cbStock:SetScript("OnClick", function(self)
		TSM.db.global.showOutOfStock = self:GetChecked() and true or false
		TSM.ItemList:RefreshDisplay()
	end)
	local lblStock = TSMAPI.GUI:CreateLabel(panel, "small")
	lblStock:SetPoint("LEFT", cbStock, "RIGHT", 4, 0)
	lblStock:SetHeight(22)
	lblStock:SetWidth(170)
	lblStock:SetJustifyH("LEFT")
	lblStock:SetJustifyV("CENTER")
	lblStock:SetText(L["Show Out of Stock"])
	panel.cbStock = cbStock

	-- Hide under X tokens checkbox
	local cbHide = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
	cbHide:SetSize(22, 22)
	cbHide:SetPoint("TOPLEFT", cbStock, "BOTTOMLEFT", 0, -4)
	cbHide:SetHitRectInsets(0, -150, 0, 0)
	cbHide:SetChecked(TSM.db.global.hideUnderTokensEnabled)
	cbHide:SetScript("OnClick", function(self)
		TSM.db.global.hideUnderTokensEnabled = self:GetChecked() and true or false
		TSM.ItemList:RefreshDisplay()
	end)
	local lblHide = TSMAPI.GUI:CreateLabel(panel, "small")
	lblHide:SetPoint("LEFT", cbHide, "RIGHT", 4, 0)
	lblHide:SetHeight(22)
	lblHide:SetWidth(170)
	lblHide:SetJustifyH("LEFT")
	lblHide:SetJustifyV("CENTER")
	lblHide:SetText(L["Hide under X Bazaar tokens"])
	panel.cbHide = cbHide

	-- Threshold input box (indented under the Hide checkbox)
	local input = TSMAPI.GUI:CreateInputBox(panel)
	input:SetPoint("TOPLEFT", cbHide, "BOTTOMLEFT", 26, -4)
	input:SetWidth(80)
	input:SetHeight(20)
	input:SetTextInsets(5, 5, 0, 0)
	input:SetNumeric(true)
	input:SetMaxLetters(6)
	input:SetText(tostring(TSM.db.global.hideUnderTokensThreshold or 1500))
	input:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	input:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	input:SetScript("OnEditFocusLost", function(self)
		local n = tonumber(self:GetText())
		if not n or n < 0 then n = 0 end
		TSM.db.global.hideUnderTokensThreshold = n
		self:SetText(tostring(n))
		if TSM.db.global.hideUnderTokensEnabled then
			TSM.ItemList:RefreshDisplay()
		end
	end)
	panel.input = input

	-- Group by category checkbox
	local cbGroup = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
	cbGroup:SetSize(22, 22)
	cbGroup:SetPoint("TOPLEFT", input, "BOTTOMLEFT", -26, -6)
	cbGroup:SetHitRectInsets(0, -150, 0, 0)
	cbGroup:SetChecked(TSM.db.global.groupByCategory)
	cbGroup:SetScript("OnClick", function(self)
		TSM.db.global.groupByCategory = self:GetChecked() and true or false
		TSM.ItemList:RefreshDisplay()
	end)
	local lblGroup = TSMAPI.GUI:CreateLabel(panel, "small")
	lblGroup:SetPoint("LEFT", cbGroup, "RIGHT", 4, 0)
	lblGroup:SetHeight(22)
	lblGroup:SetWidth(170)
	lblGroup:SetJustifyH("LEFT")
	lblGroup:SetJustifyV("CENTER")
	lblGroup:SetText(L["Group by category"])
	panel.cbGroup = cbGroup

	-- Hide already possessed items checkbox
	local cbOwned = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
	cbOwned:SetSize(22, 22)
	cbOwned:SetPoint("TOPLEFT", cbGroup, "BOTTOMLEFT", 0, -4)
	cbOwned:SetHitRectInsets(0, -170, 0, 0)
	cbOwned:SetChecked(TSM.db.global.hideOwned)
	cbOwned:SetScript("OnClick", function(self)
		TSM.db.global.hideOwned = self:GetChecked() and true or false
		TSM.ItemList:RefreshDisplay()
	end)
	local lblOwned = TSMAPI.GUI:CreateLabel(panel, "small")
	lblOwned:SetPoint("LEFT", cbOwned, "RIGHT", 4, 0)
	lblOwned:SetHeight(22)
	lblOwned:SetWidth(180)
	lblOwned:SetJustifyH("LEFT")
	lblOwned:SetJustifyV("CENTER")
	lblOwned:SetText(L["Hide already possessed items"])
	panel.cbOwned = cbOwned

	panel:Hide()
	private.filtersPanel = panel
end

function private:SyncFiltersPanelState()
	local p = private.filtersPanel
	if not p then return end
	p.cbStock:SetChecked(TSM.db.global.showOutOfStock)
	p.cbHide:SetChecked(TSM.db.global.hideUnderTokensEnabled)
	p.input:SetText(tostring(TSM.db.global.hideUnderTokensThreshold or 1500))
	p.cbGroup:SetChecked(TSM.db.global.groupByCategory)
	p.cbOwned:SetChecked(TSM.db.global.hideOwned)
end
