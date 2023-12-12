local arqueggiator = {}
arqueggiator.__index = arqueggiator 

function arqueggiator.new(id)
    local self = {}
    setmetatable(self, arqueggiator)

    self.id = id or '1'

    self.sequence = {}
    self.step = 1
    self.gate = 0
    self.index = 1
    
    self.clk = 0

    self.action_on = function(idx) end
    self.action_off = function(idx) end

    self.running = false

    return self
end

function arqueggiator:pfix(name)
    return 'arqueggiator_'..self.id..'_'..string.gsub(name, ' ', '_')
end

local divs = { 4/1, 3/1, 2/1, 1/1, 1/2, 1/3, 1/4, 1/5, 1/6, 1/7, 1/8 }
local div_names = { '4/1', '3/1', '2/1', '1/1', '1/2', '1/3', '1/4', '1/5', '1/6', '1/7', '1/8' }
local reverses = { [0] = 1, [1] = -1 }

local cs = require 'controlspec'

function arqueggiator:params()
    params:add{
        type = 'option', id = self:pfix('division'), name = 'division',
        options = div_names, default = tab.key(divs, 1/2),
    }
    params:add{
        type = 'control', id = self:pfix('gate length'), name = 'gate length',
        controlspec = cs.def{ min = 0, max = 80, default = 50, units = '%' }
    }
    params:add{
        type = 'binary', behavior = 'toggle', 
        id = self:pfix('reverse'), name = 'reverse',
    }
    params:add{
        type = 'binary', behavior = 'toggle', 
        id = self:pfix('loop'), name = 'loop', default = 1,
        action = function() self:start() end
    }
end

local function advance(self, gate_length, stride, loop)
    local idx = self.sequence[self.step]

    if idx then 
        if idx > 0 then self.action_on(idx) end
        self.gate = 1
        crops.dirty.grid = true

        clock.sleep(gate_length)

        if idx > 0 then self.action_off(idx) end
        self.gate = 0
        crops.dirty.grid = true

        local next_step = self.step + stride
        if loop then next_step = util.wrap(next_step, 1, #self.sequence) end
        
        self.step = next_step 
        
        if not self.sequence[self.step] then self:stop() end
    else
        self.step = 1
    end

    self.index = idx or 1
end

function arqueggiator:pulse()
    local div = divs[params:get(self:pfix('division'))]
    local gate_length = params:get(self:pfix('gate length'))/100 * clock.get_beat_sec() * div
    local stride = reverses[params:get(self:pfix('reverse'))]
    local loop = params:get(self:pfix('loop')) > 0

    clock.run(advance, self, gate_length, stride, loop)
end

function arqueggiator:start()
    if not self.running then
        self.running = true
        clock.run(function()
            while self.running do 
                local div = divs[params:get(self:pfix('division'))]
                local gate_length = params:get(self:pfix('gate length'))/100 
                                    * clock.get_beat_sec() 
                                    * div
                local stride = reverses[params:get(self:pfix('reverse'))]
                local loop = params:get(self:pfix('loop')) > 0

                clock.sync(div)

                advance(self, gate_length, stride, loop) 
            end
        end)
    end
end

function arqueggiator:restart()
    self.step = 1
    self:start()
end

function arqueggiator:stop()
    self.running = false
    self.step = 1
end

function arqueggiator:set_sequence(new_table)
    self.sequence = new_table
    if params:get(self:pfix('loop')) > 0 then self:start() else self:restart() end
end

return arqueggiator
