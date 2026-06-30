# Set-Accessibility.ps1
# Makes scrollbars larger and the mouse cursor more visible on Windows 11.
# No elevation needed -- all settings are under HKCU.
# Sign out and back in for changes to take effect.

# Scrollbar width/height: registry value = -15 * pixels
# Default is -255 (17 px); 30 px is noticeably wider without being excessive.
$scrollVal = -15 * 30   # -450

# Cursor size: 32 is default, 64 is clearly larger
$cursorSize = 64

$wmKey   = 'HKCU:\Control Panel\Desktop\WindowMetrics'
$curKey  = 'HKCU:\Control Panel\Cursors'
$accKey  = 'HKCU:\SOFTWARE\Microsoft\Accessibility'

Set-ItemProperty -Path $wmKey  -Name ScrollWidth    -Value ([string]$scrollVal) -Type String
Set-ItemProperty -Path $wmKey  -Name ScrollHeight   -Value ([string]$scrollVal) -Type String
Set-ItemProperty -Path $curKey -Name CursorBaseSize -Value $cursorSize           -Type DWord
# Slider value: (cursorSize - 32) / 16 + 1
Set-ItemProperty -Path $accKey -Name CursorSize     -Value (($cursorSize - 32) / 16 + 1) -Type DWord

Write-Host "Done. Sign out and back in to apply."
