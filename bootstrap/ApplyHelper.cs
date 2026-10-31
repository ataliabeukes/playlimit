using System;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Threading;

// Waits for the launcher to exit, moves the real app over the live exe, then
// starts it with PyInstaller's private _PYI_* variables removed.
class ApplyHelper
{
    static readonly string DataDir = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData),
        "AlbionLimiter");
    static readonly string LogFile = Path.Combine(DataDir, "bootstrap.log");

    static void Log(string msg)
    {
        try
        {
            Directory.CreateDirectory(DataDir);
            File.AppendAllText(LogFile,
                "[" + DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss") + "] " + msg + Environment.NewLine);
        }
        catch { }
    }

    static void StartApp(string live)
    {
        ProcessStartInfo psi = new ProcessStartInfo(live);
        psi.UseShellExecute = false;
        psi.WorkingDirectory = Path.GetDirectoryName(live);
        psi.CreateNoWindow = true;
        foreach (string key in psi.EnvironmentVariables.Keys.Cast<string>()
                     .Where(k => k.StartsWith("_PYI_", StringComparison.OrdinalIgnoreCase)).ToList())
            psi.EnvironmentVariables.Remove(key);
        psi.EnvironmentVariables["PYINSTALLER_RESET_ENVIRONMENT"] = "1";
        Process.Start(psi);
    }

    static void Main(string[] args)
    {
        if (args.Length < 4)
        {
            Log("helper: missing arguments");
            return;
        }

        int pid = 0;
        int.TryParse(args[0], out pid);
        string live = args[1];
        string real = args[2];
        string self = args[3];

        try
        {
            Log("helper start (launcher pid " + pid + ")");
            if (pid > 0)
            {
                try { Process.GetProcessById(pid).WaitForExit(); }
                catch (ArgumentException) { }
            }
            Thread.Sleep(500);

            bool ok = false;
            for (int i = 0; i < 60; i++)
            {
                try
                {
                    if (File.Exists(live))
                    {
                        string backup = live + ".old";
                        try { if (File.Exists(backup)) File.Delete(backup); }
                        catch { }
                        File.Replace(real, live, backup, true);
                        try { File.Delete(backup); }
                        catch { }
                    }
                    else
                    {
                        File.Move(real, live);
                    }
                    ok = true;
                    break;
                }
                catch (Exception ex)
                {
                    if (i == 0) Log("replace retry: " + ex.Message);
                    if (i >= 10)
                    {
                        // Fallback for filesystems where File.Replace is unsupported.
                        try
                        {
                            File.Copy(real, live, true);
                            File.Delete(real);
                            ok = true;
                            break;
                        }
                        catch { }
                    }
                    Thread.Sleep(250);
                }
            }

            if (!ok)
            {
                Log("REPLACE FAILED after retries; starting the existing exe");
                try { StartApp(live); }
                catch (Exception ex) { Log("existing exe start failed: " + ex.Message); }
                return;
            }

            Log("replace OK; starting real app");
            StartApp(live);
            Log("real app started");
        }
        catch (Exception ex)
        {
            Log("HELPER FAILED: " + ex);
            try { StartApp(live); }
            catch { }
        }
        finally
        {
            try
            {
                ProcessStartInfo psi = new ProcessStartInfo("cmd.exe",
                    "/c ping 127.0.0.1 -n 3 >nul & del /f /q \"" + self + "\"");
                psi.UseShellExecute = false;
                psi.CreateNoWindow = true;
                psi.WindowStyle = ProcessWindowStyle.Hidden;
                Process.Start(psi);
            }
            catch { }
        }
    }
}
