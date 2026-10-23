// Tray helper for Lan Mouse on Windows.
//
// Lan Mouse has no tray mode, but it is split into a GTK window and a
// `lan-mouse daemon` that does the actual sharing. This helper keeps the
// daemon running in the background with a tray icon, and opens the window on
// demand, so closing the window no longer stops sharing.
//
// It also runs release.ahk (a second release shortcut), started a moment after
// the daemon so its keyboard hook comes before Lan Mouse's.
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
    const int SW_RESTORE = 9;

    readonly string dir = AppDomain.CurrentDomain.BaseDirectory;
    readonly string exe;
    readonly NotifyIcon tray;
    readonly Control invoker = new Control();
    readonly EventWaitHandle showEvent;
    readonly System.Windows.Forms.Timer releaseScriptTimer = new System.Windows.Forms.Timer { Interval = 2000 };
    Process daemon;
    Process releaseScript;
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

        releaseScriptTimer.Tick += delegate { releaseScriptTimer.Stop(); StartReleaseScript(); };

        StartDaemon();
        OpenWindow();
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

        // A new daemon installs a new hook, so the script has to follow it again.
        releaseScriptTimer.Stop();
        releaseScriptTimer.Start();
    }

    void StartReleaseScript()
    {
        StopReleaseScript();
        string script = Path.Combine(dir, "release.ahk");
        string ahk = null;
        foreach (string root in new[] {
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData) + @"\Programs",
            Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles) })
        {
            string p = Path.Combine(root, @"AutoHotkey\v2\AutoHotkey64.exe");
            if (File.Exists(p)) { ahk = p; break; }
        }
        if (ahk == null || !File.Exists(script)) return;

        releaseScript = Process.Start(new ProcessStartInfo(ahk, "\"" + script + "\"")
        {
            WorkingDirectory = dir,
            UseShellExecute = false,
        });
    }

    void StopReleaseScript()
    {
        if (releaseScript == null) return;
        try { if (!releaseScript.HasExited) releaseScript.Kill(); }
        catch (InvalidOperationException) { }
        releaseScript = null;
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
        releaseScriptTimer.Stop();
        StopReleaseScript();
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
