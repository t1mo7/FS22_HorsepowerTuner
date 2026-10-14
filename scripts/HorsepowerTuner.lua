--
-- HorsepowerTuner
-- Vehicle specialization: on-screen panel to raise or lower horsepower and torque.
--

local MOD_NAME = g_currentModName

HorsepowerTuner = {}

HorsepowerTuner.SPEC_TABLE_NAME = "spec_" .. MOD_NAME .. ".horsepowerTuner"
HorsepowerTuner.STEP = 0.05
HorsepowerTuner.MIN_FACTOR = 0.25
HorsepowerTuner.MAX_FACTOR = 5.0

-- panel layout (screen-relative coordinates)
HorsepowerTuner.PANEL_X = 0.015
HorsepowerTuner.PANEL_Y = 0.52
HorsepowerTuner.PANEL_WIDTH = 0.27
HorsepowerTuner.TEXT_SIZE = 0.016
HorsepowerTuner.LINE_HEIGHT = 0.024
HorsepowerTuner.PADDING = 0.008

function HorsepowerTuner.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(Motorized, specializations)
end

function HorsepowerTuner.initSpecialization()
    local schemaSavegame = Vehicle.xmlSchemaSavegame
    local key = string.format("vehicles.vehicle(?).%s.horsepowerTuner", MOD_NAME)
    schemaSavegame:register(XMLValueType.FLOAT, key .. "#torqueFactor", "Low-rpm torque multiplier", 1)
    schemaSavegame:register(XMLValueType.FLOAT, key .. "#powerFactor", "High-rpm power multiplier", 1)
end

function HorsepowerTuner.registerFunctions(vehicleType)
    SpecializationUtil.registerFunction(vehicleType, "hpTuneSetFactors", HorsepowerTuner.hpTuneSetFactors)
end

function HorsepowerTuner.registerEventListeners(vehicleType)
    SpecializationUtil.registerEventListener(vehicleType, "onLoad", HorsepowerTuner)
    SpecializationUtil.registerEventListener(vehicleType, "onPostLoad", HorsepowerTuner)
    SpecializationUtil.registerEventListener(vehicleType, "onReadStream", HorsepowerTuner)
    SpecializationUtil.registerEventListener(vehicleType, "onWriteStream", HorsepowerTuner)
    SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", HorsepowerTuner)
    SpecializationUtil.registerEventListener(vehicleType, "onDraw", HorsepowerTuner)
end

function HorsepowerTuner:onLoad(savegame)
    local spec = self[HorsepowerTuner.SPEC_TABLE_NAME]
    spec.torqueFactor = 1
    spec.powerFactor = 1
    spec.panelVisible = false
    spec.actionEvents = {}
    spec.stats = nil
end

function HorsepowerTuner:onPostLoad(savegame)
    local spec = self[HorsepowerTuner.SPEC_TABLE_NAME]
    local torqueFactor, powerFactor = 1, 1

    if savegame ~= nil and not savegame.resetVehicles then
        local key = string.format("%s.%s.horsepowerTuner", savegame.key, MOD_NAME)
        torqueFactor = savegame.xmlFile:getValue(key .. "#torqueFactor", 1)
        powerFactor = savegame.xmlFile:getValue(key .. "#powerFactor", 1)
    end

    self:hpTuneSetFactors(torqueFactor, powerFactor, true)
end

function HorsepowerTuner:saveToXMLFile(xmlFile, key, usedModNames)
    local spec = self[HorsepowerTuner.SPEC_TABLE_NAME]
    xmlFile:setValue(key .. "#torqueFactor", spec.torqueFactor)
    xmlFile:setValue(key .. "#powerFactor", spec.powerFactor)
end

function HorsepowerTuner:onReadStream(streamId, connection)
    local torqueFactor = streamReadFloat32(streamId)
    local powerFactor = streamReadFloat32(streamId)
    self:hpTuneSetFactors(torqueFactor, powerFactor, true)
end

