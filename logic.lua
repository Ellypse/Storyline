----------------------------------------------------------------------------------
-- Storyline
-- ---------------------------------------------------------------------------
-- Copyright 2015 Sylvain Cossement (telkostrasz@totalrp3.info)
-- Copyright 2015 Renaud "Ellypse" Parize (ellypse@totalrp3.info)
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
-- http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
----------------------------------------------------------------------------------

-- Storyline API
local wipe, tContains = wipe, tContains;
local UnitGUID = UnitGUID;
local setTooltipForSameFrame, setTooltipAll = Storyline_API.lib.setTooltipForSameFrame, Storyline_API.lib.setTooltipAll;
local registerHandler = Storyline_API.lib.registerHandler;
local loc, tsize = Storyline_API.locale.getText, Storyline_API.lib.tsize;
local playNext = Storyline_API.playNext;
local showStorylineFrame = Storyline_API.layout.showStorylineFrame;
local hideStorylineFrame = Storyline_API.layout.hideStorylineFrame;

-- WOW API
local strsplit, pairs, tostring = strsplit, pairs, tostring;
local UnitIsUnit, UnitExists, UnitName = UnitIsUnit, UnitExists, UnitName;
local IsAltKeyDown, IsShiftKeyDown, IsControlKeyDown = IsAltKeyDown, IsShiftKeyDown, IsControlKeyDown;
local InterfaceOptionsFrame_OpenToCategory = InterfaceOptionsFrame_OpenToCategory;

-- UI
local mainFrame = Storyline_NPCFrame;

local scalingLib = LibStub:GetLibrary("TRP-Dialog-Scaling-DB");
local scalingDB, customHeightDB, customPersonalDB;

-- Constants
local LINE_FEED_CODE = string.char(10);
local CARRIAGE_RETURN_CODE = string.char(13);
local WEIRD_LINE_BREAK = LINE_FEED_CODE .. CARRIAGE_RETURN_CODE .. LINE_FEED_CODE;
local CHAT_MARGIN = 70;

--*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
-- NPC Blacklisting
--*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*

local Storyline_NPC_BLACKLIST = {"94399"} -- Garrison mission table

--*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
-- DATA SAVING & RESTORING
--*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*

---
-- Get the scaling structures (saved and defaults)
-- @param modelMeID
-- @param modelYouID
--
local function getScalingStuctures(modelMeID, modelYouID)
	local key, invertedKey = scalingLib:GetModelKeys(modelMeID, modelYouID);
	local dataMe, dataYou = scalingLib:GetModelCoupleProperties(modelMeID, modelYouID);

	-- Custom height
	if customHeightDB[key] then
		dataMe.scale = customHeightDB[key][1];
		dataYou.scale = customHeightDB[key][2];
	elseif customHeightDB[invertedKey] then
		dataMe.scale = customHeightDB[invertedKey][2];
		dataYou.scale = customHeightDB[invertedKey][1];
	end

	-- Custom attributes
	if customPersonalDB[modelMeID] then
		for field, value in pairs(customPersonalDB[modelMeID]) do
			dataMe[field] = value;
		end
	end
	if customPersonalDB[modelYouID] then
		for field, value in pairs(customPersonalDB[modelYouID]) do
			dataYou[field] = value;
		end
	end

	return dataMe, dataYou;
end

---
-- Reset a scaling field in the saved structures for a modelID tuple.
-- @param field typically "me" or "you"
--
local function resetStructure()
	local key, invertedKey = scalingLib:GetModelKeys(mainFrame.models.me.model, mainFrame.models.you.model);

	-- Reset custom heights
	for _, value in pairs({key, invertedKey}) do
		if customHeightDB[value] then
			wipe(customHeightDB[value]);
			customHeightDB[value] = nil;
		end
	end

	-- Reset custom attributes
	if customPersonalDB[mainFrame.models.me.model] then
		wipe(customPersonalDB[mainFrame.models.me.model]);
		customPersonalDB[mainFrame.models.me.model] = nil;
	end
	if customPersonalDB[mainFrame.models.you.model] then
		wipe(customPersonalDB[mainFrame.models.you.model]);
		customPersonalDB[mainFrame.models.you.model] = nil;
	end
end

--*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
-- LOADING & START DIALOG
--*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*

local function loadScalingParameters(defaultData, meYou, facing)
	scalingLib:SetModelHeight(defaultData.scale, mainFrame.models[meYou]);
	scalingLib:SetModelFeet(defaultData.feet, mainFrame.models[meYou]);
	scalingLib:SetModelOffset(defaultData.offset, mainFrame.models[meYou], facing);
	scalingLib:SetModelFacing(defaultData.facing, mainFrame.models[meYou], facing);
