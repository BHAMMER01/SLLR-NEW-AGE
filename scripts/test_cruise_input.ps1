param(
  [string] $GameRoot = 'C:\games\SLRROPENCLEAN\SLRR-NEWAGE\Street Legal Racing - Redline',
  [string] $Exe = (Join-Path $PSScriptRoot '..\build\Release\slrr_host.exe'),
  [int] $WaitSeconds = 20
)

$ErrorActionPreference = 'Stop'
$GameRoot = (Resolve-Path -LiteralPath $GameRoot).Path
$Exe = (Resolve-Path -LiteralPath $Exe).Path
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$outDir = (Resolve-Path (Join-Path $PSScriptRoot '..\build')).Path
$stdout = Join-Path $outDir "cruise-input-$stamp.out.log"
$stderr = Join-Path $outDir "cruise-input-$stamp.err.log"

if (-not ('SlrrInput.Native' -as [type])) {
  Add-Type @'
using System;
using System.Runtime.InteropServices;
using System.Text;
namespace SlrrInput {
  public static class Native {
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr hWnd, uint msg, UIntPtr wParam, IntPtr lParam);
    [StructLayout(LayoutKind.Sequential)] public struct INPUT { public uint type; public KEYBDINPUT ki; }
    [StructLayout(LayoutKind.Sequential)] public struct KEYBDINPUT {
      public ushort wVk; public ushort wScan; public uint dwFlags; public uint time; public IntPtr dwExtraInfo;
    }
    [DllImport("user32.dll", SetLastError=true)] public static extern uint SendInput(uint nInputs, INPUT[] inputs, int cbSize);
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
    [DllImport("user32.dll")] static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint pid);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int count);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr hWnd);
    public static IntPtr FindGameWindow(int processId) {
      IntPtr found = IntPtr.Zero;
      EnumWindows((h, l) => {
        uint pid; GetWindowThreadProcessId(h, out pid);
        if (pid != (uint)processId || !IsWindowVisible(h)) return true;
        var title = new StringBuilder(256); GetWindowText(h, title, title.Capacity);
        if (title.ToString().StartsWith("OpenSLRR", StringComparison.OrdinalIgnoreCase)) { found = h; return false; }
        return true;
      }, IntPtr.Zero);
      return found;
    }
    public static void Key(ushort vk, bool up) {
      var i = new INPUT[1]; i[0].type=1; i[0].ki.wVk=vk; i[0].ki.dwFlags=up ? 2u : 0u;
      SendInput(1, i, Marshal.SizeOf(typeof(INPUT)));
    }
    public static void PostKey(IntPtr hwnd, ushort vk, ushort scan, bool up) {
      uint msg = up ? 0x0101u : 0x0100u;
      long lp = ((long)scan << 16) | (up ? 0xC0000000L : 0L);
      PostMessage(hwnd, msg, (UIntPtr)vk, (IntPtr)lp);
    }
  }
}
'@
}

$si = [Diagnostics.ProcessStartInfo]::new()
$si.FileName = $Exe
$si.WorkingDirectory = Split-Path $Exe
$si.UseShellExecute = $false
$si.RedirectStandardOutput = $true
$si.RedirectStandardError = $true
$si.Arguments = '--game --window --no-vsync --root "' + $GameRoot + '" --spawn-car cars/racers/Baiern.rpk:0x6 --auto-city --seed 3 --renderer vulkan'
$proc = [Diagnostics.Process]::new()
$proc.StartInfo = $si
[void]$proc.Start()
$outTask = $proc.StandardOutput.ReadToEndAsync()
$errTask = $proc.StandardError.ReadToEndAsync()

try {
  $deadline = (Get-Date).AddSeconds($WaitSeconds)
  do {
    Start-Sleep -Milliseconds 250
    $proc.Refresh()
    $proc = Get-Process -Id $proc.Id -ErrorAction SilentlyContinue
    if ($proc) {
      $hwnd = [SlrrInput.Native]::FindGameWindow($proc.Id)
      if ($hwnd -ne [IntPtr]::Zero) { break }
    }
  } while ($proc -and (Get-Date) -lt $deadline)
  if (-not $proc -or $hwnd -eq [IntPtr]::Zero) { throw 'slrr_host did not expose the OpenSLRR game window' }
  [SlrrInput.Native]::SetForegroundWindow($hwnd) | Out-Null
  # Splash/preload must finish before the controller and its hotkeys exist.
  Start-Sleep -Seconds 15

  # W then S must never generate a cruise press. P activates it first; the
  # following S must generate only the release edge that cancels it.
  [SlrrInput.Native]::PostKey($hwnd,0x57,0x11,$false); Start-Sleep -Milliseconds 1200; [SlrrInput.Native]::PostKey($hwnd,0x57,0x11,$true)
  Start-Sleep -Milliseconds 500
  [SlrrInput.Native]::PostKey($hwnd,0x53,0x1f,$false); Start-Sleep -Milliseconds 700; [SlrrInput.Native]::PostKey($hwnd,0x53,0x1f,$true)
  Start-Sleep -Milliseconds 500
  [SlrrInput.Native]::PostKey($hwnd,0x50,0x19,$false); Start-Sleep -Milliseconds 250; [SlrrInput.Native]::PostKey($hwnd,0x50,0x19,$true)
  Start-Sleep -Milliseconds 500
  [SlrrInput.Native]::PostKey($hwnd,0x53,0x1f,$false); Start-Sleep -Milliseconds 700; [SlrrInput.Native]::PostKey($hwnd,0x53,0x1f,$true)
  Start-Sleep -Seconds 2
} finally {
  if ($proc -and -not $proc.HasExited) { Stop-Process -Id $proc.Id -Force }
  if ($outTask) { [IO.File]::WriteAllText($stdout, $outTask.Result) }
  if ($errTask) { [IO.File]::WriteAllText($stderr, $errTask.Result) }
}

$events = @()
if (Test-Path $stdout) { $events = @(Select-String -Path $stdout -Pattern '\[input-hotkey\]') }
[pscustomobject]@{ Stdout=$stdout; Stderr=$stderr; HotkeyEvents=$events.Count; Events=($events -join "`n") } | Format-List
