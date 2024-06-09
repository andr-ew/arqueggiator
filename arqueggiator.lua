local arqueggiator = {}
arqueggiator.__index = arqueggiator 

local STOPPED = 1
local divs = { 
    4, 4/1, 2/1, 1/1, 1/2, 1/3, 1/4, 1/5, 1/6, 1/7, 1/8, 1/16, 1/32 
}
local div_names = { 
    'stop', '4/1', '2/1', '1/1', '1/2', '1/3', '1/4', '1/5', '1/6', '1/7', '1/8', '1/16', '1/32'
}

local reverses = { [0] = 1, [1] = -1 }

local init_step = 0

local function advance(self, gate_length, stride, loop)
    local next_step = self.step + stride
    if loop then next_step = util.wrap(next_step, 1, #self.sequence) end
    
    self.step = next_step 
    local idx = self.sequence[self.step]

    if idx then 
        if idx > 0 then self.action_on(idx) end
        self.gate = 1
        crops.dirty.grid = true
        
        clock.sleep(gate_length)

        if idx > 0 then self.action_off(idx) end
        self.gate = 0
        crops.dirty.grid = true
        
        -- if not self.sequence[self.step] then self:stop() end
    else
        -- self.step = 1
        self:stop()
    end

    self.index = idx or 1
end

function arqueggiator.new(id)
    local self = {}
    setmetatable(self, arqueggiator)

    self.id = id or '1'

    self.sequence = {}
    self.step = init_step
    self.gate = 0
    self.index = 1
    
    self.clk = 0

    self.action_on = function(idx) end
    self.action_off = function(idx) end

    self.running = false
    
    self.division = tab.key(divs, 1/2)
    self.gate_length = 50
    self.reverse = 0
    self.loop = 0

    self.trigger = function()
        local div = divs[self.division]
        local gate_length = self.gate_length/100 
                            * clock.get_beat_sec() 
                            * div
        local stride = reverses[self.reverse]
        local loop = self.loop > 0

        advance(self, gate_length, stride, loop)
    end

    self.tick = function()
        while self.running do 
            local div = divs[self.division]
            clock.sync(div)

            if self.running then self:trigger() end
        end
    end

    return self
end

function arqueggiator:pfix(name)
    return 'arqueggiator_'..self.id..'_'..string.gsub(name, ' ', '_')
end

local cs = require 'controlspec'

local param_ids = {
    'division',
    'gate_length',
    'reverse',
    'loop',
    'pulse'
}

arqueggiator.param_ids = param_ids
arqueggiator.params_count = #param_ids

function arqueggiator:params()
    params:add{
        type = 'option', id = self:pfix('division'), name = 'division',
        options = div_names, default = self.division,
        action = function(v)
            self.division = v

            self.running = v ~= STOPPED

            clock.cancel(self.clk)
            self.clk = clock.run(self.tick)
        end
    }
    params:add{
        type = 'control', id = self:pfix('gate_length'), name = 'gate length',
        controlspec = cs.def{ min = 0, max = 80, default = self.gate_length, units = '%' },
        action = function(v) self.gate_length = v end
    }
    params:add{
        type = 'binary', behavior = 'toggle', 
        id = self:pfix('reverse'), name = 'reverse',
        action = function(v) self.reverse = v end
    }
    params:add{
        type = 'binary', behavior = 'toggle', 
        id = self:pfix('loop'), name = 'loop', default = 1,
        action = function(v) 
            self.loop = v
            self:start() 
        end,
    }
    params:add{
        type = 'binary', behavior = 'trigger',
        id = self:pfix('pulse'), name = 'pulse',
        action = function() 
            clock.run(self.trigger)
        end
    }
end

function arqueggiator:start()
    local div = self.division 

    if not self.running and div ~= STOPPED then
        self.running = true
        self.clk = clock.run(self.tick)
    end
end

function arqueggiator:restart()
    self.step = init_step
    self:start()
end

function arqueggiator:stop()
    self.running = false
    self.step = init_step
end

function arqueggiator:set_sequence(new_table)
    self.sequence = new_table
    if self.loop > 0 then self:start() else self:restart() end
end

return arqueggiator
