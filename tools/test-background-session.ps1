[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$test=Join-Path $root ('build\background-tests-'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $test|Out-Null
$fixture=@'
using System;using System.Collections.Generic;using System.Diagnostics;using System.IO;using System.Windows.Forms;using RiseOnAir;
class BackgroundFixture { [System.Runtime.InteropServices.DllImport("user32.dll",CharSet=System.Runtime.InteropServices.CharSet.Unicode)] static extern int GetClassName(IntPtr window,System.Text.StringBuilder name,int count);
 static void Check(bool condition,string message){if(!condition)throw new Exception(message);}
 [STAThread] static int Main(){try{Run();return 0;}catch(Exception e){Console.WriteLine(e.GetType().Name+": "+e.Message);return 1;}} static void Run(){
  // Own fixture only: never hide, close or restart the real Codex window.
  var exe=Process.GetCurrentProcess().MainModule.FileName;
  File.WriteAllText(Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"CodexExe.txt"),exe);
  var ids=new HashSet<int>{Process.GetCurrentProcess().Id};
  using(var window=new Form()){window.Text="Rise background fixture";window.Show();Application.DoEvents();
   var hwnd=window.Handle; var name=new System.Text.StringBuilder(256);GetClassName(hwnd,name,256);var kind=name.ToString();
   Check(CodexSession.FindWindowForProcesses(ids,kind)==hwnd,"Visible window missing");
   window.WindowState=FormWindowState.Minimized;Application.DoEvents();
   Check(CodexSession.FindWindowForProcesses(ids,kind)==hwnd,"Minimized window missing");
   window.Hide();Application.DoEvents();
   Check(Process.GetCurrentProcess().MainWindowHandle==IntPtr.Zero,"Fixture must reproduce MainWindowHandle=0");
   Check(CodexSession.FindWindowForProcesses(ids,kind)==hwnd,"Hidden resident window missing");
   Check(CodexSession.FindWindowForProcesses(ids,kind,false)==IntPtr.Zero,"Hidden window falsely reported visible/ready");
   Check(CodexSession.HasMainProcess(),"Resident main process missing");
   window.Close();Application.DoEvents();
   Check(CodexSession.FindWindowForProcesses(ids,kind)==IntPtr.Zero,"Destroyed window still detected");
   Check(CodexSession.HasMainProcess(),"Windowless resident process missing");
  }
  Console.WriteLine("PASS visible / minimized / hidden / windowless resident detection; original hidden-window failure reproduced");
 }
}
'@
$source=Join-Path $test 'Fixture.cs';[IO.File]::WriteAllText($source,$fixture)
$framework=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319'
& (Join-Path $framework 'csc.exe') /nologo /target:exe /platform:x64 ('/out:'+(Join-Path $test 'ChatGPT.exe')) /reference:System.Windows.Forms.dll /reference:System.Drawing.dll /reference:System.Management.dll (Join-Path $root 'src\launcher\CodexSession.cs') $source
if($LASTEXITCODE -ne 0){throw 'Fixture compilation failed.'}
& (Join-Path $test 'ChatGPT.exe')
if($LASTEXITCODE -ne 0){throw 'Background session regression failed.'}
