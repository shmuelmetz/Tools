# PriorityQueue

`next-pending.rex` is a small reusable ooRexx tool that finds the next
not-yet-done entry in a flat, pipe-delimited priority queue file. It
handles the bookkeeping (parsing the queue, skipping comments/blanks,
checking sentinel files) so callers don't have to reimplement it —
factored out after the same pattern showed up twice in
`session-2026-05-02.rex` (once for Baen Book-CD downloads, once for
Book-CD extraction).

The tool does not perform the actual work and does not write the
sentinel; it only reports which item is next. The caller does the work
and marks the sentinel itself once it succeeds — this keeps "what's
next" separate from "what to do with it."

## Usage

```
rexx next-pending.rex /QUEUE:path /SENTINELDIR:dir [/SENTINELPREFIX:text]
```

| Option | Default | Description |
|---|---|---|
| `/QUEUE:path` | *(required)* | Queue file to read |
| `/SENTINELDIR:dir` | *(required)* | Directory holding sentinel files |
| `/SENTINELPREFIX:text` | `.queue-` | Sentinel file = `dir\prefix<ID>-done` |

## Queue file format

One entry per line, pipe-delimited, first field is the ID used to build
the sentinel filename:

```
# comments and blank lines are ignored
ID|field2|field3|...
```

## Output

- Match found: prints the full matching line to stdout, exits 0.
- Nothing pending (all done, or queue empty): prints nothing, exits 1.
- Error (missing file, bad args): prints `ERROR: ...` to stdout, exits 2.

## Requirements

- ooRexx 5.x

## Author

Shmuel (Seymour J. Metz) (שְׁמוּאֵל בֵּן ל״ביש) <smetz3@gmu.edu>

## License

MIT — see [LICENSE](LICENSE).
