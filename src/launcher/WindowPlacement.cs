using System;
using System.Runtime.InteropServices;
using System.Text.RegularExpressions;
using System.Windows;
using System.Windows.Interop;
namespace RiseOnAir {
 // All monitor geometry here is physical pixels. WPF/WebView handle DIP layout.
 internal class WindowPlacement {
  [StructLayout(LayoutKind.Sequential)] struct Point { public int x,y;public Point(int a,int b){x=a;y=b;} }
  [StructLayout(LayoutKind.Sequential)] struct Rect {public int left,top,right,bottom;}
  [StructLayout(LayoutKind.Sequential)] struct MonitorInfo {public int cbSize;public Rect monitor,work;public uint flags;}
  [StructLayout(LayoutKind.Sequential)] struct MinMax {public Point reserved,maxSize,maxPosition,minTrack,maxTrack;}
  [DllImport("user32.dll")] static extern IntPtr MonitorFromPoint(Point point,uint flags);
  [DllImport("user32.dll")] static extern IntPtr MonitorFromWindow(IntPtr hwnd,uint flags);
  [DllImport("user32.dll")] static extern bool GetMonitorInfo(IntPtr monitor,ref MonitorInfo info);
  [DllImport("user32.dll")] static extern bool SetWindowPos(IntPtr hwnd,IntPtr after,int x,int y,int width,int height,uint flags);
  [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr hwnd,out Rect rect);
  [DllImport("user32.dll")] static extern uint GetDpiForWindow(IntPtr hwnd);
  [DllImport("shcore.dll")] static extern int GetDpiForMonitor(IntPtr monitor,int type,out uint x,out uint y);
  readonly Window window;readonly IntPtr handle;
  WindowPlacement(Window owner){window=owner;handle=new WindowInteropHelper(owner).Handle;HwndSource.FromHwnd(handle).AddHook(Hook);}
  static Rect Work(IntPtr monitor){var info=new MonitorInfo();info.cbSize=Marshal.SizeOf(info);GetMonitorInfo(monitor,ref info);return info.work;}
  public static void Attach(Window window){new WindowPlacement(window).Initial();}
  void Initial(){
   var cursor=System.Windows.Forms.Cursor.Position;var monitor=MonitorFromPoint(new Point(cursor.X,cursor.Y),2);var area=Work(monitor);
   uint dx=96,dy=96;try{GetDpiForMonitor(monitor,0,out dx,out dy);}catch{}
   double scale=Math.Max(1,dx)/96.0;double aw=area.right-area.left,ah=area.bottom-area.top,w,h;
   if(aw/ah<1.1){w=Math.Min(720*scale,aw*.86);h=Math.Min(1280*scale,ah*.86);}
   else {w=Math.Min(1280*scale,Math.Min(aw*.86,(ah*.86-48*scale)*16/9));h=w*9/16+48*scale;}
   if(Program.Preview){foreach(string arg in Environment.GetCommandLineArgs()){var match=Regex.Match(arg,@"^--size=(\d{3,4})x(\d{3,4})$");if(match.Success){w=int.Parse(match.Groups[1].Value)*scale;h=int.Parse(match.Groups[2].Value)*scale;}}}
   Place(new Rect{left=area.left+(int)((aw-w)/2),top=area.top+(int)((ah-h)/2),right=area.left+(int)((aw+w)/2),bottom=area.top+(int)((ah+h)/2)},area);
   Rect actual;GetWindowRect(handle,out actual);Program.Log("window-bounds pixels="+(actual.right-actual.left)+"x"+(actual.bottom-actual.top)+" dpi="+GetDpiForWindow(handle)+" work="+(int)aw+"x"+(int)ah);
  }
  void Place(Rect requested,Rect area){int w=Math.Min(requested.right-requested.left,area.right-area.left),h=Math.Min(requested.bottom-requested.top,area.bottom-area.top);int x=Math.Max(area.left,Math.Min(requested.left,area.right-w)),y=Math.Max(area.top,Math.Min(requested.top,area.bottom-h));SetWindowPos(handle,IntPtr.Zero,x,y,w,h,0x14);}
  IntPtr Hook(IntPtr hwnd,int message,IntPtr wParam,IntPtr lParam,ref bool handled){
   if(message==0x02E0){var rect=(Rect)Marshal.PtrToStructure(lParam,typeof(Rect));window.Dispatcher.BeginInvoke(new Action(()=>{Place(rect,Work(MonitorFromWindow(handle,2)));Program.Log("monitor-dpi-changed dpi="+GetDpiForWindow(handle));}));}
   if(message==0x007E)window.Dispatcher.BeginInvoke(new Action(()=>{Rect rect;GetWindowRect(handle,out rect);Place(rect,Work(MonitorFromWindow(handle,2)));}));
   if(message==0x0024){var area=Work(MonitorFromWindow(handle,2));var limits=(MinMax)Marshal.PtrToStructure(lParam,typeof(MinMax));double scale=GetDpiForWindow(handle)/96.0;limits.minTrack=new Point((int)Math.Min(300*scale,area.right-area.left),(int)Math.Min(260*scale,area.bottom-area.top));limits.maxTrack=new Point(area.right-area.left,area.bottom-area.top);Marshal.StructureToPtr(limits,lParam,false);handled=true;}
   return IntPtr.Zero;
  }
 }
}
