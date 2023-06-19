local arqueggiator = {}
arqueggiator.__index = arqueggiator 

function arqueggiator.new()
    local self = {}
    setmetatable(self, arqueggiator)

    self.sequence = {}
    self.step = 1
    self.gate = 0
    
    self.div = 1/2
    self.gate_length = 0.5
    self.stride = 1

    self.clk = 0

    self.action_on = function(idx) end
    self.action_off = function(idx) end

    self.running = false

    return self
end

local function advance(self)
    local idx = self.sequence[self.step]

    if idx then 
        if idx > 0 then self.action_on(idx) end
        self.gate = 1
        crops.dirty.grid = true

        clock.sleep(self.gate_length * clock.get_beat_sec() * self.div)

        if idx > 0 then self.action_off(idx) end
        self.gate = 0
        crops.dirty.grid = true
        
        self.step = util.wrap(self.step + self.stride, 1, #self.sequence)
    else
        self.step = 1
    end
end

function arqueggiator:pulse()
    clock.run(advance, self)
end

function arqueggiator:start()
    self.running = true
    clock.run(function()
        while self.running do 
            clock.sync(self.div)

            advance(self) 
        end
    end)
end

function arqueggiator:stop()
    self.running = false
end

return arqueggiator