function HorsepowerTuner:onWriteStream(streamId, connection)
    local spec = self[HorsepowerTuner.SPEC_TABLE_NAME]
    streamWriteFloat32(streamId, spec.torqueFactor)
    streamWriteFloat32(streamId, spec.powerFactor)
end

local function sanitizeFactor(value)
    value = MathUtil.clamp(value or 1, HorsepowerTuner.MIN_FACTOR, HorsepowerTuner.MAX_FACTOR)
    return math.floor(value * 100 + 0.5) / 100
end

function HorsepowerTuner:hpTuneSetFactors(torqueFactor, powerFactor, noEventSend)
    local spec = self[HorsepowerTuner.SPEC_TABLE_NAME]
    spec.torqueFactor = sanitizeFactor(torqueFactor)
    spec.powerFactor = sanitizeFactor(powerFactor)

    local motor = self:getMotor()
    HorsepowerTunerUtil.applyToMotor(motor, spec.torqueFactor, spec.powerFactor)
    local pushed = HorsepowerTunerUtil.pushToPhysics(self)

    if not noEventSend or spec.torqueFactor ~= 1 or spec.powerFactor ~= 1 then
        print(string.format("HorsepowerTuner: %s torque x%.2f, power x%.2f (sent to physics: %s)",
            self:getFullName(), spec.torqueFactor, spec.powerFactor, tostring(pushed)))
    end

    if motor ~= nil then
        local stockTorque, stockPower = HorsepowerTunerUtil.computePeaks(motor, false)
        local tunedTorque, tunedPower = HorsepowerTunerUtil.computePeaks(motor, true)
        spec.stats = {
            stockHp = stockPower * HorsepowerTunerUtil.KW_TO_HP,
            tunedHp = tunedPower * HorsepowerTunerUtil.KW_TO_HP,
            stockNm = stockTorque * 1000,
            tunedNm = tunedTorque * 1000
        }
    end

    HorsepowerTunerEvent.sendEvent(self, spec.torqueFactor, spec.powerFactor, noEventSend)
end

----------------------------------------------------------------------------------------------------
-- Input
----------------------------------------------------------------------------------------------------

HorsepowerTuner.ADJUST_ACTIONS = {
    "HPTUNE_HP_UP", "HPTUNE_HP_DOWN", "HPTUNE_TQ_UP", "HPTUNE_TQ_DOWN", "HPTUNE_RESET"
}

function HorsepowerTuner:onRegisterActionEvents(isActiveForInput, isActiveForInputIgnoreSelection)
    if not self.isClient then
        return
    end

    local spec = self[HorsepowerTuner.SPEC_TABLE_NAME]
    self:clearActionEventsTable(spec.actionEvents)

    if isActiveForInputIgnoreSelection then
        local _, toggleId = self:addActionEvent(spec.actionEvents, InputAction.HPTUNE_TOGGLE, self, HorsepowerTuner.actionEventToggle, false, true, false, true, nil)
        g_inputBinding:setActionEventTextPriority(toggleId, GS_PRIO_NORMAL)

        for _, actionName in ipairs(HorsepowerTuner.ADJUST_ACTIONS) do
            local _, actionEventId = self:addActionEvent(spec.actionEvents, InputAction[actionName], self, HorsepowerTuner.actionEventAdjust, false, true, false, true, nil)
            g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_HIGH)
        end

        HorsepowerTuner.updateActionEvents(self)
    else
        spec.panelVisible = false
    end
end

function HorsepowerTuner.updateActionEvents(self)
    local spec = self[HorsepowerTuner.SPEC_TABLE_NAME]
    for _, actionName in ipairs(HorsepowerTuner.ADJUST_ACTIONS) do
        local actionEvent = spec.actionEvents[InputAction[actionName]]
        if actionEvent ~= nil then
            g_inputBinding:setActionEventActive(actionEvent.actionEventId, spec.panelVisible)
        end
    end
end

