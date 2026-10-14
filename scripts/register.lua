--
-- Adds the horsepowerTuner specialization to every vehicle type that has an engine.
--

local modName = g_currentModName
local specName = modName .. ".horsepowerTuner"

local function addTunerSpecialization(typeManager)
    if typeManager.typeName ~= "vehicle" then
        return
    end

    local numAdded = 0
    for typeName, typeEntry in pairs(typeManager:getTypes()) do
        if typeEntry.specializationsByName["motorized"] ~= nil and typeEntry.specializationsByName[specName] == nil then
            typeManager:addSpecialization(typeName, specName)
            numAdded = numAdded + 1
        end
    end

    print(string.format("  HorsepowerTuner: added engine tuner to %d vehicle types", numAdded))
end

TypeManager.validateTypes = Utils.prependedFunction(TypeManager.validateTypes, addTunerSpecialization)
