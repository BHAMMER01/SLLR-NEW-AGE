param(
  [string]$GameRoot=(Join-Path $PSScriptRoot '..\build\verification\telemetry\root-20261125-065337'),
  [string]$Exe=(Join-Path $PSScriptRoot '..\build\Release\slrr_host.exe')
)
$ErrorActionPreference='Stop'
$drawing = Get-ChildItem 'C:\Program Files\dotnet\shared\Microsoft.WindowsDesktop.App\8.0.16' -Filter System.Drawing.Common.dll |
  Select-Object -First 1 -ExpandProperty FullName
Add-Type -Path $drawing
Add-Type -ReferencedAssemblies $drawing @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
public static class SlrrCapture {
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc p, IntPtr l);
  [DllImport("user32.dll")] static extern void GetWindowThreadProcessId(IntPtr h, out uint p);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] static extern int GetWindowText(IntPtr h, System.Text.StringBuilder s, int n);
  public struct RECT { public int Left,Top,Right,Bottom; }
  delegate bool EnumProc(IntPtr h,IntPtr l);
  public static IntPtr Find(uint pid){ IntPtr x=IntPtr.Zero; EnumWindows((h,l)=>{uint p;GetWindowThreadProcessId(h,out p);var s=new System.Text.StringBuilder(128);GetWindowText(h,s,128);if(p==pid&&s.ToString().StartsWith("OpenSLRR")){x=h;return false;}return true;},IntPtr.Zero);return x; }
  public static void Capture(IntPtr h,string path){ RECT r; if(!GetWindowRect(h,out r)) throw new Exception("GetWindowRect failed"); int w=r.Right-r.Left,ht=r.Bottom-r.Top; using(var b=new Bitmap(w,ht)){using(var g=Graphics.FromImage(b)){g.CopyFromScreen(r.Left,r.Top,0,0,b.Size);}b.Save(path,ImageFormat.Png);} }
}
'@
$root=(Resolve-Path $GameRoot).Path; $exe=(Resolve-Path $Exe).Path
$a1=Join-Path $root 'maps\city\smallmap\meshes\a1.SCX'; $backup=Join-Path $root 'perf\a1.before.SCX'; $round=Join-Path $root 'perf\city_a1_roundtrip.scx'
Copy-Item $a1 $backup -Force; Copy-Item $round $a1 -Force
$stamp=Get-Date -Format yyyyMMdd-HHmmss; $out=Join-Path $root "perf\city-roundtrip-$stamp.log"; $err=$out+'.err'
$p=Start-Process $exe -WorkingDirectory (Split-Path $exe) -ArgumentList @('--game','--window','--no-vsync','--root',$root,'--spawn-car','cars/racers/Baiern.rpk:0x6','--auto-city','--renderer','vulkan') -RedirectStandardOutput $out -RedirectStandardError $err -PassThru
Start-Sleep 15; $h=[SlrrCapture]::Find($p.Id); if($h -eq [IntPtr]::Zero){Copy-Item $backup $a1 -Force; throw 'janela OpenSLRR nao encontrada'}
[SlrrCapture]::SetForegroundWindow($h)|Out-Null; $shot=Join-Path $root "perf\city-roundtrip-$stamp.png"; [SlrrCapture]::Capture($h,$shot)
if(!$p.HasExited){$p.Kill()}; $p.WaitForExit(); Copy-Item $backup $a1 -Force
[pscustomobject]@{Screenshot=$shot;Log=$out;ExitCode=$p.ExitCode}|Format-List