end

---
-- Called when the two models are loaded.
-- This method initializes all scaling parameters.
--
local function modelsLoaded()
	if mainFrame.models.you.modelLoaded and mainFrame.models.me.modelLoaded then

		mainFrame.models.you.model = mainFrame.models.you:GetModelFileID();
		if mainFrame.models.you.model then
			mainFrame.models.you.model = tostring(mainFrame.models.you.model);
		end
		mainFrame.models.me.model = mainFrame.models.me:GetModelFileID();
		if mainFrame.models.me.model then
			mainFrame.models.me.model = tostring(mainFrame.models.me.model);
		end


		local dataMe, dataYou = getScalingStuctures(mainFrame.models.me.model, mainFrame.models.you.model);

		-- Configuration for model Me.
		loadScalingParameters(dataMe, "me", true);

		-- Configuration for model You, if available.
		if mainFrame.models.you.model then
			loadScalingParameters(dataYou, "you", false);
		else
			-- If there is no You model, play the read animation for the Me model.
			mainFrame.models.me:SetAnimation(520);
		end

		-- Place the modelIDs in the debug frame
		if mainFrame.models.you.model then
			mainFrame.debug.you:SetText(mainFrame.models.you.model);
		end
		if mainFrame.models.me.model then
			mainFrame.debug.me:SetText(mainFrame.models.me.model);
		end

		mainFrame.debug.recorded:Hide();
		if scalingLib:IsRecorded(mainFrame.models.me.model, mainFrame.models.you.model) then
			mainFrame.debug.recorded:Show();
		end
	end
end

