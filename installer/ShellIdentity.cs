using System;
using System.Runtime.InteropServices;

namespace RiseOnAir {
 public static class ShellIdentity {
  [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr window,out uint pid);
  public static int WindowProcess(long window){uint pid;GetWindowThreadProcessId(new IntPtr(window),out pid);return (int)pid;}
  [StructLayout(LayoutKind.Sequential)] struct Key { public Guid Format; public uint Id; public Key(uint id){Format=new Guid("9F4C2855-9F79-4B39-A8D0-E1D42DE1D5F3");Id=id;} }
  [StructLayout(LayoutKind.Explicit,Size=24)] struct Value { [FieldOffset(0)] public ushort Type; [FieldOffset(8)] public IntPtr Text; }
  [ComImport,Guid("886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99"),InterfaceType(ComInterfaceType.InterfaceIsIUnknown)] interface Store {
   void GetCount(out uint count); void GetAt(uint index,out Key key); void GetValue(ref Key key,out Value value); void SetValue(ref Key key,ref Value value); void Commit();
  }
  [DllImport("shell32.dll",CharSet=CharSet.Unicode,PreserveSig=false)] static extern void SHGetPropertyStoreFromParsingName(string path,IntPtr bind,uint flags,ref Guid iid,out Store store);
  [DllImport("shell32.dll",PreserveSig=false)] static extern void SHGetPropertyStoreForWindow(IntPtr window,ref Guid iid,out Store store);
  [DllImport("ole32.dll")] static extern int PropVariantClear(ref Value value);
  [DllImport("shell32.dll",CharSet=CharSet.Unicode)] static extern void SHChangeNotify(uint evt,uint flags,string path,IntPtr unused);
  static Store Open(string path,IntPtr window,bool write) {
   var iid=typeof(Store).GUID;Store store;
   if(!string.IsNullOrEmpty(path))SHGetPropertyStoreFromParsingName(path,IntPtr.Zero,write?2u:0u,ref iid,out store);
   else SHGetPropertyStoreForWindow(window,ref iid,out store);
   return store;
  }
  public static string Read(string path,long window,uint id) {
   var store=Open(path,new IntPtr(window),false);var key=new Key(id);Value value;
   try {store.GetValue(ref key,out value);try{return value.Type==31?Marshal.PtrToStringUni(value.Text):null;}finally{PropVariantClear(ref value);}}
   finally{Marshal.FinalReleaseComObject(store);}
  }
  public static void Write(string path,long window,uint id,string text) {
   var store=Open(path,new IntPtr(window),true);var key=new Key(id);var value=new Value();
   if(text!=null){value.Type=31;value.Text=Marshal.StringToCoTaskMemUni(text);}
   try {store.SetValue(ref key,ref value);store.Commit();}finally{PropVariantClear(ref value);Marshal.FinalReleaseComObject(store);}
   if(!string.IsNullOrEmpty(path))SHChangeNotify(0x00002000,0x0005,path,IntPtr.Zero);
  }
 }
}
