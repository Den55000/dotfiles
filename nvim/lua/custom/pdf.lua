-- PDF viewing inside the terminal (kitty graphics protocol; pages rendered with pdftoppm):
--  * Opening a .pdf shows its pages as an image in the window.
--    j/k (also Space, PageDown/PageUp, mouse wheel) flip pages, gg/G or {count}G jump,
--    `o` opens it in the system PDF viewer instead.
--  * `M.telescope_previewer_maker` draws the first page in Telescope's preview window.
local M = {}

local api = vim.api

-- [[ Rendering ]]

local TELESCOPE_ID = 7311 -- kitty image id for the Telescope preview
local WINDOW_ID_BASE = 7400 -- + window id: one image per window showing a PDF
local cache_dir = vim.fn.stdpath 'cache' .. '/pdf-preview'

local function supported()
  return (vim.env.KITTY_WINDOW_ID or vim.env.TERM == 'xterm-kitty') and vim.fn.executable 'pdftoppm' == 1
end

local function kitty(cmd, payload)
  api.nvim_ui_send('\27_G' .. cmd .. (payload and (';' .. payload) or '') .. '\27\\')
end

local function unplace(id) kitty(('a=d,d=I,i=%d,q=2'):format(id)) end

--- Terminal cell size in pixels, from TIOCGWINSZ on /dev/tty
local cell_size = (function()
  local ok, ffi = pcall(require, 'ffi')
  if not ok then return function() return 8, 16 end end
  pcall(ffi.cdef, [[
    struct pdf_winsize { unsigned short row, col, xpixel, ypixel; };
    int ioctl(int, unsigned long, ...);
    int open(const char *, int, ...);
    int close(int);
  ]])
  return function()
    local fd = ffi.C.open('/dev/tty', 0)
    if fd < 0 then return 8, 16 end
    local ws = ffi.new 'struct pdf_winsize'
    local rc = ffi.C.ioctl(fd, 0x5413, ws) -- TIOCGWINSZ
    ffi.C.close(fd)
    if rc ~= 0 or ws.xpixel == 0 or ws.col == 0 then return 8, 16 end
    return ws.xpixel / ws.col, ws.ypixel / ws.row
  end
end)()

local function png_size(png)
  local f = io.open(png, 'rb')
  if not f then return end
  local header = f:read(24)
  f:close()
  if not header or #header < 24 then return end
  local function u32(i)
    local a, b, c, d = header:byte(i, i + 3)
    return ((a * 256 + b) * 256 + c) * 256 + d
  end
  return u32(17), u32(21)
end

---@type table<string, fun(png: string?)[]>
local pending = {}

--- Render `page` of `path` to a cached PNG, then call `cb(png)` (nil on failure)
local function render(path, page, cb)
  local stat = vim.uv.fs_stat(path)
  if not stat then return cb(nil) end
  local png = ('%s/%s.png'):format(cache_dir, vim.fn.sha256(table.concat({ path, stat.mtime.sec, stat.size, page }, ':')))
  if pending[png] then return table.insert(pending[png], cb) end
  if vim.uv.fs_stat(png) then return cb(png) end
  pending[png] = { cb }
  vim.fn.mkdir(cache_dir, 'p')
  local cmd = { 'pdftoppm', '-png', '-f', tostring(page), '-l', tostring(page), '-singlefile', '-scale-to', '1600', path, png:sub(1, -5) }
  vim.system(cmd, {}, function(res)
    vim.schedule(function()
      local cbs = pending[png]
      pending[png] = nil
      for _, f in ipairs(cbs) do
        f(res.code == 0 and png or nil)
      end
    end)
  end)
end

--- Draw `png` as kitty image `id`, fitted and centred in the text area of `winid`
local function place(id, png, winid)
  local iw, ih = png_size(png)
  if not iw then return end
  local info = vim.fn.getwininfo(winid)[1]
  local top, left = info.winrow + info.winbar, info.wincol + info.textoff
  local W, H = info.width - info.textoff, info.height
  local cw, ch = cell_size()
  local scale = math.min(W * cw / iw, H * ch / ih)
  local cols = math.max(1, math.floor(iw * scale / cw))
  local rows = math.max(1, math.floor(ih * scale / ch))

  unplace(id)
  -- Save cursor, move to the window, place the image (kitty reads the file itself), restore
  api.nvim_ui_send(('\0277\27[%d;%dH'):format(top, left + math.floor((W - cols) / 2)))
  kitty(('a=T,f=100,t=f,i=%d,c=%d,r=%d,C=1,q=2'):format(id, cols, rows), vim.base64.encode(png))
  api.nvim_ui_send '\0278'
end

-- [[ PDF buffers ]]

---@type table<integer, {path: string, page: integer, pages: integer}>
local docs = {}
---@type table<integer, true> windows that currently have an image placed
local placed = {}
local generation = 0

local function refresh()
  generation = generation + 1
  local wins = api.nvim_tabpage_list_wins(0)
  -- Images sit on top of everything, so hide them while a picker/float is open
  local covered = vim.iter(wins):any(function(w)
    local cfg = api.nvim_win_get_config(w)
    return cfg.relative ~= '' and cfg.focusable and not cfg.hide
  end)

  local want = {}
  if not covered then
    for _, w in ipairs(wins) do
      local doc = docs[api.nvim_win_get_buf(w)]
      if doc then want[w] = doc end
    end
  end
  for w in pairs(placed) do
    if not want[w] then
      unplace(WINDOW_ID_BASE + w)
      placed[w] = nil
    end
  end

  local this = generation
  for w, doc in pairs(want) do
    local page = doc.page
    render(doc.path, page, function(png)
      if not png or this ~= generation or doc.page ~= page or not api.nvim_win_is_valid(w) then return end
      place(WINDOW_ID_BASE + w, png, w)
      placed[w] = true
      -- Warm the cache for the next page
      if page < doc.pages then render(doc.path, page + 1, function() end) end
    end)
  end
