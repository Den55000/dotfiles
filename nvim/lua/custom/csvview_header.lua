-- Keep csvview columns as narrow as their data.
--
-- csvview sizes each column by its widest cell, header included, so one long
-- header name over short values leaves a wide, mostly empty column. This
-- sizes columns by the data rows only, cuts long header names off with "…",
-- and shows the full name of the cursor's column in the winbar.
--
-- csvview has no option for this, so it wraps a few of its internal
-- functions. If a csvview update changes them, this warns once and does
-- nothing, leaving csvview's normal behaviour. Remove this file (and its
-- `require` in init.lua) if csvview gains a built-in option for it.

local M = {}

-- A shortened header keeps at least this many cells (including the "…"), so
-- it stays recognisable even over a column of one-character values.
local HEADER_MIN_WIDTH = 10

local ok_metrics, Metrics = pcall(require, 'csvview.metrics')
local ok_view, views = pcall(require, 'csvview.view')
local ok_util, util = pcall(require, 'csvview.util')
local View = ok_view and views.View

local function supported()
  return ok_metrics
    and ok_view
    and ok_util
    and type(View) == 'table'
    and type(Metrics.new) == 'function'
    and type(Metrics._update_column_metrics_for_row) == 'function'
    and type(Metrics.get_logical_row_fields) == 'function'
    and type(View._render_field) == 'function'
    and type(View._add_extmark) == 'function'
    and type(views.get) == 'function'
    and type(util.get_cursor) == 'function'
end

--- Count the header row as at most HEADER_MIN_WIDTH wide in the column widths.
local function patch_widths()
  local orig_new = Metrics.new
  function Metrics:new(bufnr, opts, parser)
    local obj = orig_new(self, bufnr, opts, parser)
    -- csvview stores the detected header before it builds the metrics
    local info = vim.b[bufnr].csvview_info
    local header = info and info.header and info.header.lnum
    local tracker = obj._columns
    if type(header) ~= 'number' or not (tracker and tracker._get_row and tracker.recalculate) then return obj end
    obj._header_lnum = header

    -- Rescans after edits skip the header too...
    local get_row = tracker._get_row
    tracker._get_row = function(lnum)
      if lnum == header then return nil end
      return get_row(lnum)
    end
    -- ...then the header's capped width is added back in
    local recalculate = tracker.recalculate
    tracker.recalculate = function(t, col_idx)
      recalculate(t, col_idx)
      local header_row = get_row(header)
      local field = header_row and header_row:field(col_idx)
      if field then t:update_width(col_idx, header, math.min(field.display_width, HEADER_MIN_WIDTH)) end
    end
    return obj
  end

  local orig_update = Metrics._update_column_metrics_for_row
  function Metrics:_update_column_metrics_for_row(row_idx)
    if row_idx ~= self._header_lnum then return orig_update(self, row_idx) end
    local row = self._rows[row_idx]
    if row then
      for col_idx, field in row:iter() do
        self._columns:update_width(col_idx, row_idx, math.min(field.display_width, HEADER_MIN_WIDTH))
      end
    end
  end
end

--- Cut header names that don't fit their column off with "…".
local function patch_header_render()
  local orig_render = View._render_field
  function View:_render_field(lnum, column_index, field)
    local column = lnum == self.header_lnum and self.metrics:column(column_index)
    -- Hiding text relies on conceal, which csvview only turns on in border mode
    if not column or self.opts.view.display_mode ~= 'border' then return orig_render(self, lnum, column_index, field) end

    local colwidth = math.max(column.max_width, self.opts.view.min_column_width)
    if field.display_width <= colwidth then return orig_render(self, lnum, column_index, field) end

    -- Keep as many characters as fit in colwidth - 1, then conceal the rest as "…"
    local text = vim.api.nvim_buf_get_text(self.bufnr, lnum - 1, field.offset, lnum - 1, field.offset + field.len, {})[1]
    local width, cut = 0, 0
    for _, char in ipairs(vim.fn.split(text, [[\zs]])) do
      local char_width = vim.fn.strdisplaywidth(char)
      if width + char_width > colwidth - 1 then break end
      width, cut = width + char_width, cut + #char
    end
    self:_add_extmark(lnum, field.offset + cut, { end_col = field.offset + field.len, conceal = '…' })

    -- Let csvview pad the field as if it were exactly as wide as what's shown
    local shown = setmetatable({ display_width = width + 1 }, { __index = function(_, key) return field[key] end })
    return orig_render(self, lnum, column_index, shown)
  end
end

--- Winbar text: position and full header name of the cursor's column.
--- The window being drawn is the current window while the winbar is evaluated.
local function winbar_text()
  local buf = vim.api.nvim_get_current_buf()
  local view = views.get(buf)
  if not (view and view.header_lnum) then return '' end

  local ok, cursor = pcall(util.get_cursor, buf)
  if not ok or cursor.kind ~= 'field' then return '' end

  local col = cursor.pos[2]
  local fields = view.metrics:get_logical_row_fields { lnum = view.header_lnum }
  local range = fields[col]
  if not range then return '' end

  local name = table.concat(vim.api.nvim_buf_get_text(buf, range.start_row - 1, range.start_col, range.end_row - 1, range.end_col, {}), ' ')
  return string.format(' %d/%d  %s', col, #fields, (name:gsub('%%', '%%%%')))
end

function M.winbar()
  local ok, text = pcall(winbar_text)
  return ok and text or ''
end

function M.setup()
  if not supported() then
    vim.notify('csvview internals changed: long header names are no longer shortened (lua/custom/csvview_header.lua)', vim.log.levels.WARN)
    return
  end
  patch_widths()
  patch_header_render()

  -- Show the winbar only in windows displaying a csvview buffer
  local winbar = "%{%v:lua.require'custom.csvview_header'.winbar()%}"
  local group = vim.api.nvim_create_augroup('csvview-header', { clear = true })
  local function set_winbar(buf, value)
    for _, win in ipairs(vim.fn.win_findbuf(buf)) do
      if vim.api.nvim_win_get_config(win).relative == '' then vim.api.nvim_set_option_value('winbar', value, { scope = 'local', win = win }) end
    end
  end
  vim.api.nvim_create_autocmd('User', {
    group = group,
    pattern = 'CsvViewAttach',
    callback = function(args) set_winbar(args.data, winbar) end,
  })
  vim.api.nvim_create_autocmd('User', {
    group = group,
    pattern = 'CsvViewDetach',
    callback = function(args) set_winbar(args.data, '') end,
  })
  -- A window switching between a csvview buffer and anything else
  vim.api.nvim_create_autocmd('BufWinEnter', {
    group = group,
    callback = function(args)
      local win = vim.api.nvim_get_current_win()
      if vim.api.nvim_win_get_config(win).relative ~= '' then return end
      local current = vim.api.nvim_get_option_value('winbar', { scope = 'local', win = win })
      if views.get(args.buf) then
        if current ~= winbar then vim.api.nvim_set_option_value('winbar', winbar, { scope = 'local', win = win }) end
      elseif current == winbar then
        vim.api.nvim_set_option_value('winbar', '', { scope = 'local', win = win })
      end
    end,
  })
end

return M
