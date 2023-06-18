local Arqueggiator = { grid = {} }

do
    local default_props = {
        x = 1,                           --x position of the component
        y = 1,                           --y position of the component
        size = 128,                      --number of keys in component
        state = {{}},                    --state is a sequece of indices
        step = 1,                        --the current step in the sequence, this key is lit
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

        return function(props)
            setmetatable(props, default_props)

            local function chord_add(idx) end

            local function chord_release()
                crops.copy_state_from(props.state, held)
            end
            
            local function tap_new(idx)
                crops.insert_state_at(props.state, props.step, idx)
            end

            local function tap_existing(idx)
                print('tap_existing', idx)
            end

            local function double_tap_existing(idx)
                print('double_tap_existing', idx)
            end

            local function hold_existing(idx)
                print('hold_existing', idx)
            end

            if crops.mode == 'input' then
                local x, y, z = table.unpack(crops.args) 
                local idx = Grid.util.xy_to_index(props, x, y)

                if idx then 
                    if z==1 then
                        table.insert(held, idx)

                        if #held == 1 then
                            is_releasing = false
                            downtime = util.time()
                        elseif #held == 2 then
                            for _,iidx in ipairs(held) do chord_add(iidx) end
                        elseif #held > 2 then
                            chord_add(idx)
                        end
                    elseif z==0 then
                        if #held == 1 and (not is_releasing) then
                            local theld = util.time() - downtime
                            local tlast = util.time() - lasttime

                            clock.cancel(tap_clk)

                            local blank = true
                            for i,iidx in ipairs(crops.get_state(props.state)) do
                                if math.abs(iidx) == idx then
                                    blank = false
                                    break
                                end
                            end
                            
                            if blank then
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
                        elseif #held > 1 then
                            chord_release()

                            held = {}
                            is_releasing = true
                        end
                        
                        table.remove(held, tab.key(held, idx))
                    end
                end
            elseif crops.mode == 'redraw' then
                local g = crops.handler 

                for i,idx in ipairs(crops.get_state(props.state)) do
                    local lvl
                    if idx > 0 then
                        if i == props.step then lvl = props.levels[3]
                        else lvl = props.levels[2] end
                    elseif idx < 0 then
                        if i == props.step then lvl = props.levels[2]
                        else lvl = props.levels[1] end
                    end

                    local x, y = Grid.util.index_to_xy(props, math.abs(idx))

                    if lvl>0 then g:led(x, y, lvl) end
                end
            end
        end
    end
end

return Arqueggiator
