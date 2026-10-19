using System;using System.Text;using System.Runtime.InteropServices;
namespace RiseOnAir {
 public static class ResumeWindow {
  delegate bool Visit(IntPtr h,IntPtr p);
  [StructLayout(LayoutKind.Sequential)]struct Rect{public int l,t,r,b;}
  [DllImport("user32.dll")]static extern bool EnumWindows(Visit v,IntPtr p);
  [DllImport("user32.dll")]static extern uint GetWindowThreadProcessId(IntPtr h,out uint p);
  [DllImport("user32.dll",CharSet=CharSet.Unicode)]static extern int GetClassName(IntPtr h,StringBuilder c,int n);
  [DllImport("user32.dll")]static extern bool GetWindowRect(IntPtr h,out Rect r);
  [DllImport("user32.dll")]static extern IntPtr SetThreadDpiAwarenessContext(IntPtr value);
  [DllImport("user32.dll")]static extern bool ShowWindowAsync(IntPtr h,int c);
  [DllImport("user32.dll")]public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")]static extern bool IsIconic(IntPtr h);
  [DllImport("user32.dll")]static extern bool SetForegroundWindow(IntPtr h);
  public static long Restore(int process,double x,double y,double width,double height,double dpr) {
   IntPtr best=IntPtr.Zero;double score=double.MaxValue,second=double.MaxValue;
   var old=SetThreadDpiAwarenessContext(new IntPtr(-4));
   try {EnumWindows(delegate(IntPtr h,IntPtr unused){
    uint pid;GetWindowThreadProcessId(h,out pid);if(pid!=(uint)process)return true;
    var name=new StringBuilder(256);GetClassName(h,name,256);if(name.ToString()!="Chrome_WidgetWin_1")return true;
    Rect r;GetWindowRect(h,out r);
    foreach(double scale in new double[]{1,dpr}){
     var dimensions=Math.Abs((r.r-r.l)-width*scale)+Math.Abs((r.b-r.t)-height*scale);
     var position=Math.Abs(r.l-x*scale)+Math.Abs(r.t-y*scale);
     var value=dimensions*4+position;
     if(dimensions>32||position>64)continue;
     if(h==best){score=Math.Min(score,value);continue;}
     if(value<score){second=score;score=value;best=h;}else second=Math.Min(second,value);
    }
    return true;
   },IntPtr.Zero);}finally{SetThreadDpiAwarenessContext(old);}
   if(best==IntPtr.Zero||second-score<4)throw new InvalidOperationException("No unique native main window matches the verified renderer.");
   ShowWindowAsync(best,IsIconic(best)?9:5);SetForegroundWindow(best);return best.ToInt64();
  }
 }
}
