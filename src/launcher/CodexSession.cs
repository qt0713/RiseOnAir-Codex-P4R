using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Management;
using System.Runtime.InteropServices;
using System.Text;

namespace RiseOnAir {
 public static class CodexSession {
  delegate bool WindowVisitor(IntPtr window,IntPtr parameter);
  [DllImport("user32.dll")] static extern bool EnumWindows(WindowVisitor visitor,IntPtr parameter);
  [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr window,out uint pid);
  [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr window);
  [DllImport("user32.dll")] static extern IntPtr GetWindow(IntPtr window,uint command);
  [DllImport("user32.dll",CharSet=CharSet.Unicode)] static extern int GetClassName(IntPtr window,StringBuilder name,int count);
  [DllImport("user32.dll",CharSet=CharSet.Unicode)] static extern int GetWindowText(IntPtr window,StringBuilder text,int count);
  [DllImport("kernel32.dll",CharSet=CharSet.Unicode)] static extern int GetPackageFamilyName(IntPtr process,ref uint length,StringBuilder family);
  static bool IsRegisteredCodex(Process process,string expected) {
   uint size=256;var family=new StringBuilder((int)size);
   if(GetPackageFamilyName(process.Handle,ref size,family)==0&&family.ToString()=="OpenAI.Codex_2p2nqsd0c76g0")return true;
   // The upstream verified WindowsApps fallback can have no package identity.
   return !string.IsNullOrEmpty(expected)&&string.Equals(process.MainModule.FileName,expected,StringComparison.OrdinalIgnoreCase);
  }
  // EnumWindows includes hidden windows; Process.MainWindowHandle does not.
  public static IntPtr FindWindowForProcesses(HashSet<int> processes,string windowClass,bool includeHidden=true) {
   IntPtr visible=IntPtr.Zero,hidden=IntPtr.Zero;
   EnumWindows(delegate(IntPtr window,IntPtr unused) {
    uint pid;GetWindowThreadProcessId(window,out pid);
    if(!processes.Contains((int)pid)||GetWindow(window,4)!=IntPtr.Zero)return true;
    var name=new StringBuilder(256);GetClassName(window,name,name.Capacity);
    if(windowClass!=null&&name.ToString()!=windowClass)return true;
    var title=new StringBuilder(512);if(GetWindowText(window,title,title.Capacity)==0)return true;
    if(IsWindowVisible(window)){visible=window;return false;}
    if(hidden==IntPtr.Zero)hidden=window;return true;
   },IntPtr.Zero);
   return visible!=IntPtr.Zero?visible:includeHidden?hidden:IntPtr.Zero;
  }
  public static string ExpectedExecutable {
   get {try{return File.ReadAllText(Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"CodexExe.txt")).Trim();}catch{return null;}}
  }
  public static HashSet<int> ProcessIds() {
   var result=new HashSet<int>();var expected=ExpectedExecutable;
   var session=Process.GetCurrentProcess().SessionId;
   foreach(var process in Process.GetProcessesByName("ChatGPT"))using(process) {
    try {if(process.SessionId==session&&IsRegisteredCodex(process,expected))result.Add(process.Id);}catch{}
   }
   return result;
  }
  public static IntPtr Window(bool includeHidden=false){return FindWindowForProcesses(ProcessIds(),"Chrome_WidgetWin_1",includeHidden);}
  public static bool HasMainProcess() {
   var ids=ProcessIds();if(ids.Count==0)return false;
   // Renderer/utility children can linger after exit: only resume the browser.
   using(var search=new ManagementObjectSearcher("SELECT ProcessId,CommandLine FROM Win32_Process WHERE Name='ChatGPT.exe'"))
   using(var results=search.Get())foreach(ManagementObject row in results)using(row) {
    if(!ids.Contains(Convert.ToInt32(row["ProcessId"])))continue;
    var command=row["CommandLine"] as string;
    if(command!=null&&command.IndexOf("--type=",StringComparison.OrdinalIgnoreCase)<0&&command.IndexOf("--type ",StringComparison.OrdinalIgnoreCase)<0)return true;
   }
   return false;
  }
 }
}
