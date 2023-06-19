local Arqueggiator = { grid = {} }

do
    local default_props = {
        x = 1,                           --x position of the component
        y = 1,                           --y position of the component
        size = 128,                      --number of keys in component
        state = {{}},                    --state is a sequece of indices
        step = 1,                        --the current step in the sequence, this key is lit
        gate = 1,                        --gate value
        levels = { 0, 15 },              --brightness levels. expects a table of 2 ints 0-15
        input = function(n, z) end,      --input callback, passes last key state on any input
        wrap = 16,                       --wrap to the next row/column every n keys
        flow = 'right',                  --primary direction to flow: 'up', 'down', 'left', 'right'
        flow_wrap = 'down',              --direction to flow when wrapping. must be perpendicular to flow
        padding = 0,                     --add blank spaces before the first key
                                         --note the lack of state prop – this is handled internally
    }
    default_props.__index = default_props

    local holdtime = 0.5
    local dtaptime = 0.25

    function Arqueggiator.grid.keymap()
        local downtime = 0
        local lasttime = 0

        local tap_clk = 0

        local held = {}
        local is_releasing = false

        local que = {}

        return function(props)
            setmetatable(props, default_props)

            local function chord_add(idx) 
                table.insert(que, idx)
                crops.dirty.grid = true
            end

            local function chord_release()
                crops.set_state(props.state, que)
                que = {}
            end
            
            local function tap_new(idx)
                crops.insert_state_at(props.state, props.step, idx)
            end

            local function tap_existing(idx)
                local seq = crops.get_state(props.state)
                for i,iidx in ipairs(seq) do
                    if math.abs(iidx) == idx then seq[i] = -seq[i] end
                end

                crops.set_state(props.state, seq)
            end

            local function double_tap_existing(idx)
                for i = crops.get_state_length(props.state), 1, -1 do
                    iidx = crops.get_state_at(props.state, i)

                    if math.abs(iidx) == idx then
                        crops.insert_state_at(props.state, i, iidx)
                    end
                end
            end

            local function hold_existing(idx)
                for i = crops.get_state_length(props.state), 1, -1 do
                    iidx = crops.get_state_at(props.state, i)

                    if math.abs(iidx) == idx then
                        crops.remove_state_at(props.state, i, iidx)
                    end
                end
            end

            local function seq_contains(idx)
                for i,iidx in ipairs(crops.get_state(props.state)) do
                    if math.abs(iidx) == idx then return iidx end
                end
            end

            if crops.mode == 'input' then
                local x, y, z = table.unpack(crops.args) 
                local idx = Grid.util.xy_to_index(props, x, y)

                if idx then 
                    if z==1 then
                        table.insert(held, idx)

                        if #held == 1 then
                            downtime = util.time()
                        elseif #held == 2 then
                            for _,iidx in ipairs(held) do chord_add(iidx) end
                        elseif #held > 2 then
                            chord_add(idx)
                        end
                    elseif z==0 then
                        if #held == 1 then
                            if is_releasing then 
                                chord_release() 
                                is_releasing = false
                            else
                                local theld = util.time() - downtime
                                local tlast = util.time() - lasttime

                                clock.cancel(tap_clk)

                                if not seq_contains(idx) then
                                    tap_new(idx)
                                else
                                    if theld > holdtime then --hold
                                        hold_existing(idx)
                                    else
                                        if tlast < dtaptime then --double-tap
                                            double_tap_existing(idx)
                                        else

                                            tap_clk = clock.run(function() 
                                                clock.sleep(dtaptime)

                                                tap_existing(idx)
                                            end)
                                        end
                                    end
                                end

                                lasttime = util.time()
                            end
                        elseif #held > 1 then
                            is_releasing = true
                        end
                        
                        table.remove(held, tab.key(held, idx))
                    end
                end
            elseif crops.mode == 'redraw' then
                local g = crops.handler 

                local idx_step = crops.get_state_at(props.state, props.step)
                local gate = props.gate > 0

                for idx = 1, props.size do
                    local idx_seq = seq_contains(idx)
                    local is_que = tab.contains(que, idx)
                        
                    local lvl = 0

                    if idx_seq then
                        if idx_seq > 0 then
                            if idx_seq == idx_step and gate then lvl = props.levels[3]
                            else lvl = #que==0 and props.levels[2] or 0 end
                        elseif idx_seq < 0 then
                            if idx_seq == idx_step and gate then lvl = props.levels[2]
                            else lvl = #que==0 and props.levels[1] or 0 end
                        end
                    end
                    if is_que then
                        lvl = props.levels[2]
                    end
                        
                    if idx_seq or is_que then
                        local x, y = Grid.util.index_to_xy(props, math.abs(idx))
                        if lvl>0 then g:led(x, y, lvl) end
                    end
                end
            end
        end
    end
end

return Arqueggiator
