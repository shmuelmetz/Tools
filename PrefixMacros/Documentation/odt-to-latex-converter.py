#!/usr/bin/env python3
"""Convert Prefix.Macros.odt to Prefix.Macros.tex, targeting pfxmacros.sty.

Built on pandoc's own JSON AST (`pandoc -f odt -t json`), not a hand-
rolled parser: pandoc already resolves the ODF's structure -- list
nesting, which paragraphs belong to which bullet, table cell content --
correctly, because it uses a real parser. This script's job is only to
walk that well-typed tree and decide *document-specific* grouping (does
a following Table/Para belong to the item just opened, per this
document's own inconsistent authoring) and emit semantic macros
(\\constant, \\variable, \\pfxcommand, the pfxexample environment) in
place of raw \\textbf/\\textit/tabular.

Usage:
    pandoc -f odt -t json Prefix.Macros.odt -o Prefix.Macros.json
    python3 odt-to-latex-converter.py Prefix.Macros.json > body.tex

Author: Claude Code, 2026-09-22
"""
import json
import sys

SPECIALS = str.maketrans({
    '&': r'\&', '%': r'\%', '$': r'\$', '#': r'\#', '_': r'\_',
    '{': r'\{', '}': r'\}', '~': r'\textasciitilde{}',
    '^': r'\textasciicircum{}', '\\': r'\textbackslash{}',
    '|': r'\textbar{}',
})


def esc(s):
    return s.translate(SPECIALS)


def _inline(nodes):
    """Render pandoc Inline nodes to LaTeX. Never strips: a Strong/Emph
    run's own leading/trailing space (a real source quirk -- e.g. ".. "
    bolded including its trailing space) is meaningful once it sits
    inside a larger sentence, and stripping it here, one nesting level
    too early, would silently swallow the word-space after it."""
    out = []
    for n in nodes:
        t = n['t']
        if t == 'Str':
            out.append(esc(n['c']))
        elif t == 'Space':
            out.append(' ')
        elif t == 'Strong':
            inner = _inline(n['c'])
            out.append(r'\constant{%s}' % inner if inner.strip() else '')
        elif t == 'Emph':
            inner = _inline(n['c'])
            out.append(r'\variable{%s}' % inner if inner.strip() else '')
        elif t == 'Code':
            out.append(esc(n['c'][1]))
        elif t in ('SoftBreak', 'LineBreak'):
            out.append(' ')
        else:
            # Anything unhandled: fall through on its plain text content
            # if it has one, rather than silently dropping it.
            out.append(esc(_plain_text([n])))
    return ''.join(out)


def inline(nodes):
    """Render a list of pandoc Inline nodes to one LaTeX string, with
    leading/trailing whitespace trimmed once, at this outer level."""
    return _inline(nodes).strip()


def _plain_text(nodes):
    out = []
    for n in nodes:
        if n['t'] == 'Str':
            out.append(n['c'])
        elif n['t'] == 'Space':
            out.append(' ')
        elif 'c' in n and isinstance(n['c'], list):
            out.append(_plain_text(n['c']))
    return ''.join(out)


def block_text(block):
    """Render one Para/Plain block to a LaTeX string."""
    if block['t'] in ('Para', 'Plain'):
        return inline(block['c'])
    return ''


def item_paragraphs(item_blocks):
    """A BulletList item's content is a list of Blocks (almost always
    Para here). Return their rendered text, one per paragraph."""
    return [block_text(b) for b in item_blocks if b['t'] in ('Para', 'Plain')]


def render_table(tbl):
    """tbl['c'] = [Attr, Caption, ColSpecs, TableHead, [TableBody...], TableFoot]."""
    _, _, _, thead, tbodies, _ = tbl['c']
    rows = list(thead[1])  # header rows (usually none here)
    for tbody in tbodies:
        rows.extend(tbody[3])
    out = [r'\begin{pfxexample}']
    for row in rows:
        cells = row[1]
        texts = []
        for cell in cells:
            blocks = cell[4]
            texts.append(' '.join(block_text(b) for b in blocks if block_text(b)))
        while len(texts) < 2:
            texts.append('')
        out.append(r'\pfxrow{%s}{%s}' % (texts[0], texts[1]))
    out.append(r'\end{pfxexample}')
    return '\n'.join(out)


def render_nested_itemize(sub_items):
    lines = [r'\begin{itemize}']
    for it in sub_items:
        paras = item_paragraphs(it)
        label = paras[0] if paras else ''
        body = ' '.join(paras[1:]).strip()
        lines.append(r'\item %s%s' % (label, (': ' + body) if body else ''))
    lines.append(r'\end{itemize}')
    return '\n'.join(lines)


