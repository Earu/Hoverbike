--[[
    PID CONTROLLER IMPLEMENTATION
    SEE: https://en.wikipedia.org/wiki/PID_controller
]]

local META = {}
META.__index = META

-- Sets the proportional, integral and derivative coefs
function META:SetCoeff(kp,ki,kd)
    self.Kp = kp or self.Kp
    self.Ki = ki or self.Ki
    self.Kd = kd or self.Kd
end

-- Computes proportional,integral and derivative and
-- returns the current pid's value
function META:Compute(err,delta)
    self.P = err
    self.I = self.I + err * delta
    self.D = (err - self.Err) / delta
    self.Err = err
    return self:Value()
end

-- The current PID value
function META:Value()
    return self.Kp * self.P + self.Ki * self.I + self.Kd * self.D
end

-- Resets computed values of the pid
function META:Reset()
    self.I = 0
    self.D = 0
    self.P = 0
    self.Err = 0
end

-- Constructor
local function PID(kp,ki,kd)
    kp = kp or 1
    ki = ki or 1
    kd = kd or 1
    return setmetatable({
        P = 0, I = 0, D = 0, Err = 0,
        Kp = kp, Ki = ki, Kd = kd,
    }, META)
end

return PID