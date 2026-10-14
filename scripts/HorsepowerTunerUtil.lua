--
-- HorsepowerTunerUtil
-- Hooks the engine torque curve so a vehicle's motor can be scaled at runtime.
--
-- Two multipliers are stored on the motor:
--   hpTuneTorqueFactor - applied at the bottom of the rpm range (low-end pull)
--   hpTunePowerFactor  - applied at the top of the rpm range (top-end horsepower)
-- Between min and max rpm the multiplier is blended linearly, so the two
-- settings can be changed independently while power = torque * rpm stays true.
--

HorsepowerTunerUtil = {}

HorsepowerTunerUtil.KW_TO_HP = 1.35962
HorsepowerTunerUtil.NUM_SAMPLES = 60

function HorsepowerTunerUtil.getFactorAtRpm(motor, rpm)
    local torqueFactor = motor.hpTuneTorqueFactor or 1
    local powerFactor = motor.hpTunePowerFactor or 1
    local minRpm = motor.minRpm or 0
    local maxRpm = motor.maxRpm or minRpm

    local t = 0.5
    if maxRpm > minRpm then
        t = MathUtil.clamp((rpm - minRpm) / (maxRpm - minRpm), 0, 1)
    end

    return torqueFactor + (powerFactor - torqueFactor) * t
end

function HorsepowerTunerUtil.getTorqueCurveValue(motor, superFunc, rpm)
    local value = superFunc(motor, rpm)
    if motor.hpTuneTorqueFactor ~= nil and not motor.hpTuneSuspended then
        value = value * HorsepowerTunerUtil.getFactorAtRpm(motor, rpm)
    end
    return value
end

-- This is the curve that gets handed to the physics engine. Scale it here explicitly
-- (with the getTorqueCurveValue hook suspended so it is never applied twice).
function HorsepowerTunerUtil.getTorqueAndSpeedValues(motor, superFunc, ...)
    motor.hpTuneSuspended = true
    local torques, rotationSpeeds = superFunc(motor, ...)
    motor.hpTuneSuspended = false

    if motor.hpTuneTorqueFactor ~= nil and torques ~= nil and rotationSpeeds ~= nil then
        local scaled = {}
        for i, torque in ipairs(torques) do
            local rpm = (rotationSpeeds[i] or 0) * 30 / math.pi
            scaled[i] = torque * HorsepowerTunerUtil.getFactorAtRpm(motor, rpm)
        end
        torques = scaled
    end

    return torques, rotationSpeeds
end

-- Re-sends the motor's torque curve to the physics engine (server side only)
function HorsepowerTunerUtil.pushToPhysics(vehicle)
    local spec = vehicle.spec_motorized
    if not vehicle.isServer or spec == nil or spec.motorizedNode == nil then
        return false
    end

    if vehicle.updateMotorProperties ~= nil then
        vehicle:updateMotorProperties()
        return true
    elseif Motorized.updateMotorProperties ~= nil then
        Motorized.updateMotorProperties(vehicle)
        return true
    end

    return false
end

-- Returns peak torque (kNm) and peak power (kW) of the raw curve, optionally tuned
function HorsepowerTunerUtil.computePeaks(motor, tuned)
    local curve = motor.torqueCurve
    if curve == nil or curve.get == nil or motor.minRpm == nil or motor.maxRpm == nil then
        return 0, 0
    end

    local peakTorque, peakPower = 0, 0
    local n = HorsepowerTunerUtil.NUM_SAMPLES
    for i = 0, n do
        local rpm = motor.minRpm + (motor.maxRpm - motor.minRpm) * i / n
        local torque = curve:get(rpm)
        if tuned then
            torque = torque * HorsepowerTunerUtil.getFactorAtRpm(motor, rpm)
        end
        peakTorque = math.max(peakTorque, torque)
        peakPower = math.max(peakPower, torque * rpm * math.pi / 30)
    end

    return peakTorque, peakPower
end

function HorsepowerTunerUtil.applyToMotor(motor, torqueFactor, powerFactor)
    if motor == nil then
        return
    end

    if motor.hpTuneOrigPeakTorque == nil then
        motor.hpTuneOrigPeakTorque = motor.peakMotorTorque
        motor.hpTuneOrigPeakPower = motor.peakMotorPower
    end

    motor.hpTuneTorqueFactor = torqueFactor
    motor.hpTunePowerFactor = powerFactor

    -- Keep the motor's cached peak values (used by the transmission logic) in sync,
    -- scaled by the same ratio as the curve so we don't depend on their units.
    local stockTorque, stockPower = HorsepowerTunerUtil.computePeaks(motor, false)
    local tunedTorque, tunedPower = HorsepowerTunerUtil.computePeaks(motor, true)
    if motor.hpTuneOrigPeakTorque ~= nil and stockTorque > 0 then
        motor.peakMotorTorque = motor.hpTuneOrigPeakTorque * tunedTorque / stockTorque
    end
    if motor.hpTuneOrigPeakPower ~= nil and stockPower > 0 then
        motor.peakMotorPower = motor.hpTuneOrigPeakPower * tunedPower / stockPower
    end
end

if VehicleMotor ~= nil and VehicleMotor.getTorqueCurveValue ~= nil then
    VehicleMotor.getTorqueCurveValue = Utils.overwrittenFunction(VehicleMotor.getTorqueCurveValue, HorsepowerTunerUtil.getTorqueCurveValue)
else
    Logging.error("HorsepowerTuner: VehicleMotor.getTorqueCurveValue not found, engine tuning will have no effect")
end

if VehicleMotor ~= nil and VehicleMotor.getTorqueAndSpeedValues ~= nil then
    VehicleMotor.getTorqueAndSpeedValues = Utils.overwrittenFunction(VehicleMotor.getTorqueAndSpeedValues, HorsepowerTunerUtil.getTorqueAndSpeedValues)
else
    Logging.warning("HorsepowerTuner: VehicleMotor.getTorqueAndSpeedValues not found")
end
