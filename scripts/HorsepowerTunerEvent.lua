--
-- HorsepowerTunerEvent
-- Syncs a vehicle's tuning factors between clients and server.
--

HorsepowerTunerEvent = {}
local HorsepowerTunerEvent_mt = Class(HorsepowerTunerEvent, Event)

InitEventClass(HorsepowerTunerEvent, "HorsepowerTunerEvent")

function HorsepowerTunerEvent.emptyNew()
    return Event.new(HorsepowerTunerEvent_mt)
end

function HorsepowerTunerEvent.new(vehicle, torqueFactor, powerFactor)
    local self = HorsepowerTunerEvent.emptyNew()
    self.vehicle = vehicle
    self.torqueFactor = torqueFactor
    self.powerFactor = powerFactor
    return self
end

function HorsepowerTunerEvent:readStream(streamId, connection)
    self.vehicle = NetworkUtil.readNodeObject(streamId)
    self.torqueFactor = streamReadFloat32(streamId)
    self.powerFactor = streamReadFloat32(streamId)
    self:run(connection)
end

function HorsepowerTunerEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.vehicle)
    streamWriteFloat32(streamId, self.torqueFactor)
    streamWriteFloat32(streamId, self.powerFactor)
end

function HorsepowerTunerEvent:run(connection)
    if not connection:getIsServer() then
        g_server:broadcastEvent(self, false, connection, self.vehicle)
    end

    if self.vehicle ~= nil and self.vehicle:getIsSynchronized() and self.vehicle.hpTuneSetFactors ~= nil then
        self.vehicle:hpTuneSetFactors(self.torqueFactor, self.powerFactor, true)
    end
end

function HorsepowerTunerEvent.sendEvent(vehicle, torqueFactor, powerFactor, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(HorsepowerTunerEvent.new(vehicle, torqueFactor, powerFactor), nil, nil, vehicle)
        else
            g_client:getServerConnection():sendEvent(HorsepowerTunerEvent.new(vehicle, torqueFactor, powerFactor))
        end
    end
end
