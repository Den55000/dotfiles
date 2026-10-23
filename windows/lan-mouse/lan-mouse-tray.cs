// Tray helper for Lan Mouse on Windows.
//
// Lan Mouse has no tray mode, but it is split into a GTK window and a
// `lan-mouse daemon` that does the actual sharing. This helper keeps the
// daemon running in the background with a tray icon, and opens the window on
// demand, so closing the window no longer stops sharing. While it runs,
// Ctrl+Alt+Up switches to the other laptop (Ctrl+Alt+Down, Lan Mouse's own
// release_bind, switches back).
//
// Built and installed next to lan-mouse.exe by install.ps1 in this folder, with
// the .NET Framework compiler that ships with Windows (C# 5, so no newer syntax).

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Management;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Forms;

static class Program
{
    const string MutexName = @"Local\LanMouseTray";
    public const string ShowEventName = @"Local\LanMouseTray.Show";

    [STAThread]
    static void Main()
    {
        bool created;
        using (var mutex = new Mutex(true, MutexName, out created))
        {
            if (!created)
            {
                // Already running: ask that instance to open the window, then leave.
                try { EventWaitHandle.OpenExisting(ShowEventName).Set(); }
                catch (WaitHandleCannotBeOpenedException) { }
                return;
            }
            Application.EnableVisualStyles();
            Application.Run(new TrayContext());
        }
    }
}

