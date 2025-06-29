local M = {
    b = 0,
    ts = 0, -- ms
    dt = 0, -- sec
    offset = nil,
    tsline = 0, -- zero based line number of `tsprompt`
    dtline = nil, -- `setup()`

    tsprefix     = "[1]ts:",
    tsprompt     = "", -- `tsline`
    tssec        = "sec:       ",
    tsms         = "msec:      ",
    tsloc        = "local:     ",
    tsutc        = "utc:       ",
    hr           = "3↓  4↑ ----------------",
    dtprompt     = "[2]dt:     ",
    dtsec        = "sec:       ",
    dtms         = "msec:      ",
    dtloc        = "local:     ",
    dtutc        = "utc:       ",
    instructions = "  (0=reset  5=now)"
}

function M.setlines(j, prompt, ...)
    local content
    if prompt then
        content = {prompt}
        for _, v in ipairs({...}) do
            table.insert(content, v)
        end
    else
        content = {...}
    end
    vim.api.nvim_buf_set_lines(M.b, j - #content, j, false, content)
end

function M.get_utc_and_loc(s, ms)
    local m = string.format(".%03d", ms)
    local dt = os.date("%Y-%m-%d %H:%M:%S", s)
    return os.date("%a %Y-%m-%d %H:%M:%S", s - M.offset) .. m, os.date("%a ", s) .. dt .. m, dt
end

function M.resetall()
    if M.dt <= 0 then
        M.dt = math.floor(os.time())
    end
    local utc, loc, dt = M.get_utc_and_loc(M.dt, 0)
    M.ts = M.dt * 1000
    M.setlines(12, nil,
        M.tsprompt .. M.ts,
        M.tssec .. M.dt,
        M.tsms .. M.ts,
        M.tsloc .. loc,
        M.tsutc .. utc,
        M.hr,
        M.dtprompt .. dt,
        M.dtsec .. M.dt,
        M.dtms .. M.ts,
        M.dtloc .. loc,
        M.dtutc .. utc,
        M.instructions
    )
end

function M.updatets(setprompt)
    local s = math.floor(M.ts / 1000)
    local utc, loc = M.get_utc_and_loc(s, M.ts % 1000)
    local newprompt = nil
    if setprompt then
        local line = vim.api.nvim_buf_get_lines(M.b, M.tsline, M.tsline + 1, false)
        if #line == 1 then
            local l = line[1]
            if l:sub(1, #M.tsprefix) == M.tsprefix then
                newprompt = M.tsprompt .. M.ts .. " " .. l:sub(#M.tsprefix+1):gsub("^%s+", "")
            else
                newprompt = M.tsprompt .. M.ts .. " " .. l:gsub("^%s+", "")
            end
        end
    end
    M.setlines(M.tsline + 5, newprompt,
        M.tssec .. s,
        M.tsms .. M.ts,
        M.tsloc .. loc,
        M.tsutc .. utc
    )
end

function M.convts()
    local line = vim.api.nvim_buf_get_lines(M.b, M.tsline, M.tsline + 1, false)
    if #line ~= 1 then
        vim.api.nvim_err_writeln("EpochConv failed to get ts")
        return
    end
    local number = tonumber(string.match(line[1], ":%s*(%d+)"))
    if number then
        if number > 115895208634 and number < 32502322952000 then
            M.ts = number
        elseif number > 0 and number < 32502322952 then
            M.ts = number * 1000
        else
            vim.api.nvim_err_writeln("EpochConv got invalid ts " .. number)
            return
        end
        M.ts = math.floor(M.ts)
        M.updatets(false)
    else
        vim.api.nvim_err_writeln("EpochConv failed to parse ts")
    end
end

function M.updatedt(setprompt)
    local utc, loc, dt = M.get_utc_and_loc(M.dt, 0)
    M.setlines(M.dtline + 5, setprompt and M.dtprompt .. dt,
        M.dtsec .. M.dt,
        M.dtms .. M.dt .. "000",
        M.dtloc .. loc,
        M.dtutc .. utc
    )
end

function M.convdt()
    local line = vim.api.nvim_buf_get_lines(M.b, M.dtline, M.dtline + 1, false)
    if #line ~= 1 then
        vim.api.nvim_err_writeln("EpochConv failed to get dt")
        return
    end
    local syear, smonth, sday, shour, smin, ssec = string.match(line[1], "(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)")
    if syear and smonth and sday and shour and smin and ssec then
        local dttable = {
            year = tonumber(syear),
            month = tonumber(smonth),
            day = tonumber(sday),
            hour = tonumber(shour),
            min = tonumber(smin),
            sec = tonumber(ssec)
        }
        if
            dttable.year > 0 and dttable.month >= 1 and dttable.month <= 12 and
                dttable.day >= 1 and dttable.day <= 31 and
                dttable.hour >= 0 and dttable.hour <= 23 and
                dttable.sec >= 0 and dttable.sec <= 59
        then
            M.dt = math.floor(os.time(dttable))
        else
            vim.api.nvim_err_writeln("EpochConv got invalid dt")
            return
        end
        M.updatedt(false)
    else
        vim.api.nvim_err_writeln("EpochConv failed to parse dt")
    end
end

function M.ts2dt()
    if M.ts > 0 then
        M.dt = math.floor(M.ts / 1000)
        M.updatedt(true)
    end
end

function M.dt2ts()
    if M.dt > 0 then
        M.ts = M.dt * 1000
        M.updatets(true)
    end
end

function M.tsnow()
    M.ts = math.floor(os.time()) * 1000
    M.updatets(true)
end

function M.show()
    vim.api.nvim_open_win(M.b, true, {split = "right"})
    -- vim.api.nvim_set_option_value('winfixwidth', true, {win=ret})
end

function M.toggle()
    if M.b > 0 then
        local winid = vim.fn.bufwinid(M.b)
        if winid == -1 then
            M.show()
        else
            vim.api.nvim_win_close(winid, false)
        end
    else
        M.b = vim.api.nvim_create_buf(false, false)
        if M.b == 0 then
            vim.api.nvim_err_writeln("EpochConv failed to create buf")
            return
        end
        vim.api.nvim_buf_set_name(M.b, "EpochConv")
        vim.api.nvim_set_option_value("buftype", "nofile", {buf=M.b})
        vim.api.nvim_set_option_value("swapfile", false, {buf=M.b})
        vim.keymap.set("n", "g0", M.resetall, {buffer = M.b, noremap = true, silent = true, nowait = true})
        vim.keymap.set("n", "g1", M.convts, {buffer = M.b, noremap = true, silent = true, nowait = true})
        vim.keymap.set("n", "g2", M.convdt, {buffer = M.b, noremap = true, silent = true, nowait = true})
        vim.keymap.set("n", "g3", M.ts2dt, {buffer = M.b, noremap = true, silent = true, nowait = true})
        vim.keymap.set("n", "g4", M.dt2ts, {buffer = M.b, noremap = true, silent = true, nowait = true})
        vim.keymap.set("n", "g5", M.tsnow, {buffer = M.b, noremap = true, silent = true, nowait = true})
        M.show()
    end
end

function M.setup()
    if M.offset == nil then
        vim.api.nvim_create_user_command("EpochConv", M.toggle, {desc = "toggle Epoch Conv"})
        local now = os.time()
        M.offset = math.floor(os.difftime(now, os.time(os.date("!*t", now))))
        M.tsprompt = M.tsprefix .. "     "
        M.dtline = M.tsline + 6
    end
end

return M