end

-- Coalesce bursts of events; the short delay lets nvim finish redrawing
-- (a full redraw clears the screen, images included) before drawing
local refresh_queued = false
local function schedule_refresh()
  if refresh_queued then return end
  refresh_queued = true
  vim.defer_fn(function()
    refresh_queued = false
    refresh()
  end, 20)
end

local function goto_page(buf, page)
  local doc = docs[buf]
  page = math.max(1, math.min(page, doc.pages))
  if page == doc.page then return end
  doc.page = page
  vim.cmd.redrawstatus { bang = true }
  schedule_refresh()
end

--- Winbar text for the PDF window being drawn
function M.winbar()
  local doc = docs[api.nvim_win_get_buf(vim.g.statusline_winid or 0)]
  if not doc then return '' end
  return (' %s  ·  page %d/%d'):format(vim.fn.fnamemodify(doc.path, ':t'), doc.page, doc.pages)
end

local function setup_buffer(buf)
  local path = api.nvim_buf_get_name(buf)
  local bo = vim.bo[buf]
  bo.modifiable = true
  if supported() then
    local pages = tonumber(vim.fn.system({ 'pdfinfo', path }):match 'Pages:%s+(%d+)') or 1
    docs[buf] = { path = path, page = 1, pages = pages }
    api.nvim_buf_set_lines(buf, 0, -1, false, {})
  else
    api.nvim_buf_set_lines(buf, 0, -1, false, {
      'PDF: ' .. vim.fn.fnamemodify(path, ':~'),
      '',
      'Pages can only be drawn in kitty with pdftoppm installed. Press o to open it externally.',
    })
  end
  bo.buftype = 'nowrite'
  bo.swapfile = false
  bo.modifiable = false
  bo.modified = false
  bo.filetype = 'pdf'

  local function map(keys, fn, desc)
    for _, key in ipairs(keys) do
      vim.keymap.set('n', key, fn, { buffer = buf, desc = desc })
    end
  end
  map({ 'o' }, function() vim.ui.open(path) end, 'PDF: open in external viewer')
  if not docs[buf] then return end
  local function step(dir)
    return function() goto_page(buf, docs[buf].page + dir * vim.v.count1) end
  end
  map({ 'j', 'l', '<Down>', '<Right>', '<Space>', '<PageDown>', '<ScrollWheelDown>' }, step(1), 'PDF: next page')
  map({ 'k', 'h', '<Up>', '<Left>', '<BS>', '<PageUp>', '<ScrollWheelUp>' }, step(-1), 'PDF: previous page')
  map({ 'gg' }, function() goto_page(buf, vim.v.count > 0 and vim.v.count or 1) end, 'PDF: first page')
  map({ 'G' }, function() goto_page(buf, vim.v.count > 0 and vim.v.count or docs[buf].pages) end, 'PDF: last page / {count}G')
end

local function setup_window(win)
  local wo = vim.wo[win][0] -- local to this buffer in this window
  wo.number = false
  wo.relativenumber = false
  wo.signcolumn = 'no'
  wo.foldcolumn = '0'
  wo.statuscolumn = ''
  wo.cursorline = false
  wo.list = false
  wo.fillchars = 'eob: '
  wo.winbar = "%!v:lua.require'custom.pdf'.winbar()"
end

function M.setup()
  local group = api.nvim_create_augroup('custom-pdf', { clear = true })
  api.nvim_create_autocmd('BufReadCmd', {
    group = group,
    pattern = '*.pdf',
    callback = function(args) setup_buffer(args.buf) end,
  })
  api.nvim_create_autocmd('BufWinEnter', {
    group = group,
    callback = function(args)
      if docs[args.buf] then setup_window(api.nvim_get_current_win()) end
    end,
  })
  api.nvim_create_autocmd('BufWipeout', {
    group = group,
    callback = function(args) docs[args.buf] = nil end,
  })
  api.nvim_create_autocmd({
    'BufWinEnter',
    'BufWinLeave',
    'BufWipeout',
    'WinEnter',
    'WinClosed',
    'WinResized',
    'WinScrolled',
    'VimResized',
    'TabEnter',
    'FocusGained',
    'VimResume',
  }, { group = group, callback = schedule_refresh })
end

-- [[ Telescope preview ]]

local telescope_generation = 0

--- Drop-in replacement for Telescope's `buffer_previewer_maker`
function M.telescope_previewer_maker(filepath, bufnr, opts)
  telescope_generation = telescope_generation + 1
  unplace(TELESCOPE_ID)
  filepath = vim.fn.expand(filepath)
  if not filepath:lower():match '%.pdf$' or not supported() then
    return require('telescope.previewers').buffer_previewer_maker(filepath, bufnr, opts)
  end

  local winid = opts.winid
  api.nvim_buf_set_lines(bufnr, 0, -1, false, {})
  local clear = function() unplace(TELESCOPE_ID) end
  api.nvim_create_autocmd('BufWipeout', { buffer = bufnr, once = true, callback = clear })
  api.nvim_create_autocmd('WinClosed', { pattern = tostring(winid), once = true, callback = clear })

  local this = telescope_generation
  render(filepath, 1, function(png)
    if this ~= telescope_generation or not api.nvim_win_is_valid(winid) or api.nvim_win_get_buf(winid) ~= bufnr then return end
    if not png then return api.nvim_buf_set_lines(bufnr, 0, -1, false, { 'Could not render PDF' }) end
    place(TELESCOPE_ID, png, winid)
  end)
end

return M
