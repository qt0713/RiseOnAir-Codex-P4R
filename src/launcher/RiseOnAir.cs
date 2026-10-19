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
  public static volatile bool ResumeCompleted;
  public static volatile bool ResumeFailed;
  static volatile bool themeVerified;
  public static readonly ManualResetEvent StartupFinished=new ManualResetEvent(true);
  public static readonly string IntroEventName="Local\\RiseOnAir.IntroFinished."+Guid.NewGuid().ToString("N");
  public static readonly EventWaitHandle IntroFinished=new EventWaitHandle(false,EventResetMode.ManualReset,IntroEventName);
  static bool resumeAttempted;
  static IntPtr sessionWindow;
  static string launchToken;
  static readonly object LogLock=new object();
  [DllImport("user32.dll")] static extern bool SetForegroundWindow(IntPtr window);
  [DllImport("user32.dll")] static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] static extern bool ShowWindowAsync(IntPtr window,int command);
  [DllImport("user32.dll")] static extern bool IsIconic(IntPtr window);
  [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr window);
  [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr window,out uint pid);
  [DllImport("user32.dll")] static extern IntPtr FindWindow(string className,string title);
  public static void Log(string message) {
   try { lock(LogLock) File.AppendAllText(Path.Combine(Home,"launcher.log"),DateTime.UtcNow.ToString("o")+" "+message+Environment.NewLine,Encoding.UTF8); } catch { }
  }
  public static IntPtr CodexWindow() {
   if(resumeAttempted)return IsWindowVisible(sessionWindow)?sessionWindow:IntPtr.Zero;
   return CodexSession.Window();
  }
  public static void Activate(IntPtr handle) {
   if(handle==IntPtr.Zero)return;
   if(IsIconic(handle))ShowWindowAsync(handle,9);
   else if(!IsWindowVisible(handle))ShowWindowAsync(handle,5);
   if(GetForegroundWindow()!=handle)SetForegroundWindow(handle);
  }
  public static bool IsReady() {
   if(CodexWindow()==IntPtr.Zero)return false;
   if(themeVerified)return true;
   if(!File.Exists(Path.Combine(Home,"integration.json")))return true;
   try {return launchToken!=null && File.ReadAllText(Path.Combine(Home,"LaunchReady.flag")).Trim()==launchToken;}catch{return false;}
  }
  static Process ThemeProcess(bool login,bool background) {
   launchToken=Guid.NewGuid().ToString("N");
   var shell=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Windows),@"System32\WindowsPowerShell\v1.0\powershell.exe");
   var script=Path.Combine(Home,"scripts","Theme-Control.ps1");
   return Process.Start(new ProcessStartInfo(shell,"-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy RemoteSigned -File \""+script+"\" -Action "+(login?"Login":"Apply")+" -LaunchToken "+launchToken+(background?" -Background":"")+(ResumeCompleted?" -NativeWindow "+sessionWindow.ToInt64():" -EnsureSession")+(login?"":" -IntroEventName "+IntroEventName)) {UseShellExecute=false,CreateNoWindow=true,WindowStyle=ProcessWindowStyle.Hidden});
  }
  public static void OpenCodex() {
   resumeAttempted=true;
   ResumeFailed=false;
   themeVerified=false;
   ResumeCompleted=ResumeVerifiedSession();
   ExistingSession=ResumeCompleted;
   Log("resume-complete="+ResumeCompleted);
   if(ResumeCompleted){themeVerified=true;Log("ready verified-existing-theme");return;}
   var themeScript=Path.Combine(Home,"scripts","Theme-Control.ps1");
   if(File.Exists(themeScript)&&File.Exists(Path.Combine(Home,"integration.json"))) {
    var ready=Path.Combine(Home,"LaunchReady.flag");if(File.Exists(ready))File.Delete(ready);
    using(var process=ThemeProcess(false,false)) {
     Log("theme-activation-requested");
      if(!process.WaitForExit(150000)||process.ExitCode!=0){ResumeFailed=true;Log("theme-start-failed");return;}
      var windowFlag=Path.Combine(Home,"LaunchWindow-"+launchToken+".flag");
      try {ResumeCompleted=AcceptWindowFlag(windowFlag);}catch{ResumeCompleted=false;}
      finally{try{File.Delete(windowFlag);}catch{}}
      if(!ResumeCompleted)ResumeCompleted=ResumeVerifiedSession();ResumeFailed=!ResumeCompleted;
      Log("new-session-resume="+ResumeCompleted);
    }
    return;
   }
   ActivatePackage();
  }
  static void ActivatePackage() {
   var appId=File.ReadAllText(Path.Combine(Home,"CodexAppId.txt")).Trim();
   if(!Regex.IsMatch(appId,@"^[A-Za-z0-9._-]+![A-Za-z0-9._-]+$")) throw new InvalidDataException("Invalid application identifier.");
   Process.Start(new ProcessStartInfo("explorer.exe","shell:AppsFolder\\"+appId) {UseShellExecute=true,WindowStyle=ProcessWindowStyle.Hidden});
   Log("codex-activation-requested "+appId);
  }
  static bool ResumeVerifiedSession() {
   var token=Guid.NewGuid().ToString("N");var flag=Path.Combine(Home,"Resume-"+token+".flag");
   var shell=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Windows),@"System32\WindowsPowerShell\v1.0\powershell.exe");
   try {
    using(var process=Process.Start(new ProcessStartInfo(shell,"-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy RemoteSigned -File \""+Path.Combine(Home,"scripts","Resume-Session.ps1")+"\" -LaunchToken "+token+" -IntroEventName "+IntroEventName){UseShellExecute=false,CreateNoWindow=true,WindowStyle=ProcessWindowStyle.Hidden})) {
     if(!process.WaitForExit(30000)||process.ExitCode!=0)return false;
    }
    return AcceptWindowFlag(flag);
   }catch(Exception ex){Log("resume-error "+ex.Message);return false;}
   finally{try{if(File.Exists(flag))File.Delete(flag);}catch{}}
  }
  static bool AcceptWindowFlag(string flag) {
    long handle;if(!long.TryParse(File.ReadAllText(flag),out handle))return false;
    uint pid;var window=new IntPtr(handle);GetWindowThreadProcessId(window,out pid);
    if(!CodexSession.ProcessIds().Contains((int)pid)||!IsWindowVisible(window))return false;
    sessionWindow=window;Log("resume-verified-main-window pid="+pid+" handle="+handle);return true;
  }
  [STAThread] public static int Main(string[] args) {
   AppDomain.CurrentDomain.ProcessExit+=(sender,eventArgs)=>Log("exit");
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
    if(!owns) { var player=FindWindow(null,"Codex · Rise On Air");Activate(player!=IntPtr.Zero?player:CodexWindow());Log("duplicate-launch-activated");return 0; }
    ExistingSession=!Preview && (CodexWindow()!=IntPtr.Zero || CodexSession.HasMainProcess());
    Log("manual-intro existing="+ExistingSession);
    var initialWindow=CodexSession.Window(true);Log("session-window="+(initialWindow==IntPtr.Zero?"none":IsWindowVisible(initialWindow)?"visible":"hidden"));
    try {
     var app=new Application {ShutdownMode=ShutdownMode.OnMainWindowClose};
     app.DispatcherUnhandledException+=(sender,eventArgs)=>{Log("unhandled "+eventArgs.Exception.Message);eventArgs.Handled=true;app.Shutdown(1);};
     app.Run(new WebLaunchWindow(args.Contains("--self-test")));
     Log("window-closed");StartupFinished.WaitOne();return 0;
    } catch(Exception ex) {
     Log("fatal "+ex);
     if(!Preview) {try {OpenCodex();} catch(Exception launchError) {MessageBox.Show("无法打开 Codex："+launchError.Message,"Rise On Air");}}
     return 1;
    }
   }
  }
 }

}

