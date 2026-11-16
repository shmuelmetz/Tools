-- odt-cell-borders.lua -- give every table cell in an ODT written by
-- pandoc a thin border, as in the original Prefix.Macros.odt.
--
-- pandoc's ODT writer puts its own automatic style TableRowCell (with
-- fo:border="none") into content.xml, where a reference document
-- cannot override it, so this rewrites that one style after the fact.
--
-- Usage: pandoc lua odt-cell-borders.lua file.odt

local path = arg[1]
assert(path, 'usage: pandoc lua odt-cell-borders.lua file.odt')

local h = assert(io.open(path, 'rb'))
local archive = pandoc.zip.Archive(h:read('a'))
h:close()

local BORDER = '0.5pt solid #000000'
local entries, changed = {}, 0
for _, e in ipairs(archive.entries) do
  if e.path == 'content.xml' then
    local xml = e:contents()
    xml, changed = xml:gsub(
      '(<style:style style:name="TableRowCell" style:family="table%-cell">%s*'
        .. '<style:table%-cell%-properties) fo:border="none"',
      '%1 fo:border="' .. BORDER .. '" fo:padding="0.04in"')
    e = pandoc.zip.Entry('content.xml', xml, e.modtime)
  end
  entries[#entries + 1] = e
end
assert(changed == 1, 'TableRowCell style not found in content.xml')
archive.entries = entries

h = assert(io.open(path, 'wb'))
h:write(archive:bytestring())
h:close()