---
-- Start a dialog with unit ID targetType
-- @param targetType
-- @param fullText
-- @param event
-- @param eventInfo
--
function Storyline_API.startDialog(targetType, fullText, event, eventInfo)
	mainFrame.debug.text:SetText(event);

	-- Get NPC_ID
	local guid = UnitGUID(targetType);
	local type, zero, server_id, instance_id, zone_uid, npc_id, spawn_uid = strsplit("-", guid or "");
	mainFrame.models.you.npc_id = npc_id;

	-- Dirty if to fix the flavor text appearing on naval mission table because Blizzard…
	if tContains(Storyline_NPC_BLACKLIST, npc_id) or tContains(Storyline_Data.npc_blacklist, npc_id)then
		SelectGossipOption(1);
		return;
	end

	local targetName = UnitName(targetType);

	if targetName and targetName:len() > 0 and targetName ~= UNKNOWN then
		mainFrame.chat.name:SetText(targetName);
	else
		if eventInfo.nameGetter and eventInfo.nameGetter() then
			mainFrame.chat.name:SetText(eventInfo.nameGetter());
		else
			mainFrame.chat.name:SetText("");
		end
	end

	if eventInfo.titleGetter and eventInfo.titleGetter() and eventInfo.titleGetter():len() > 0 then
		mainFrame.banner:Show();
		mainFrame.title:SetText(eventInfo.titleGetter());
		if eventInfo.getTitleColor and eventInfo.getTitleColor() then
			mainFrame.title:SetTextColor(eventInfo.getTitleColor());
		else
			mainFrame.title:SetTextColor(0.95, 0.95, 0.95);
		end
	else
		mainFrame.title:SetText("");
		mainFrame.banner:Hide();
	end

	mainFrame.models.me.modelLoaded = false;
	mainFrame.models.you.modelLoaded = false;
	mainFrame.models.you.model = "";
	mainFrame.models.me.model = "";

	-- Load player in the left model
	mainFrame.models.me:SetUnit("player", false);

	-- Load unit in the right model
	if UnitExists(targetType) and not UnitIsUnit("player", "npc") then
		mainFrame.models.you:SetUnit(targetType, false);
	else
		mainFrame.models.you:SetUnit("none");
		mainFrame.models.you.modelLoaded = true;
	end

	fullText = fullText:gsub(LINE_FEED_CODE .. "+", "\n");
	fullText = fullText:gsub(WEIRD_LINE_BREAK, "\n");

	local texts = { strsplit("\n", fullText) };
	if texts[#texts]:len() == 0 then
		texts[#texts] = nil;
	end
	mainFrame.chat.texts = texts;
	mainFrame.chat.currentIndex = 0;
	mainFrame.chat.eventInfo = eventInfo;
	mainFrame.chat.event = event;
	Storyline_NPCFrameObjectivesContent:Hide();
	mainFrame.chat.previous:Hide();
	showStorylineFrame();

	playNext(mainFrame.models.you);
end

--*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
-- TEXT ANIMATION
--*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*

local ANIMATION_TEXT_SPEED = 80;

local function onUpdateChatText(self, elapsed)
	if self.start and mainFrame.chat.text:GetText() and mainFrame.chat.text:GetText():len() > 0 then
		self.start = self.start + (elapsed * (ANIMATION_TEXT_SPEED * Storyline_Data.config.textSpeedFactor or 0.5));
		if Storyline_Data.config.textSpeedFactor == 0 or self.start >= mainFrame.chat.text:GetText():len() then
			self.start = nil;
			mainFrame.chat.text:SetAlphaGradient(mainFrame.chat.text:GetText():len(), 1);
		else
			mainFrame.chat.text:SetAlphaGradient(self.start, 30);
		end
	end
end

--*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
-- DEBUG
--*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*

local function saveCustomHeight(meYou, scale)
	-- Getting custom structure or creating it
	local key, invertedKey = scalingLib:GetModelKeys(mainFrame.models.me.model, mainFrame.models.you.model);

	if not customHeightDB[key] and customHeightDB[invertedKey] then
		-- We swap me/you as it is inverted
		customHeightDB[invertedKey][meYou == "me" and 2 or 1] = scale;
	else
		if not customHeightDB[key] then
			customHeightDB[key] = {};
		end
		customHeightDB[key][meYou == "me" and 1 or 2] = scale;
	end

end

local function saveCustomIndependantScaling(meYou, field, value)
	local model = meYou == "me" and mainFrame.models.me.model or mainFrame.models.you.model;

	if not customPersonalDB[model] then
		customPersonalDB[model] = {};
	end
	customPersonalDB[model][field] = value;
end

local function debugInit()
	if not Storyline_Data.config.debug then
		mainFrame.debug:Hide();
	end
	Storyline_NPCFrameDebugMeResetButton:SetScript("OnClick", function(self)
		resetStructure();
		modelsLoaded();
	end);

	-- Scrolling on the 3D model frame to adjust the size of the models
	for _, meYou in pairs({"me", "you"}) do
		mainFrame.models[meYou].scroll:EnableMouseWheel(true);
		mainFrame.models[meYou].scroll:SetScript("OnMouseWheel", function(self, delta)
			if IsAltKeyDown() then
				local scale = mainFrame.models[meYou].scale - (IsShiftKeyDown() and 0.1 or 0.01) * delta;
				scalingLib:SetModelHeight(scale, mainFrame.models[meYou]);
				saveCustomHeight(meYou, scale);
			elseif IsControlKeyDown() then
				local facing = mainFrame.models[meYou].facing - (IsShiftKeyDown() and 0.2 or 0.02) * delta;
				scalingLib:SetModelFacing(facing, mainFrame.models[meYou], meYou == "me");
				saveCustomIndependantScaling(meYou, "facing", facing);
			end
		end);
		mainFrame.models[meYou].scroll:RegisterForClicks("LeftButtonUp", "RightButtonUp");
		mainFrame.models[meYou].scroll:SetScript("OnClick", function(self, button)
			if IsAltKeyDown() then
				local offset = mainFrame.models[meYou].offset - (button == "LeftButton" and 1 or -1) * (IsShiftKeyDown() and 0.1 or 0.01);
				scalingLib:SetModelOffset(offset, mainFrame.models[meYou], meYou == "me");
				saveCustomIndependantScaling(meYou, "offset", offset);
			elseif IsControlKeyDown() then
				local feet = mainFrame.models[meYou].feet - (button == "LeftButton" and 1 or -1) * (IsShiftKeyDown() and 0.1 or 0.01);
				scalingLib:SetModelFeet(feet, mainFrame.models[meYou]);
				saveCustomIndependantScaling(meYou, "feet", feet);
			end
		end);
	end

	mainFrame.debug.dump.dump:SetScript("OnClick", function()
		local info =
[[["%s~%s"] = {
	["me"] = {
		["scale"] = %s,
		["feet"] = %s,
		["offset"] = %s,
		["facing"] = %s,
	},
	["you"] = {
		["scale"] = %s,
		["feet"] = %s,
		["offset"] = %s,
		["facing"] = %s,
	}
},]]
		local formatted = info:format(
			mainFrame.models.me.model,
			mainFrame.models.you.model,
			mainFrame.models.me.scale, mainFrame.models.me.feet, mainFrame.models.me.offset, mainFrame.models.me.facing,
			mainFrame.models.you.scale, mainFrame.models.you.feet, mainFrame.models.you.offset, mainFrame.models.you.facing
		);
		mainFrame.debug.dump.scroll.text:SetText(formatted);
	end);

	-- Debug for scaling
	Storyline_API.addon:RegisterChatCommand("storydebug", function()
		Storyline_API.startDialog("target", "Pouic", "SCALING_DEBUG", Storyline_API.EVENT_INFO.SCALING_DEBUG);
	end);

	setTooltipAll(Storyline_NPCFrameDebugMeResetButton, "TOP", 0, 0, "Reset values for these models"); -- Debug, not localized
end

--*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
-- INIT
--*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*

local function closeDialog()
	if mainFrame.chat.eventInfo and mainFrame.chat.eventInfo.cancelMethod then
		mainFrame.chat.eventInfo.cancelMethod();
	end
	hideStorylineFrame();
end

local function resetDialog()
	Storyline_NPCFrameObjectivesContent:Hide();
	mainFrame.chat.currentIndex = 0;
	playNext(Storyline_NPCFrameModelsYou);
end

Storyline_API.addon = LibStub("AceAddon-3.0"):NewAddon("Storyline", "AceConsole-3.0");

function Storyline_API.addon:OnEnable()

	if not Storyline_Data then
		Storyline_Data = {};
	end

	-- Cleanup
	local usedFields = {
		"customscale",
		"config",
		"npc_blacklist",
	};
	for key, _ in pairs(Storyline_Data) do
		if not tContains(usedFields, key) then
			wipe(Storyline_Data[key]);
			Storyline_Data[key] = nil;
		end
	end

	if not Storyline_Data.customscale then
		Storyline_Data.customscale = {};
	end
	if not Storyline_Data.customscale.relative then
		Storyline_Data.customscale.relative = {};
	end
	if not Storyline_Data.customscale.personal then
		Storyline_Data.customscale.personal = {};
	end
	scalingDB = Storyline_Data.customscale;
	customHeightDB = Storyline_Data.customscale.relative;
	customPersonalDB = Storyline_Data.customscale.personal;

	if not Storyline_Data.config then
		Storyline_Data.config = {};
	end
	if not Storyline_Data.npc_blacklist then
		Storyline_Data.npc_blacklist = {};
	end

	-- List of IDs for NPCs that are buggy when ForceGossip returns true
	local fuckingNPCIDs = {
		["110725"] = true, -- Archon Torias (Priests order hall)
		["108018"] = true, -- Archivist Melinda (Warlocks order hall)
		["108050"] = true, -- Survivalist Bahn (Hunters order hall)
		["110599"] = true, -- Loramus Thalipedes (Demon hunters order hall)
		["108527"] = true, -- Loramus Thalipedes (Demon hunters order hall) again
		["107994"] = true, -- Einar the Runecaster (Warriors order hall)
		["108331"] = true, -- Chronicler Elrianne (Mages order hall)
		["109901"] = true, -- Sir Alamande Graythorn (Paladins order hall)
		["112199"] = true, -- Journeyman Goldmine (Shamans order hall)
		["97485"]  = true, -- Archivist Zubashi (Death knights order hall)
		["98939"]  = true, -- Number Nine Jia (Monks order hall)
		["105998"] = true, -- Winstone Wolfe (Rogues order hall)
		["97989"]  = true, -- Leafbeard the Storied (Druids order hall)
		["105998"] = true, -- Winstone Wolfe (Rogues order hall)
		["97389"]  = true, -- Eye of Odyn
	}

	ForceGossip = function()
		-- return if the option is enabled and check if the NPC is not buggy (thanks Blizzard)
		return Storyline_Data.config.forceGossip and not fuckingNPCIDs[select(6, strsplit("-", UnitGUID("npc") or ""))];
	end

	Storyline_API.locale.init();

	Storyline_NPCFrameBG:SetDesaturated(true);
	mainFrame.chat.next:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp");
	mainFrame.chat.next:SetScript("OnClick", function(self, button)
		if button == "RightButton" then
			-- If we are not already on the last text, jump to it
			if mainFrame.chat.currentIndex < #mainFrame.chat.texts then
				mainFrame.chat.currentIndex = #mainFrame.chat.texts - 1; -- Set current text index to the one before the last one
				playNext(mainFrame.models.you); -- Play the next text (the last one)
			else
				-- If we were on the last text, use playNext to trigger the finish method (best available action)
				playNext(mainFrame.models.you);
			end
		elseif button == "MiddleButton" then
			closeDialog();
		else
			if mainFrame.chat.start and mainFrame.chat.start < mainFrame.chat.text:GetText():len() then
				mainFrame.chat.start = mainFrame.chat.text:GetText():len();
			else
				playNext(mainFrame.models.you);
			end
		end
	end);
	mainFrame.chat.previous:SetScript("OnClick", resetDialog);
	mainFrame.chat:SetScript("OnUpdate", onUpdateChatText);
	Storyline_NPCFrameClose:SetScript("OnClick", closeDialog);
	Storyline_NPCFrameRewardsItem:SetScale(1.5);

	mainFrame:SetScript("OnKeyDown", function(self, key)
		if not Storyline_Data.config.useKeyboard then
			self:SetPropagateKeyboardInput(true);
			return;
		end

		if key == "SPACE" then
			self:SetPropagateKeyboardInput(false);
			mainFrame.chat.next:Click(IsShiftKeyDown() and "RightButton" or "LeftButton");
		elseif key == "BACKSPACE" then
			self:SetPropagateKeyboardInput(false);
			mainFrame.chat.previous:Click();
		elseif key == "ESCAPE" then
			closeDialog();
		else
			local keyNumber = tonumber(key);
			if not keyNumber then
				self:SetPropagateKeyboardInput(true);
				return;
			end

			local foundFrames = 0;
			for i = 1, 9 do
				if _G["Storyline_NPCFrameChatOption" .. i] and _G["Storyline_NPCFrameChatOption" .. i].IsVisible and _G["Storyline_NPCFrameChatOption" .. i]:IsVisible() then
					foundFrames = foundFrames + 1;
					if foundFrames == keyNumber then
						_G["Storyline_NPCFrameChatOption" .. i]:Click();
						self:SetPropagateKeyboardInput(false);
						return;
					end
				end
			end

			self:SetPropagateKeyboardInput(true);
			return;
		end
	end);

	Storyline_NPCFrameGossipChoices:SetScript("OnKeyDown", function(self, key)
		if not Storyline_Data.config.useKeyboard then
			self:SetPropagateKeyboardInput(true);
			return;
		end

		if key == "ESCAPE" then
			Storyline_NPCFrameGossipChoices:Hide();
			self:SetPropagateKeyboardInput(false);
			return;
		end

		local keyNumber = tonumber(key);
		if not keyNumber then
			self:SetPropagateKeyboardInput(true);
			return;
		end

		if keyNumber == 0 then
			keyNumber = 10;
		end

		local foundFrames = 0;
		for i = 0, 9 do
			if _G["Storyline_ChoiceString" .. i] and _G["Storyline_ChoiceString" .. i].IsVisible and _G["Storyline_ChoiceString" .. i]:IsVisible() then
				foundFrames = foundFrames + 1;
				if foundFrames == keyNumber then
					_G["Storyline_ChoiceString" .. i]:Click();
					self:SetPropagateKeyboardInput(false);
					return;
				end
			end
		end

		self:SetPropagateKeyboardInput(true);
		return;

	end);

	mainFrame.models.you.animTab = {};
	mainFrame.models.me.animTab = {};

	mainFrame.models.you:SetScript("OnUpdate", function(self, elapsed)
		if self.spin then
			self.spinAngle = self.spinAngle - (elapsed / 2);
			self:SetFacing(self.spinAngle);
		end
	end);

	-- Register events
	Storyline_API.initEventsStructure();

	-- 3D models loaded
	mainFrame.models.me:SetScript("OnModelLoaded", function()
		mainFrame.models.me.modelLoaded = true;
		modelsLoaded();
	end);

	mainFrame.models.you:SetScript("OnModelLoaded", function()
		mainFrame.models.you.modelLoaded = true;
		modelsLoaded();
	end);

	-- Closing
	registerHandler("GOSSIP_CLOSED", function()
		hideStorylineFrame();
	end);
	registerHandler("QUEST_FINISHED", function()
		hideStorylineFrame();
	end);

	-- Resizing
	local resizeChat = function()
		mainFrame.chat.text:SetWidth(mainFrame:GetWidth() - 150);
		mainFrame.chat:SetHeight(mainFrame.chat.text:GetHeight() + CHAT_MARGIN + 5);
		Storyline_NPCFrameGossipChoices:SetWidth(mainFrame:GetWidth() - 400);
	end
	mainFrame.chat.text:SetWidth(550);
	Storyline_NPCFrameResizeButton.onResizeStop = function(width, height)
		resizeChat();
		Storyline_Data.config.width = width;
		Storyline_Data.config.height = height;
	end;
	mainFrame:SetSize(Storyline_Data.config.width or 700, Storyline_Data.config.height or 450);
	resizeChat();

	-- Debug
	debugInit();

	-- Slash command to show settings frames
	Storyline_API.addon:RegisterChatCommand("storyline", function()
		InterfaceOptionsFrame_OpenToCategory(StorylineOptionsPanel);
		if not Storyline_NPCFrameConfigButton.shown then -- Dirty fix for the Interface frame shitting itself the first time
			Storyline_NPCFrameConfigButton.shown = true;
			InterfaceOptionsFrame_OpenToCategory(StorylineOptionsPanel);
		end;
	end);

	setTooltipAll(Storyline_NPCFrameConfigButton, "TOP", 0, 0, loc("SL_CONFIG"));


	mainFrame:RegisterForDrag("LeftButton");

	mainFrame:SetScript("OnDragStart", function(self)
		if not Storyline_API.layout.isFrameLocked() then
			self:StartMoving();
		end
	end);

	mainFrame:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing();
	end);

	Storyline_API.options.init();

	---------------------------------------------
	--- Buttons builder
	---------------------------------------------
	Storyline_API.buttons = {};
	local buttons = {};

	local animationLib = LibStub:GetLibrary("TRP-Dialog-Animation-DB");

	function Storyline_API.buttons.getButtonAtIndex(index, parent, anchor)
		local anchorPoint = "BOTTOM";
		if not buttons[index] then
			local button = CreateFrame("Frame", nil, parent, "Storyline_DialogChoice");
			button:HookScript("OnMouseUp", function()
				PlaySound("gsCharacterSelection");
				Storyline_API.buttons.hideAllButtons();
			end);
			button:HookScript("OnEnter", function(self)
				button.text:GetText():gsub("[%.%?%!]+", function(finder)
					Storyline_API.playSelfAnim(animationLib:GetDialogAnimation(Storyline_NPCFrameModelsMe.model, finder:sub(1, 1)));
				end);
			end);
			buttons[index] = button;
		end
		local button = buttons[index];
		if not anchor then
			anchor = parent;
			anchorPoint = "TOP";
		end
		button:SetPoint("TOP", anchor, anchorPoint, 0, -5);
		return button;
	end

	function Storyline_API.buttons.refreshButtonHeight(button)
		button:SetHeight(button.text:GetHeight() + 25);
	end

	function Storyline_API.buttons.hideAllButtons()
		Storyline_DialogChoicesScrollFrame:Hide();
		Storyline_DialogChoicesScrollFrame.borderBottom:Hide();
		Storyline_DialogChoicesScrollFrame.borderTop:Hide();
		Storyline_DialogChoicesScrollFrame:Hide();
		for _, button in pairs(buttons) do
			button:Hide();
			button.icon:SetVertexColor(1, 1, 1);
		end
	end

	function Storyline_API.buttons.getIconTextureForGossipType(gossipType)
		return "Interface\\GossipFrame\\" .. gossipType .. "GossipIcon";
	end

	function Storyline_API.buttons.getIconTextureForAvailableQuestType(frequency, isRepeatable, isLegendary)
		local questIcon = "Interface\\GossipFrame\\AvailableQuestIcon";
		if isLegendary then
			questIcon = "Interface\\GossipFrame\\AvailableLegendaryQuestIcon";
		elseif frequency == LE_QUEST_FREQUENCY_DAILY or frequency == LE_QUEST_FREQUENCY_WEEKLY or isRepeatable then
			questIcon = "Interface\\GossipFrame\\DailyQuestIcon";
		end
		return questIcon;
	end

	function Storyline_API.buttons.getIconTextureForActiveQuestType(frequency, isRepeatable, isLegendary)
		local questIcon = "Interface\\GossipFrame\\ActiveQuestIcon";
		if isLegendary then
			questIcon = "Interface\\GossipFrame\\ActiveLegendaryQuestIcon";
		elseif frequency == LE_QUEST_FREQUENCY_DAILY or frequency == LE_QUEST_FREQUENCY_WEEKLY or isRepeatable then
			questIcon = "Interface\\GossipFrame\\DailyActiveQuestIcon";
		end
		return questIcon;
	end

end