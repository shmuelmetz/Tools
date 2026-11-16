-- pfxmacros.lua -- pandoc filter: the pfxmacros.sty markup for pandoc's
-- LaTeX reader (run with -f latex+raw_tex), so that the same LaTeX
-- source builds the LibreOffice files as well as the PDF.
--
--   \constant{x}, \pfxcommand{x}  -> bold     (as in pfxmacros.sty)
--   \variable{x}                  -> italic
--   \begin{pfxexample} \pfxrow[n]{prefix}{text} ... \end{pfxexample}
--        -> a two-column table; both columns in the "Preformatted Text"
--           paragraph style (monospaced), text indented n columns
--           with no-break spaces.

local defs = [[
\newcommand{\constant}[1]{\textbf{#1}}
\newcommand{\variable}[1]{\textit{#1}}
\newcommand{\pfxcommand}[1]{\textbf{#1}}
]]

local NBSP = '\u{00A0}'

-- LaTeX fragment -> pandoc inlines
local function inl(tex)
  if tex == '' then return {} end
  local doc = pandoc.read(defs .. tex, 'latex')
  local b = doc.blocks[1]
  if b and (b.t == 'Para' or b.t == 'Plain') then return b.content end
  return {}
end

-- read one balanced {...} group starting at position i (s:sub(i,i) == '{')
local function group(s, i)
  local depth, j = 0, i
  repeat
    local c = s:sub(j, j)
    if c == '\\' then j = j + 1
    elseif c == '{' then depth = depth + 1
    elseif c == '}' then depth = depth - 1 end
    j = j + 1
  until depth == 0 or j > #s
  return s:sub(i + 1, j - 2), j
end

-- Table cells take the reference document's "Table Contents" paragraph
-- style, which is monospaced, so bold and italic survive. Spaces become
-- no-break spaces so that runs of them are kept.
local function cell(inlines)
  local t = pandoc.Inlines(inlines):walk({
    Space = function() return pandoc.Str(NBSP) end,
  })
  return pandoc.Cell({pandoc.Plain(t)})
end

local function example(text)
  local rows = {}
  local i = 1
  while true do
    local a, b = text:find('\\pfxrow', i, true)
    if not a then break end
    local j, ind = b + 1, 0
    local opt = text:match('^%[(%d+)%]', j)
    if opt then ind = tonumber(opt); j = j + #opt + 2 end
    local pfx, k = group(text, j)
    local txt, m = group(text, k)
    local t = inl(txt)
    if ind > 0 then table.insert(t, 1, pandoc.Str(NBSP:rep(ind))) end
    rows[#rows + 1] = pandoc.Row({cell(inl(pfx)), cell(t)})
    i = m
  end
  local colspecs = {{pandoc.AlignLeft, 0.2}, {pandoc.AlignLeft, 0.8}}
  return pandoc.Table({long = {}}, colspecs, pandoc.TableHead({}),
                      {{attr = {}, body = rows, head = {}, row_head_columns = 0}},
                      pandoc.TableFoot({}))
end

function RawBlock(el)
  if el.format == 'latex' and el.text:match('^\\begin{pfxexample}') then
    return example(el.text)
  end
end

function RawInline(el)
  if el.format ~= 'latex' then return nil end
  local cmd, arg = el.text:match('^\\(%a+)%s*{(.*)}$')
  if cmd == 'constant' or cmd == 'pfxcommand' then return pandoc.Strong(inl(arg)) end
  if cmd == 'variable' then return pandoc.Emph(inl(arg)) end
end
