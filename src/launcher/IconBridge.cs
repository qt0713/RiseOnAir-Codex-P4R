using System;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading;

namespace RiseOnAir {
 static class IconBridge {
  const string LockName="Local\\RiseOnAir.IconBridge",StopName="Local\\RiseOnAir.IconBridge.Stop";
  [DllImport("user32.dll",CharSet=CharSet.Unicode)] static extern IntPtr LoadImage(IntPtr instance,string path,uint type,int width,int height,uint flags);
  [DllImport("user32.dll")] static extern bool DestroyIcon(IntPtr icon);
  [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr window,out uint pid);
  [DllImport("user32.dll")] static extern bool IsWindow(IntPtr window);
  [DllImport("user32.dll",SetLastError=true)] static extern IntPtr SendMessageTimeout(IntPtr window,uint message,IntPtr kind,IntPtr value,uint flags,uint timeout,out IntPtr result);
  static IntPtr Message(IntPtr window,uint message,int kind,IntPtr icon) {
   IntPtr result;if(SendMessageTimeout(window,message,new IntPtr(kind),icon,2,1000,out result)==IntPtr.Zero)throw new InvalidOperationException("Icon window did not respond.");return result;
  }
  static bool OwnsWindow(IntPtr window,int pid){uint owner;return IsWindow(window)&&GetWindowThreadProcessId(window,out owner)!=0&&owner==(uint)pid;}
  static void Log(string value){try{File.AppendAllText(Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"icon-bridge.log"),DateTime.UtcNow.ToString("o")+" "+value+Environment.NewLine);}catch{}}
  [STAThread] static int Main(string[] args) {
   if(args.Length==1&&args[0]=="--stop") {
    try {using(var stop=EventWaitHandle.OpenExisting(StopName))stop.Set();}catch(WaitHandleCannotBeOpenedException){}
    using(var gate=new Mutex(false,LockName)) {bool held=false;try{try{held=gate.WaitOne(5000);}catch(AbandonedMutexException){held=true;}return held?0:1;}finally{if(held)gate.ReleaseMutex();}}
   }
   if(args.Length!=3)return 2;
   int pid;long ticks;if(!int.TryParse(args[0],out pid)||!long.TryParse(args[1],out ticks))return 2;
   bool owns;using(var gate=new Mutex(true,LockName,out owns)) {
    if(!owns)return 0;
    IntPtr window=IntPtr.Zero,small=IntPtr.Zero,big=IntPtr.Zero,oldSmall=IntPtr.Zero,oldBig=IntPtr.Zero;
    try {
     using(var app=Process.GetProcessById(pid)) {
      if(app.StartTime.ToUniversalTime().Ticks!=ticks||!string.Equals(app.MainModule.FileName,args[2],StringComparison.OrdinalIgnoreCase)||app.ProcessName!="ChatGPT")return 3;
      window=app.MainWindowHandle;if(!OwnsWindow(window,pid))return 3;
      var icon=Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"rise-icon-v1.ico");
      small=LoadImage(IntPtr.Zero,icon,1,32,32,0x10);big=LoadImage(IntPtr.Zero,icon,1,64,64,0x10);
      if(small==IntPtr.Zero||big==IntPtr.Zero)throw new InvalidOperationException("Rise icon could not be loaded.");
      oldSmall=Message(window,0x7f,0,IntPtr.Zero);oldBig=Message(window,0x7f,1,IntPtr.Zero);
      using(var stop=new EventWaitHandle(false,EventResetMode.ManualReset,StopName)) {
       stop.Reset();Log("attached pid="+pid);
       while(!app.HasExited&&OwnsWindow(window,pid)) {
        if(Message(window,0x7f,0,IntPtr.Zero)!=small)Message(window,0x80,0,small);
        if(Message(window,0x7f,1,IntPtr.Zero)!=big)Message(window,0x80,1,big);
        if(stop.WaitOne(1000))break;
       }
      }
     }
     return 0;
    }catch(Exception error){Log("error "+error.Message);return 1;}
    finally {
     if(OwnsWindow(window,pid)) {
      try {if(small!=IntPtr.Zero&&Message(window,0x7f,0,IntPtr.Zero)==small)Message(window,0x80,0,oldSmall);}catch{}
      try {if(big!=IntPtr.Zero&&Message(window,0x7f,1,IntPtr.Zero)==big)Message(window,0x80,1,oldBig);}catch{}
     }
     if(small!=IntPtr.Zero)DestroyIcon(small);if(big!=IntPtr.Zero)DestroyIcon(big);
     Log("detached pid="+pid);gate.ReleaseMutex();
    }
   }
  }
 }
}
