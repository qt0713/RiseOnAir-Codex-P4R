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
   timer.Interval=TimeSpan.FromMilliseconds(100);timer.Tick+=(s,e)=>Tick();timer.Start();
   Closing+=(s,e)=>{closing=true;timer.Stop();browser.Dispose();};
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
   if(activationRequested)return;activationRequested=true;
   Task.Run(()=>{try{Program.OpenCodex();}catch(Exception ex){Program.Log("activation-error "+ex.Message);Dispatcher.BeginInvoke(new Action(()=>{waiting=false;Script("showWaiting(true)");}));}});
  }
  void Tick() {
   if(closing)return;
   if(waiting) {
    if(Program.IsReady()){FadeClose();return;}
    if(lifetime.Elapsed.TotalSeconds-waitStart>45&&!waitNoticeShown){waitNoticeShown=true;Script("showWaiting(true)");}return;
   }
   if(introFinished)return;
   if(!playing&&lifetime.Elapsed.TotalSeconds>10){Program.Log("player-open-timeout");Finish("media-open-timeout");}
   if(playing&&lifetime.Elapsed.TotalSeconds-playStart>5.5){Program.Log("player-end-timeout");Finish("media-end-timeout");}
  }
  void Script(string code){if(browser.CoreWebView2!=null&&!closing)browser.CoreWebView2.ExecuteScriptAsync(code);}
  void Finish(string reason) {
   if(closing||waiting||introFinished)return;introFinished=true;Program.Log("finish "+reason);
   if(Program.Preview||reason=="skip"||Program.IsReady()){FadeClose();return;}
   playing=false;waiting=true;waitStart=lifetime.Elapsed.TotalSeconds;Script("showWaiting(false)");
  }
  void FadeClose() {
   if(closing)return;closing=true;timer.Stop();
   var fade=new DoubleAnimation(Opacity,0,TimeSpan.FromMilliseconds(160));fade.Completed+=(s,e)=>Close();BeginAnimation(OpacityProperty,fade);
  }
 }
}
