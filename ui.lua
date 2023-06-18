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

            local function chord_add(idx)
                print('chord_add', idx)
            end

            local function chord_release()
                print('chord_release')
            end

            local function tap(idx)
                print('tap', idx)
            end

            local function double_tap(idx)
                print('double_tap', idx)
            end

            local function hold(idx)
                print('hold', idx)
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
                        table.remove(held, tab.key(held, idx))

                        if #held == 0 and (not is_releasing) then
                            local theld = util.time() - downtime
                            local tlast = util.time() - lasttime

                            clock.cancel(tap_clk)
                            
                            --TODO: only check for tap gesture on blank keys
                            
                            if theld > holdtime then --hold
                                hold(idx)
                            else
                                if tlast < dtaptime then --double-tap
                                    double_tap(idx)
                                else

                                    tap_clk = clock.run(function() 
                                        clock.sleep(dtaptime)

                                        tap(idx)
                                    end)
                                end
                            end

                            lasttime = util.time()
                        elseif #held > 0 then
                            held = {}
                            is_releasing = true
                            
                            chord_release()
                        end
                    end
                    --print('held ------')
                    --tab.print(held)
                    --print('-----------')
                end
            elseif crops.mode == 'redraw' then
            end
        end
    end
end


return Arqueggiator
