using System;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Reflection;

// Native bootstrap that wraps the real PyInstaller app.
// The updater downloads THIS exe and the old helper launches it, possibly with
// PyInstaller's private _PYI_* environment. Being native, this launcher ignores
// those variables, then applies + starts the real app with a clean environment.
class Launcher
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

    static string Extract(string resource, string tag)
    {
        string path = Path.Combine(Path.GetTempPath(),
            "PlayLimit_" + tag + "_" + Guid.NewGuid().ToString("N") + ".exe");
        using (Stream s = Assembly.GetExecutingAssembly().GetManifestResourceStream(resource))
        {
            if (s == null) throw new Exception("missing embedded resource: " + resource);
            using (FileStream f = File.Create(path)) { s.CopyTo(f); }
        }
        return path;
    }

    static void Main()
    {
        try
        {
            Log("launcher v" + Assembly.GetExecutingAssembly().GetName().Version + " start");
            string live = Process.GetCurrentProcess().MainModule.FileName;
            string real = Extract("Payload", "real");
            string helper = Extract("ApplyHelper", "apply");
            Log("payload extracted; starting apply helper");

            ProcessStartInfo psi = new ProcessStartInfo(helper);
            psi.UseShellExecute = false;
            psi.CreateNoWindow = true;
            psi.WindowStyle = ProcessWindowStyle.Hidden;
            psi.Arguments = "\"" + Process.GetCurrentProcess().Id + "\" \"" + live + "\" \"" + real + "\" \"" + helper + "\"";
            foreach (string key in psi.EnvironmentVariables.Keys.Cast<string>()
                         .Where(k => k.StartsWith("_PYI_", StringComparison.OrdinalIgnoreCase)).ToList())
                psi.EnvironmentVariables.Remove(key);
            psi.EnvironmentVariables["PYINSTALLER_RESET_ENVIRONMENT"] = "1";

            Process.Start(psi);
            Log("apply helper started; launcher exiting");
        }
        catch (Exception ex)
        {
            Log("LAUNCHER FAILED: " + ex);
        }
    }
}
