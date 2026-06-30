# Set-Accessibility

PowerShell script to make Windows 11 scrollbars wider and the mouse
cursor more visible. Edits `HKCU` registry keys only; no elevation
required. Changes take effect after sign-out and sign-in.

## Usage

```powershell
Set-Accessibility.ps1
```

Run from `~\bin\` (which must be on `%PATH%`) or with a full path.
If execution policy blocks it:

```powershell
powershell -ExecutionPolicy Bypass -File Set-Accessibility.ps1
```

## What it changes

| Setting | Registry key | Default | New value |
|---|---|---|---|
| Scrollbar width and height | `HKCU\Control Panel\Desktop\WindowMetrics\ScrollWidth` / `ScrollHeight` | `-255` (17 px) | `-450` (30 px) |
| Cursor size | `HKCU\Control Panel\Cursors\CursorBaseSize` | `32` | `64` |
| Cursor size (slider) | `HKCU\SOFTWARE\Microsoft\Accessibility\CursorSize` | `1` | `3` |

## Author

Shmuel (Seymour J. Metz) (שְׁמוּאֵל בֵּן ל״ביש) <smetz3@gmu.edu>

## License

MIT License — see [LICENSE](LICENSE).