def find_nested_list(item_blocks):
    for b in item_blocks:
        if b['t'] == 'BulletList':
            return b['c']
    return None


TRANSITION_MARKERS = ('GLOBALV', 'The prefix commands for', 'Prefix macros for')


def is_transition(text):
    return any(m in text for m in TRANSITION_MARKERS)


def render_section(blocks):
    out = []
    in_desc = [False]
    pending = []
    current_label = [None]

    def open_desc():
        if not in_desc[0]:
            out.append(r'\begin{description}')
            in_desc[0] = True

    def flush_item(label):
        parts = [p for p in pending if p]
        if parts:
            body = parts[0] + ''.join('\n\n' + p for p in parts[1:])
        else:
            body = ''
        out.append(r'\item[{\pfxcommand{%s}}] %s' % (label, body))
        pending.clear()

    def close_pending():
        if current_label[0] is not None:
            flush_item(current_label[0])
            current_label[0] = None

    def close_desc():
        close_pending()
        if in_desc[0]:
            out.append(r'\end{description}')
            in_desc[0] = False

    for block in blocks:
        t = block['t']
        if t in ('Para', 'Plain'):
            txt = block_text(block)
            if not txt:
                continue
            if current_label[0] is not None and not is_transition(txt):
                pending.append(txt)
            else:
                close_desc()
                out.append(txt)
                out.append('')
        elif t == 'BulletList':
            items = block['c']
            # Drop a leading item that is entirely empty: a spurious
            # blank bullet in the source (e.g. before "DO FR").
            while items and not any(item_paragraphs(items[0])):
                items = items[1:]
            if not items:
                continue
            open_desc()
            close_pending()
            if len(items) == 2:
                p0 = item_paragraphs(items[0])
                p1 = item_paragraphs(items[1])
                lbl1 = p1[0] if p1 else ''
                if lbl1.startswith('Insert '):
                    close_pending()
                    current_label[0] = p0[0] if p0 else ''
                    pending.append(' '.join(p1).strip())
                    nested = find_nested_list(items[0])
                    if nested:
                        pending.append(render_nested_itemize(nested))
                    continue
            for it in items[:-1]:
                paras = item_paragraphs(it)
                label = paras[0] if paras else ''
                nested = find_nested_list(it)
                parts = []
                if len(paras) > 1:
                    parts.append(' '.join(paras[1:]).strip())
                if nested:
                    parts.append(render_nested_itemize(nested))
                out.append(r'\item[{\pfxcommand{%s}}] %s' % (label, '\n\n'.join(parts)))
            paras = item_paragraphs(items[-1])
            label = paras[0] if paras else ''
            current_label[0] = label
            nested = find_nested_list(items[-1])
            if len(paras) > 1:
                pending.append(' '.join(paras[1:]).strip())
            if nested:
                pending.append(render_nested_itemize(nested))
        elif t == 'Table':
            if current_label[0] is None:
                pending.clear()
            pending.append(render_table(block))
    close_desc()
    return '\n'.join(out)


def find_marker(blocks, substr):
    for i, b in enumerate(blocks):
        if b['t'] == 'Para' and substr in block_text(b):
            return i
    return None


def main():
    doc = json.load(open(sys.argv[1], encoding='utf-8'))
    blocks = doc['blocks']

    intro_end = find_marker(blocks, 'The prefix commands for GML are:')
    hlasm_start = find_marker(blocks, 'Prefix macros for High Level Assembler:')
    rexx_start = find_marker(blocks, 'Prefix macros for REXX:')

    intro = '\n\n'.join(block_text(b) for b in blocks[:intro_end] if block_text(b))
    gml = render_section(blocks[intro_end + 1:hlasm_start])
    hlasm = render_section(blocks[hlasm_start + 1:rexx_start])
    rexx = render_section(blocks[rexx_start + 1:])

    open('intro.tex', 'w', encoding='utf-8', newline='\n').write(intro)
    open('gml.tex', 'w', encoding='utf-8', newline='\n').write(gml)
    open('hlasm.tex', 'w', encoding='utf-8', newline='\n').write(hlasm)
    open('rexx.tex', 'w', encoding='utf-8', newline='\n').write(rexx)
    print('wrote intro/gml/hlasm/rexx .tex', file=sys.stderr)


if __name__ == '__main__':
    main()
