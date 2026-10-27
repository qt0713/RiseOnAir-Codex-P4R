using System;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Animation;
using System.Windows.Threading;
using Microsoft.Web.WebView2.Core;
using Microsoft.Web.WebView2.Wpf;

namespace RiseOnAir {
 public class WebLaunchWindow:Window {
  readonly WebView2 browser=new WebView2();
  readonly DispatcherTimer timer=new DispatcherTimer();
  readonly Stopwatch lifetime=Stopwatch.StartNew();
  readonly bool selfTest;
  bool playing,waiting,closing,activationRequested,introFinished,waitNoticeShown;
  int activationInFlight;
  double playStart,waitStart;
  [DllImport("user32.dll")] static extern bool ReleaseCapture();
  [DllImport("user32.dll")] static extern IntPtr SendMessage(IntPtr hwnd,uint message,IntPtr wParam,IntPtr lParam);
  public WebLaunchWindow(bool capture) {
   selfTest=capture;Title="Codex · Rise On Air";WindowStyle=WindowStyle.None;ResizeMode=ResizeMode.NoResize;ShowInTaskbar=false;Topmost=true;
   Background=new SolidColorBrush(Color.FromRgb(36,33,36));
   Width=800;Height=498;WindowStartupLocation=WindowStartupLocation.Manual;
   SourceInitialized+=(s,e)=>WindowPlacement.Attach(this);
   browser.DefaultBackgroundColor=System.Drawing.Color.FromArgb(255,36,33,36);Content=browser;
   Loaded+=async(s,e)=>{Program.Log("window-shown renderer=WebView2");if(!Program.Preview)RequestCodex();await Initialize();};
   // Never keep an intro/wait surface above another app the user selects.
   Deactivated+=(s,e)=>{Topmost=false;};
   timer.Interval=TimeSpan.FromMilliseconds(100);timer.Tick+=(s,e)=>Tick();timer.Start();
   Closing+=(s,e)=>{Program.IntroFinished.Set();closing=true;timer.Stop();ReleaseCapture();System.Windows.Input.Mouse.Capture(null);Topmost=false;browser.Dispose();};
   Closed+=(s,e)=>{if(!Program.Preview)Program.Activate(Program.CodexWindow());};
  }
  async Task Initialize() {
   try {
    var options=new CoreWebView2EnvironmentOptions("--autoplay-policy=no-user-gesture-required");
    var environment=await CoreWebView2Environment.CreateAsync(null,Path.Combine(Program.Home,"WebViewData"),options);
    if(closing)return;
    await browser.EnsureCoreWebView2Async(environment);
    var core=browser.CoreWebView2;
    core.Settings.AreDefaultContextMenusEnabled=false;core.Settings.AreDevToolsEnabled=false;core.Settings.IsStatusBarEnabled=false;core.Settings.IsZoomControlEnabled=false;core.Settings.AreBrowserAcceleratorKeysEnabled=false;
    core.SetVirtualHostNameToFolderMapping("rise-on-air.local",Program.Home,CoreWebView2HostResourceAccessKind.DenyCors);
    core.NavigationStarting+=(s,e)=>{Uri uri;if(!Uri.TryCreate(e.Uri,UriKind.Absolute,out uri)||uri.Host!="rise-on-air.local")e.Cancel=true;};
    core.NewWindowRequested+=(s,e)=>{e.Handled=true;};
    core.WebMessageReceived+=Message;
    core.ProcessFailed+=(s,e)=>{Program.Log("webview-process-failed "+e.ProcessFailedKind);Finish("renderer-failed");};
    Program.Log("webview-ready version="+environment.BrowserVersionString);
    core.Navigate("https://rise-on-air.local/startup.html"+(Program.Muted?"?muted=1":""));
   } catch(Exception ex) {Program.Log("webview-error "+ex.Message);if(!Program.Preview)RequestCodex();Close();}
  }
  async void Message(object sender,CoreWebView2WebMessageReceivedEventArgs args) {
   if(closing||!args.Source.StartsWith("https://rise-on-air.local/",StringComparison.OrdinalIgnoreCase))return;
   string message;try{message=args.TryGetWebMessageAsString();}catch{return;}
   if(message.Length>1024)return;
   Program.Log("player "+message);
   if(message=="drag"||message=="resize")Dispatcher.BeginInvoke(new Action(()=>{ReleaseCapture();SendMessage(new System.Windows.Interop.WindowInteropHelper(this).Handle,0xA1,new IntPtr(message=="drag"?2:17),IntPtr.Zero);}));
   if(message.StartsWith("playing")){playing=true;playStart=lifetime.Elapsed.TotalSeconds;}
   if(message=="ended"){Finish("media-ended");}
   if(message=="skip"){Finish("skip");}
   if(message.StartsWith("error")){Finish("media-failed");}
   if(message=="retry"){activationRequested=false;waitNoticeShown=false;RequestCodex();waiting=true;waitStart=lifetime.Elapsed.TotalSeconds;Script("showWaiting(false)");}
   if(message=="close"){FadeClose();}
   if(message=="capture"&&selfTest) {
    try{using(var image=File.Create(Path.Combine(Program.Home,"SelfTest.png"))){await browser.CoreWebView2.CapturePreviewAsync(CoreWebView2CapturePreviewImageFormat.Png,image);}Program.Log("snapshot-saved");}catch(Exception ex){Program.Log("snapshot-error "+ex.Message);}
   }
  }
  void RequestCodex() {
   if(activationRequested||System.Threading.Interlocked.CompareExchange(ref activationInFlight,1,0)!=0)return;activationRequested=true;
   Program.StartupFinished.Reset();
   // Skipping/closing the intro must not abort a still-starting application.
   new System.Threading.Thread(()=>{try{Program.OpenCodex();}catch(Exception ex){Program.ResumeFailed=true;Program.Log("activation-error "+ex.Message);Program.OpenOfficialFallback();}finally{System.Threading.Interlocked.Exchange(ref activationInFlight,0);Program.StartupFinished.Set();}}){IsBackground=false,Name="Rise On Air startup"}.Start();
  }
  void Tick() {
   if(closing)return;
   if(waiting) {
    if(Program.StartupFinished.WaitOne(0)&&Program.OfficialFallback){Program.Log("handoff-official-fallback");FadeClose();return;}
    if(Program.ResumeFailed&&!waitNoticeShown){Topmost=false;waitNoticeShown=true;Script("showWaiting(true)");}
    if(Program.StartupFinished.WaitOne(0)&&Program.IsReady()&&!Program.ResumeFailed){Program.Log("handoff-verified-window");FadeClose();return;}
    if(lifetime.Elapsed.TotalSeconds-waitStart>20){Program.Log("intro-wait-budget-ended startup-continues");FadeClose();}return;
   }
   if(introFinished)return;
   if(!playing&&lifetime.Elapsed.TotalSeconds>10){Program.Log("player-open-timeout");Finish("media-open-timeout");}
   if(playing&&lifetime.Elapsed.TotalSeconds-playStart>5.5){Program.Log("player-end-timeout");Finish("media-end-timeout");}
  }
  void Script(string code){if(browser.CoreWebView2!=null&&!closing)browser.CoreWebView2.ExecuteScriptAsync(code);}
  void Finish(string reason) {
   Program.IntroFinished.Set();
   // Esc must also work after the animation has entered the waiting state.
   if(closing)return;
   if(reason=="skip"){Program.Log("finish skip");FadeClose();return;}
   if(waiting||introFinished)return;introFinished=true;Topmost=false;Program.Log("finish "+reason);
   if(Program.Preview||(Program.StartupFinished.WaitOne(0)&&Program.IsReady()&&!Program.ResumeFailed)){FadeClose();return;}
   playing=false;waiting=true;waitStart=lifetime.Elapsed.TotalSeconds;Script(Program.ResumeFailed?"showWaiting(true)":"showWaiting(false)");
  }
  void FadeClose() {
   if(closing)return;closing=true;timer.Stop();
   ReleaseCapture();System.Windows.Input.Mouse.Capture(null);IsHitTestVisible=false;
   var fade=new DoubleAnimation(Opacity,0,TimeSpan.FromMilliseconds(160));fade.Completed+=(s,e)=>{Hide();Close();};BeginAnimation(OpacityProperty,fade);
  }
 }
}
