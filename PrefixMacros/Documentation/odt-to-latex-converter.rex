/* odt-to-latex-converter.rex
 *
 * Port of odt-to-latex-converter.py to ooRexx, using ooRexx's own
 * json.cls (shipped with the standard distribution, C:\Program
 * Files\oorexx\json.cls) instead of Python's json module -- verified
 * before writing this that ooRexx had no gap here needing Python or
 * BSF4ooRexx to fill (2026-09-22).
 *
 * Converts Prefix.Macros.odt to the four LaTeX body fragments
 * (intro/gml/hlasm/rexx), targeting pfxmacros.sty. Not a general
 * ODF-to-LaTeX tool -- shaped around this document's own structure,
 * same as the Python version it replaces. Built on pandoc's own JSON
 * AST (`pandoc -f odt -t json`), not a hand-rolled parser: pandoc
 * already resolves the ODF's structure -- list nesting, which
 * paragraphs belong to which bullet, table cell content -- correctly,
 * using a real parser. This script's job is only this document's own
 * grouping decisions (does a following Table/Para belong to the item
 * just opened) and emitting semantic macros in place of raw
 * \textbf/\textit/tabular.
 *
 * JSON objects become .Directory (string-keyed), JSON arrays become
 * .Array (1-based) -- every index below is the Python version's
 * 0-based index plus one.
 *
 * Usage:
 *     pandoc -f odt -t json Prefix.Macros.odt -o Prefix.Macros.json
 *     rexx odt-to-latex-converter.rex Prefix.Macros.json
 *
 * Author: Claude Code, 2026-09-22
 */

call main arg(1)
exit

::requires "json.cls"

::routine main
    use strict arg jsonPath

    doc = .json~fromJsonFile(jsonPath)
    blocks = doc['blocks']

    introEnd   = findMarker(blocks, 'The prefix commands for GML are:')
    hlasmStart = findMarker(blocks, 'Prefix macros for High Level Assembler:')
    rexxStart  = findMarker(blocks, 'Prefix macros for REXX:')

    introText = ''
    do i = 1 to introEnd - 1
        t = blockText(blocks[i])
        if t \= '' then do
            if introText \= '' then introText = introText || '0a'x || '0a'x
            introText = introText || t
        end
    end

    gml   = renderSection(subArray(blocks, introEnd + 1,   hlasmStart - 1))
    hlasm = renderSection(subArray(blocks, hlasmStart + 1, rexxStart - 1))
    rexx  = renderSection(subArray(blocks, rexxStart + 1,  blocks~items))

    call writeFile 'intro.tex', introText
    call writeFile 'gml.tex',   gml
    call writeFile 'hlasm.tex', hlasm
    call writeFile 'rexx.tex',  rexx
    say 'wrote intro/gml/hlasm/rexx .tex'
    return 0

::routine writeFile
    use strict arg path, text
    s = .stream~new(path)~~open('write replace')
    s~charout(text)
    s~close
    return

::routine subArray
    -- blocks[first..last] inclusive, empty .array if last < first
    -- NB: never name a plain variable "result" (or any case variant) --
    -- ooRexx silently overwrites that specific name with the return
    -- value of the next uncaptured expression/message-send statement,
    -- the same automatic-variable mechanism classic REXX uses after an
    -- internal CALL. Found the hard way: every ~append(...) statement
    -- below, left uncaptured, clobbered a variable actually named
    -- "result" with the index it returned.
    use strict arg blocks, first, last
    picked = .array~new
    do i = first to last
        picked~append(blocks[i])
    end
    return picked

::routine findMarker
    use strict arg blocks, substr
    do i = 1 to blocks~items
        b = blocks[i]
        if b['t'] = 'Para' then do
            if pos(substr, blockText(b)) > 0 then return i
        end
    end
    return blocks~items + 1

/* ---- character escaping ---- */