class TrayContext : ApplicationContext
{
    [DllImport("user32.dll")] static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")] static extern bool IsIconic(IntPtr hWnd);
    [DllImport("user32.dll")] static extern bool RegisterHotKey(IntPtr hWnd, int id, uint mods, uint vk);
    [DllImport("user32.dll")] static extern bool UnregisterHotKey(IntPtr hWnd, int id);
    [DllImport("user32.dll")] static extern short GetAsyncKeyState(int vk);
    [DllImport("user32.dll")] static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] static extern uint SendInput(uint n, INPUT[] inputs, int size);
    const int SW_RESTORE = 9;
    const uint MOD_ALT = 0x1, MOD_CONTROL = 0x2, MOD_NOREPEAT = 0x4000;
    const int VK_CONTROL = 0x11, VK_MENU = 0x12, VK_UP = 0x26;
    const uint INPUT_MOUSE = 0, MOUSEEVENTF_MOVE = 0x1;

    [StructLayout(LayoutKind.Sequential)]
    struct MOUSEINPUT { public int dx, dy; public uint data, flags, time; public IntPtr extra; }
    [StructLayout(LayoutKind.Sequential)]
    struct INPUT { public uint type; public MOUSEINPUT mi; }

    readonly string dir = AppDomain.CurrentDomain.BaseDirectory;
    readonly string exe;
    readonly NotifyIcon tray;
    readonly Control invoker = new Control();
    readonly EventWaitHandle showEvent;
    readonly HotkeyWindow hotkey = new HotkeyWindow();
    readonly System.Windows.Forms.Timer switchTimer = new System.Windows.Forms.Timer { Interval = 20 };
    Process daemon;
    DateTime daemonStarted;
    int quickCrashes;
    bool quitting;

    public TrayContext()
    {
        exe = Path.Combine(dir, "lan-mouse.exe");
        invoker.CreateControl();

        var menu = new ContextMenuStrip();
        var open = menu.Items.Add("Open Lan Mouse", null, delegate { OpenWindow(); });
        open.Font = new Font(open.Font, FontStyle.Bold);
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add("Quit", null, delegate { Quit(); });

        string ico = Path.Combine(dir, "lan-mouse.ico");
        tray = new NotifyIcon
        {
            Icon = File.Exists(ico) ? new Icon(ico, SystemInformation.SmallIconSize)
                                    : Icon.ExtractAssociatedIcon(Application.ExecutablePath),
            Text = "Lan Mouse",
            ContextMenuStrip = menu,
            Visible = true,
        };
        tray.MouseClick += delegate(object s, MouseEventArgs e)
        {
            if (e.Button == MouseButtons.Left) OpenWindow();
        };

        // Second launches (Start menu, Command Palette) signal this event.
        showEvent = new EventWaitHandle(false, EventResetMode.AutoReset, Program.ShowEventName);
        ThreadPool.RegisterWaitForSingleObject(showEvent,
            delegate { invoker.BeginInvoke((MethodInvoker)OpenWindow); }, null, -1, false);

        // Ctrl+Alt+Up switches to the other laptop. It only fires while the mouse
        // is here: once it is over there, Lan Mouse swallows the keys first.
        hotkey.Pressed += delegate { if (daemon != null) switchTimer.Start(); };
        switchTimer.Tick += delegate
        {
            // Wait for the keys to come up, or Lan Mouse would catch the releases
            // and this PC would think they are still held when control comes back.
            foreach (int vk in new[] { VK_CONTROL, VK_MENU, VK_UP })
                if ((GetAsyncKeyState(vk) & 0x8000) != 0) return;
            switchTimer.Stop();
            SwitchToOtherPc();
        };
        if (!RegisterHotKey(hotkey.Handle, 1, MOD_CONTROL | MOD_ALT | MOD_NOREPEAT, VK_UP))
            tray.ShowBalloonTip(5000, "Lan Mouse", "Ctrl+Alt+Up is taken by another program.", ToolTipIcon.Warning);

        StartDaemon();
        OpenWindow();
    }

    void SwitchToOtherPc()
    {
        // Lan Mouse switches when the cursor pushes through the edge the other
        // laptop sits at (the top), so put it on the top edge and nudge it up.
        Point p = Cursor.Position;
        int top = SystemInformation.VirtualScreen.Top;
        Rectangle screen = Rectangle.Empty;
        foreach (Screen s in Screen.AllScreens)
        {
            if (s.Bounds.Top != top) continue;
            if (screen.IsEmpty || (p.X >= s.Bounds.Left && p.X < s.Bounds.Right)) screen = s.Bounds;
        }
        SetCursorPos(Math.Max(screen.Left, Math.Min(p.X, screen.Right - 1)), top);

        var move = new[] { new INPUT { type = INPUT_MOUSE, mi = new MOUSEINPUT { dy = -30, flags = MOUSEEVENTF_MOVE } } };
        for (int i = 0; i < 5; i++)
        {
            SendInput(1, move, Marshal.SizeOf(typeof(INPUT)));
            Thread.Sleep(15);
        }
    }

    void StartDaemon()
    {
        // Adopt a daemon that is already running (e.g. left over from the window).
        var existing = FindLanMouse("daemon");
        if (existing.Count > 0)
        {
            try { daemon = Process.GetProcessById(existing[0]); }
            catch (ArgumentException) { daemon = null; }
        }
        if (daemon == null)
            daemon = Launch("daemon");

        daemonStarted = DateTime.Now;
        daemon.EnableRaisingEvents = true;
        daemon.Exited += delegate { invoker.BeginInvoke((MethodInvoker)OnDaemonExited); };
    }

    void OnDaemonExited()
    {
        daemon = null;
        if (quitting) return;

        // Restart it, unless it keeps dying right away.
        quickCrashes = (DateTime.Now - daemonStarted).TotalSeconds < 10 ? quickCrashes + 1 : 0;
        if (quickCrashes >= 3)
        {
            tray.Text = "Lan Mouse (stopped)";
            tray.ShowBalloonTip(5000, "Lan Mouse", "The daemon keeps exiting, so it was not restarted.", ToolTipIcon.Error);
            return;
        }
        StartDaemon();
    }

    void OpenWindow()
    {
        if (daemon == null && !quitting && quickCrashes >= 3)
        {
            quickCrashes = 0;
            tray.Text = "Lan Mouse";
            StartDaemon();
        }

        // Bring an open window to the front instead of starting a second one.
        foreach (int id in FindLanMouse(""))
        {
            try
            {
                IntPtr hwnd = Process.GetProcessById(id).MainWindowHandle;
                if (hwnd == IntPtr.Zero) continue;
                if (IsIconic(hwnd)) ShowWindow(hwnd, SW_RESTORE);
                SetForegroundWindow(hwnd);
                return;
            }
            catch (ArgumentException) { }
        }
        Launch("");
    }

    void Quit()
    {
        quitting = true;
        switchTimer.Stop();
        UnregisterHotKey(hotkey.Handle, 1);
        hotkey.DestroyHandle();
        foreach (int id in FindLanMouse(""))
        {
            try
            {
                var p = Process.GetProcessById(id);
                p.CloseMainWindow();
                if (!p.WaitForExit(2000)) p.Kill();
            }
            catch (ArgumentException) { }
            catch (InvalidOperationException) { }
        }
        if (daemon != null)
        {
            try { daemon.Kill(); daemon.WaitForExit(2000); }
            catch (InvalidOperationException) { }
        }
        tray.Visible = false;
        tray.Dispose();
        ExitThread();
    }

    Process Launch(string args)
    {
        // lan-mouse.exe is a console program; CreateNoWindow keeps the console hidden.
        return Process.Start(new ProcessStartInfo(exe, args)
        {
            WorkingDirectory = dir,
            UseShellExecute = false,
            CreateNoWindow = true,
        });
    }

    // Process ids of lan-mouse.exe started with exactly these arguments ("" = the window).
    static List<int> FindLanMouse(string args)
    {
        var ids = new List<int>();
        using (var s = new ManagementObjectSearcher(
            "SELECT ProcessId, CommandLine FROM Win32_Process WHERE Name = 'lan-mouse.exe'"))
        {
            foreach (ManagementObject o in s.Get())
            {
                string cl = (o["CommandLine"] as string ?? "").Trim();
                string rest;
                if (cl.StartsWith("\""))
                {
                    int end = cl.IndexOf('"', 1);
                    rest = end < 0 ? "" : cl.Substring(end + 1);
                }
                else
                {
                    int sp = cl.IndexOf(' ');
                    rest = sp < 0 ? "" : cl.Substring(sp + 1);
                }
                if (rest.Trim() == args) ids.Add(Convert.ToInt32(o["ProcessId"]));
            }
        }
        return ids;
    }
}

// Hidden window that receives WM_HOTKEY for RegisterHotKey.
class HotkeyWindow : NativeWindow
{
    const int WM_HOTKEY = 0x0312;
    public event MethodInvoker Pressed;

    public HotkeyWindow() { CreateHandle(new CreateParams()); }

    protected override void WndProc(ref Message m)
    {
        if (m.Msg == WM_HOTKEY && Pressed != null) Pressed();
        base.WndProc(ref m);
    }
}