function HorsepowerTuner.actionEventToggle(self, actionName, inputValue, callbackState, isAnalog)
    local spec = self[HorsepowerTuner.SPEC_TABLE_NAME]
    spec.panelVisible = not spec.panelVisible
    HorsepowerTuner.updateActionEvents(self)
end

function HorsepowerTuner.actionEventAdjust(self, actionName, inputValue, callbackState, isAnalog)
    local spec = self[HorsepowerTuner.SPEC_TABLE_NAME]
    if not spec.panelVisible then
        return
    end

    local torqueFactor, powerFactor = spec.torqueFactor, spec.powerFactor
    local step = HorsepowerTuner.STEP

    if actionName == InputAction.HPTUNE_HP_UP then
        powerFactor = powerFactor + step
    elseif actionName == InputAction.HPTUNE_HP_DOWN then
        powerFactor = powerFactor - step
    elseif actionName == InputAction.HPTUNE_TQ_UP then
        torqueFactor = torqueFactor + step
    elseif actionName == InputAction.HPTUNE_TQ_DOWN then
        torqueFactor = torqueFactor - step
    elseif actionName == InputAction.HPTUNE_RESET then
        torqueFactor, powerFactor = 1, 1
    end

    self:hpTuneSetFactors(torqueFactor, powerFactor)
end

----------------------------------------------------------------------------------------------------
-- Panel
----------------------------------------------------------------------------------------------------

local function formatPercent(factor)
    local percent = math.floor((factor - 1) * 100 + 0.5)
    if percent > 0 then
        return string.format("+%d%%", percent)
    end
    return string.format("%d%%", percent)
end

function HorsepowerTuner:onDraw(isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
    local spec = self[HorsepowerTuner.SPEC_TABLE_NAME]
    if not spec.panelVisible or not isActiveForInputIgnoreSelection or spec.stats == nil then
        return
    end

    local stats = spec.stats
    local stock = g_i18n:getText("hptune_stock")
    local lines = {
        { text = string.format("%s - %s", g_i18n:getText("hptune_title"), self:getFullName()), bold = true },
        { text = string.format("%s: %s   %d hp  (%s %d hp)", g_i18n:getText("hptune_horsepower"),
            formatPercent(spec.powerFactor), stats.tunedHp + 0.5, stock, stats.stockHp + 0.5) },
        { text = string.format("%s: %s   %d Nm  (%s %d Nm)", g_i18n:getText("hptune_torque"),
            formatPercent(spec.torqueFactor), stats.tunedNm + 0.5, stock, stats.stockNm + 0.5) },
        { text = g_i18n:getText("hptune_help"), small = true }
    }

    local x = HorsepowerTuner.PANEL_X
    local pad = HorsepowerTuner.PADDING
    local lineHeight = HorsepowerTuner.LINE_HEIGHT
    local height = #lines * lineHeight + 2 * pad
    local y = HorsepowerTuner.PANEL_Y

    local width = HorsepowerTuner.PANEL_WIDTH
    for _, line in ipairs(lines) do
        line.size = line.small and HorsepowerTuner.TEXT_SIZE * 0.8 or HorsepowerTuner.TEXT_SIZE
        setTextBold(line.bold == true)
        width = math.max(width, getTextWidth(line.size, line.text) + 2 * pad)
    end

    if drawFilledRect ~= nil then
        drawFilledRect(x, y, width, height, 0, 0, 0, 0.75)
    end

    setTextAlignment(RenderText.ALIGN_LEFT)
    local textY = y + height - pad - lineHeight * 0.8
    for _, line in ipairs(lines) do
        setTextBold(line.bold == true)
        if line.small then
            setTextColor(0.75, 0.75, 0.75, 1)
        elseif line.bold then
            setTextColor(1, 0.75, 0.15, 1)
        else
            setTextColor(1, 1, 1, 1)
        end
        renderText(x + pad, textY, line.size, line.text)
        textY = textY - lineHeight
    end

    setTextBold(false)
    setTextColor(1, 1, 1, 1)
end