::routine esc
    use strict arg s
    s = s~changestr('\', '\textbackslash{}')
    s = s~changestr('&', '\&')
    s = s~changestr('%', '\%')
    s = s~changestr('$', '\$')
    s = s~changestr('#', '\#')
    s = s~changestr('_', '\_')
    s = s~changestr('{', '\{')
    s = s~changestr('}', '\}')
    s = s~changestr('~', '\textasciitilde{}')
    s = s~changestr('^', '\textasciicircum{}')
    s = s~changestr('|', '\textbar{}')
    return s

/* ---- inline rendering ---- */

/* Never strips: a Strong/Emph run's own leading/trailing space (a real
 * source quirk -- e.g., ".. " bolded including its trailing space) is
 * meaningful once it sits inside a larger sentence, and stripping it
 * here, one nesting level too early, would silently swallow the
 * word-space after it. Only the outer caller (inline()) strips.
 */
::routine _inline
    use strict arg nodes
    out = ''
    do n over nodes
        t = n['t']
        select
            when t = 'Str' then out = out || esc(n['c'])
            when t = 'Space' then out = out || ' '
            when t = 'Strong' then do
                inner = _inline(n['c'])
                if inner~strip() \= '' then out = out || '\constant{' || inner || '}'
            end
            when t = 'Emph' then do
                inner = _inline(n['c'])
                if inner~strip() \= '' then out = out || '\variable{' || inner || '}'
            end
            when t = 'Code' then out = out || esc(n['c'][2])
            when t = 'SoftBreak' then out = out || ' '
            when t = 'LineBreak' then out = out || ' '
            otherwise out = out || esc(plainText(.array~of(n)))
        end
    end
    return out

::routine inline
    use strict arg nodes
    return _inline(nodes)~strip()

::routine plainText
    use strict arg nodes
    out = ''
    do n over nodes
        t = n['t']
        if t = 'Str' then out = out || n['c']
        else if t = 'Space' then out = out || ' '
        else if n~hasindex('c'), n['c']~isa(.array) then out = out || plainText(n['c'])
    end
    return out

/* ---- block-level helpers ---- */

::routine blockText
    use strict arg block
    if block['t'] = 'Para' | block['t'] = 'Plain' then return inline(block['c'])
    return ''

/* A BulletList item's content is an Array of Blocks (almost always
 * Para here). Returns an Array of their rendered text, one per
 * paragraph.
 */
::routine itemParagraphs
    use strict arg itemBlocks
    picked = .array~new
    do b over itemBlocks
        if b['t'] = 'Para' | b['t'] = 'Plain' then picked~append(blockText(b))
    end
    return picked

::routine anyNonEmpty
    use strict arg strArray
    do s over strArray
        if s~strip() \= '' then return 1
    end
    return 0

::routine findNestedList
    use strict arg itemBlocks
    do b over itemBlocks
        if b['t'] = 'BulletList' then return b['c']
    end
    return .nil

::routine isTransition
    use strict arg text
    if pos('GLOBALV', text) > 0, pos('indentation', text) > 0 then return 1
    if pos('The prefix commands for', text) > 0 then return 1
    if pos('Prefix macros for', text) > 0 then return 1
    return 0

/* ---- the prefix-area/text-area example table ---- */

::routine renderTable
    -- tbl['c'] = [Attr, Caption, ColSpecs, TableHead, [TableBody...], TableFoot]
    use strict arg tbl
    c = tbl['c']
    thead   = c[4]
    tbodies = c[5]

    rows = .array~new
    do r over thead[2]
        rows~append(r)
    end
    do tbody over tbodies
        do r over tbody[4]
            rows~append(r)
        end
    end

    out = '\begin{pfxexample}'
    do row over rows
        cells = row[2]
        text1 = ''
        text2 = ''
        i = 0
        do cell over cells
            i = i + 1
            blocks = cell[5]
            cellText = ''
            do b over blocks
                bt = blockText(b)
                if bt \= '' then do
                    if cellText \= '' then cellText = cellText || ' '
                    cellText = cellText || bt
                end
            end
            if i = 1 then text1 = cellText
            else if i = 2 then text2 = cellText
        end
        out = out || '0a'x || '\pfxrow{' || text1 || '}{' || text2 || '}'
    end
    out = out || '0a'x || '\end{pfxexample}'
    return out

::routine renderNestedItemize
    use strict arg subItems
    out = '\begin{itemize}'
    do it over subItems
        paras = itemParagraphs(it)
        if paras~items > 0 then label = paras[1]
        else label = ''
        body = ''
        do i = 2 to paras~items
            if body \= '' then body = body || ' '
            body = body || paras[i]
        end
        body = body~strip()
        line = '\item ' || label
        if body \= '' then line = line || ': ' || body
        out = out || '0a'x || line
    end
    out = out || '0a'x || '\end{itemize}'
    return out

/* ---- the stateful per-section walk ---- */

::class SectionRenderer

::method init
    expose out pending currentLabel inDesc
    out = .array~new
    pending = .array~new
    currentLabel = .nil
    inDesc = 0

::method openDesc
    expose out inDesc
    if \inDesc then do
        out~append('\begin{description}')
        inDesc = 1
    end

::method flushItem
    expose out pending
    use strict arg label
    nonEmpty = .array~new
    do p over pending
        if p \= '' then nonEmpty~append(p)
    end
    if nonEmpty~items > 0 then do
        body = nonEmpty[1]
        do i = 2 to nonEmpty~items
            body = body || '0a'x || '0a'x || nonEmpty[i]
        end
    end
    else body = ''
    out~append('\item[{\pfxcommand{' || label || '}}] ' || body)
    pending = .array~new

::method closePending
    expose pending currentLabel
    if currentLabel \== .nil then do
        self~flushItem(currentLabel)
        currentLabel = .nil
    end

::method closeDesc
    expose out inDesc
    self~closePending()
    if inDesc then do
        out~append('\end{description}')
        inDesc = 0
    end

::method appendPending
    expose pending
    use strict arg piece
    pending~append(piece)

::method setCurrentLabel
    expose currentLabel
    use strict arg label
    currentLabel = label

::method currentLabelIsSet
    expose currentLabel
    return currentLabel \== .nil

::method result
    expose out
    text = ''
    do line over out
        if text \= '' then text = text || '0a'x
        text = text || line
    end
    return text

::method run
    expose out pending currentLabel inDesc
    use strict arg blocks

    do block over blocks
        t = block['t']
        select
            when t = 'Para' | t = 'Plain' then do
                txt = blockText(block)
                if txt \= '' then do
                    if self~currentLabelIsSet(), \isTransition(txt) then
                        self~appendPending(txt)
                    else do
                        self~closeDesc()
                        out~append(txt)
                        out~append('')
                    end
                end
            end
            when t = 'BulletList' then do
                items = block['c']
                -- drop a leading item that is entirely empty: a
                -- spurious blank bullet in the source
                do while items~items > 0
                    if anyNonEmpty(itemParagraphs(items[1])) then leave
                    trimmed = .array~new
                    do i = 2 to items~items
                        trimmed~append(items[i])
                    end
                    items = trimmed
                end
                if items~items > 0 then do
                    self~openDesc()
                    self~closePending()

                    merged = 0
                    if items~items = 2 then do
                        p0 = itemParagraphs(items[1])
                        p1 = itemParagraphs(items[2])
                        if p1~items > 0 then lbl1 = p1[1]
                        else lbl1 = ''
                        if left(lbl1, 7) = 'Insert ' then do
                            merged = 1
                            if p0~items > 0 then self~setCurrentLabel(p0[1])
                            else self~setCurrentLabel('')
                            joined = lbl1
                            do i = 2 to p1~items
                                joined = joined || ' ' || p1[i]
                            end
                            self~appendPending(joined~strip())
                            nested0 = findNestedList(items[1])
                            if nested0 \== .nil then
                                self~appendPending(renderNestedItemize(nested0))
                        end
                    end

                    if \merged then do
                        do i = 1 to items~items - 1
                            paras = itemParagraphs(items[i])
                            if paras~items > 0 then label = paras[1]
                            else label = ''
                            nested = findNestedList(items[i])
                            parts = .array~new
                            if paras~items > 1 then do
                                body1 = paras[2]
                                do j = 3 to paras~items
                                    body1 = body1 || ' ' || paras[j]
                                end
                                parts~append(body1~strip())
                            end
                            if nested \== .nil then
                                parts~append(renderNestedItemize(nested))
                            joinedParts = ''
                            do p over parts
                                if joinedParts \= '' then joinedParts = joinedParts || '0a'x || '0a'x
                                joinedParts = joinedParts || p
                            end
                            out~append('\item[{\pfxcommand{' || label || '}}] ' || joinedParts)
                        end

                        lastParas = itemParagraphs(items[items~items])
                        if lastParas~items > 0 then self~setCurrentLabel(lastParas[1])
                        else self~setCurrentLabel('')
                        nestedLast = findNestedList(items[items~items])
                        if lastParas~items > 1 then do
                            bodyLast = lastParas[2]
                            do j = 3 to lastParas~items
                                bodyLast = bodyLast || ' ' || lastParas[j]
                            end
                            self~appendPending(bodyLast~strip())
                        end
                        if nestedLast \== .nil then
                            self~appendPending(renderNestedItemize(nestedLast))
                    end
                end
            end
            when t = 'Table' then do
                if \self~currentLabelIsSet() then pending = .array~new
                self~appendPending(renderTable(block))
            end
            otherwise nop
        end
    end
    self~closeDesc()
    return

::routine renderSection
    use strict arg blocks
    r = .SectionRenderer~new
    r~run(blocks)
    return r~result()
