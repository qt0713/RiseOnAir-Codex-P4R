using System;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Animation;
using System.Windows.Media.Imaging;
using System.Windows.Threading;

namespace RiseOnAir {
 public static class Program {
  public static readonly string Home=AppDomain.CurrentDomain.BaseDirectory;
  public static bool Preview;
  public static bool Muted;
  public static bool ExistingSession;
  static string launchToken;
  static readonly object LogLock=new object();
  [DllImport("user32.dll")] static extern bool SetForegroundWindow(IntPtr window);
  [DllImport("user32.dll")] static extern bool ShowWindowAsync(IntPtr window,int command);
  [DllImport("user32.dll")] static extern bool IsIconic(IntPtr window);
  [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr window);
  [DllImport("user32.dll")] static extern IntPtr FindWindow(string className,string title);
  public static void Log(string message) {
   try { lock(LogLock) File.AppendAllText(Path.Combine(Home,"launcher.log"),DateTime.UtcNow.ToString("o")+" "+message+Environment.NewLine,Encoding.UTF8); } catch { }
  }
  public static IntPtr CodexWindow() {
   foreach(var process in Process.GetProcessesByName("ChatGPT")) {
    try { using(process) {
     if(process.MainWindowHandle==IntPtr.Zero || !IsWindowVisible(process.MainWindowHandle)) continue;
     var location=process.MainModule.FileName;
     if(location.IndexOf("OpenAI.Codex_",StringComparison.OrdinalIgnoreCase)>=0) return process.MainWindowHandle;
    }} catch { }
   }
   return IntPtr.Zero;
  }
  public static void Activate(IntPtr handle) {
   if(handle==IntPtr.Zero)return;
   ShowWindowAsync(handle,IsIconic(handle)?9:5);
   SetForegroundWindow(handle);
  }
  public static bool IsReady() {
   if(CodexWindow()==IntPtr.Zero)return false;
   if(!File.Exists(Path.Combine(Home,"integration.json")))return true;
   try {return launchToken!=null && File.ReadAllText(Path.Combine(Home,"LaunchReady.flag")).Trim()==launchToken;}catch{return false;}
  }
  static Process ThemeProcess(bool login,bool background) {
   launchToken=Guid.NewGuid().ToString("N");
   var shell=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Windows),@"System32\WindowsPowerShell\v1.0\powershell.exe");
   var script=Path.Combine(Home,"scripts","Theme-Control.ps1");
   return Process.Start(new ProcessStartInfo(shell,"-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy RemoteSigned -File \""+script+"\" -Action "+(login?"Login":"Apply")+" -LaunchToken "+launchToken+(background?" -Background":"")) {UseShellExecute=false,CreateNoWindow=true,WindowStyle=ProcessWindowStyle.Hidden});
  }
  public static void OpenCodex() {
   var themeScript=Path.Combine(Home,"scripts","Theme-Control.ps1");
   if(File.Exists(themeScript)&&File.Exists(Path.Combine(Home,"integration.json"))) {
    var ready=Path.Combine(Home,"LaunchReady.flag");if(File.Exists(ready))File.Delete(ready);
    using(var process=ThemeProcess(false,ExistingSession)) { }
    Log("theme-activation-requested");return;
   }
   var appId=File.ReadAllText(Path.Combine(Home,"CodexAppId.txt")).Trim();
   if(!Regex.IsMatch(appId,@"^[A-Za-z0-9._-]+![A-Za-z0-9._-]+$")) throw new InvalidDataException("Invalid application identifier.");
   Process.Start(new ProcessStartInfo("explorer.exe","shell:AppsFolder\\"+appId) {UseShellExecute=true,WindowStyle=ProcessWindowStyle.Hidden});
   Log("codex-activation-requested "+appId);
  }
  [STAThread] public static int Main(string[] args) {
   Preview=args.Contains("--preview") || args.Contains("--self-test");
   Muted=args.Contains("--muted");
   Log("begin preview="+Preview+" muted="+Muted);
   if(args.Contains("--login")) {
    bool loginOwns;
    using(var loginMutex=new Mutex(true,"Local\\RiseOnAir.Login",out loginOwns)) {
     if(!loginOwns)return 0;
     try {using(var process=ThemeProcess(true,true)){process.WaitForExit();return process.ExitCode;}}catch(Exception ex){Log("login-error "+ex.Message);return 1;}
    }
   }
   bool owns;
   using(var mutex=new Mutex(true,"Local\\RiseOnAir.Codex.Launcher",out owns)) {
    if(!owns) { Activate(FindWindow(null,"Codex · Rise On Air"));Log("duplicate-launch-ignored");return 0; }
    ExistingSession=!Preview && CodexWindow()!=IntPtr.Zero;
    Log("manual-intro existing="+ExistingSession);
    try {
     var app=new Application {ShutdownMode=ShutdownMode.OnMainWindowClose};
     app.DispatcherUnhandledException+=(sender,eventArgs)=>{Log("unhandled "+eventArgs.Exception.Message);eventArgs.Handled=true;app.Shutdown(1);};
     app.Run(new WebLaunchWindow(args.Contains("--self-test")));
     Log("exit");return 0;
    } catch(Exception ex) {
     Log("fatal "+ex);
     if(!Preview) {try {OpenCodex();} catch(Exception launchError) {MessageBox.Show("无法打开 Codex："+launchError.Message,"Rise On Air");}}
     return 1;
    }
   }
  }
 }

}

