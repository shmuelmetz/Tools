-- pfx-slides.lua -- pandoc filter: a beamer source (pfx.slides.tex) read by
-- pandoc's LaTeX reader, turned into slides for the pptx writer (then
-- converted to ODP by LibreOffice).
--
-- * Each frame (read as Div.frame, its title as the first paragraph)
--   becomes a level-1 section: one slide, titled. The empty \titlepage
--   frame is dropped; the title slide comes from the metadata.
-- * Hebrew runs in the author are wrapped in RIGHT-TO-LEFT ISOLATE ...
--   POP DIRECTIONAL ISOLATE, so that neighbouring punctuation such as
--   the closing parenthesis keeps its place.
-- * pandoc does not read beamer's \institute; it is read from the
--   source file here and shown on the title slide after the author
--   (in the writer's date slot).

local RLI, PDI = '\u{2067}', '\u{2069}'

local function is_hebrew(s)
  return s:find('[\u{0590}-\u{05FF}]') ~= nil
end

-- Wrap each maximal run of Hebrew words (with the spaces between them)
-- in RLI ... PDI; trailing non-Hebrew characters stay outside.
local function isolate(inlines)
  local out, i, n = pandoc.Inlines({}), 1, #inlines
  while i <= n do
    local el = inlines[i]
    if el.t == 'Str' and is_hebrew(el.text) then
      local run = pandoc.Inlines({})
      local j = i
      while j <= n do
        local e = inlines[j]
        if e.t == 'Str' and is_hebrew(e.text) then run:insert(e)
        elseif e.t == 'Space' and j < n and inlines[j + 1].t == 'Str' and is_hebrew(inlines[j + 1].text) then run:insert(e)
        else break end
        j = j + 1
      end
      local last = run[#run]
      local heb, tail = last.text:match('^(.-[\u{0590}-\u{05FF}])([^\u{0590}-\u{05FF}]*)$')
      run[#run] = pandoc.Str(heb)
      out:insert(pandoc.Str(RLI))
      out:extend(run)
      out:insert(pandoc.Str(PDI))
      if tail ~= '' then out:insert(pandoc.Str(tail)) end
      i = j
    else
      out:insert(el); i = i + 1
    end
  end
  return out
end

local function institute()
  for _, f in ipairs(PANDOC_STATE.input_files) do
    local h = io.open(f, 'r')
    if h then
      local src = h:read('a'); h:close()
      local body = src:match('\\institute(%b{})')
      if body then
        body = body:sub(2, -2):gsub('\\\\', '\n\n')
        local doc = pandoc.read(body, 'latex')
        local parts = pandoc.Inlines({})
        for k, b in ipairs(doc.blocks) do
          if k > 1 then parts:insert(pandoc.LineBreak()) end
          parts:extend(b.content)
        end
        return parts
      end
    end
  end
end

function Meta(m)
  if m.author then
    for k, a in ipairs(m.author) do m.author[k] = isolate(a) end
  end
  local inst = institute()
  if inst then m.date = pandoc.MetaInlines(inst) end
  return m
end

function Div(el)
  if not el.classes:includes('frame') then return nil end
  local b = el.content
  if #b == 0 then return {} end
  if b[1].t == 'Para' or b[1].t == 'Plain' then
    local rest = {pandoc.Header(1, b[1].content)}
    for i = 2, #b do rest[#rest + 1] = b[i] end
    return rest
  end
  return b
end
