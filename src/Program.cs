using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Net;
using System.Net.NetworkInformation;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Markup;
using Microsoft.Win32;

namespace WinTool
{
    internal static class Program
    {
        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
        private class MEMORYSTATUSEX
        {
            public uint dwLength = (uint)Marshal.SizeOf(typeof(MEMORYSTATUSEX));
            public uint dwMemoryLoad;
            public ulong ullTotalPhys;
            public ulong ullAvailPhys;
            public ulong ullTotalPageFile;
            public ulong ullAvailPageFile;
            public ulong ullTotalVirtual;
            public ulong ullAvailVirtual;
            public ulong ullAvailExtendedVirtual;
        }

        [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool GlobalMemoryStatusEx([In, Out] MEMORYSTATUSEX lpBuffer);

        private static TextBox consoleBox;
        private static Window mainWindow;

        [STAThread]
        private static void Main()
        {
            // Habilitar TLS 1.2 (3072) para conexiones HTTPS en Windows 8 / 8.1 / 10 / 11
            ServicePointManager.SecurityProtocol |= (SecurityProtocolType)3072;

            try
            {
                using (Stream stream = Assembly.GetExecutingAssembly().GetManifestResourceStream("MainWindow.xaml"))
                {
                    if (stream == null)
                    {
                        MessageBox.Show("No se encontró el recurso incrustado MainWindow.xaml.", "WinTool - Error", MessageBoxButton.OK, MessageBoxImage.Error);
                        return;
                    }
                    mainWindow = (Window)XamlReader.Load(stream);
                }
            }
            catch (Exception ex)
            {
                MessageBox.Show("No se pudo cargar la interfaz.\n\nDetalle: " + ex.Message, "WinTool - Error", MessageBoxButton.OK, MessageBoxImage.Error);
                return;
            }

            consoleBox = mainWindow.FindName("txtConsoleOutput") as TextBox;

            // 1. Cargar Dashboard de Información del Sistema
            LoadSysInfo(mainWindow);

            var btnRefreshSysInfo = mainWindow.FindName("btnRefreshSysInfo") as Button;
            if (btnRefreshSysInfo != null)
            {
                btnRefreshSysInfo.Click += (s, e) =>
                {
                    LoadSysInfo(mainWindow);
                    Log("Información del sistema actualizada.");
                };
            }

            // 2. Tab Mantenimiento
            BindButton(mainWindow, "btnOptimizeDrive", () =>
            {
                Log("[Mantenimiento] Iniciando Optimización de Unidad C:...");
                InvokeToolFunction("maintenance.ps1", "Invoke-OptimizeDrive");
            });

            BindButton(mainWindow, "btnSFC", () =>
            {
                Log("[Mantenimiento] Iniciando SFC Scannow...");
                InvokeToolFunction("maintenance.ps1", "Invoke-SFC");
            });

            BindButton(mainWindow, "btnDISM", () =>
            {
                Log("[Mantenimiento] Iniciando DISM RestoreHealth...");
                InvokeToolFunction("maintenance.ps1", "Invoke-DISM");
            });

            BindButton(mainWindow, "btnRepairWU", () =>
            {
                Log("[Mantenimiento] Iniciando reparación de Windows Update...");
                InvokeToolFunction("maintenance.ps1", "Invoke-RepairWindowsUpdate");
            });

            BindButton(mainWindow, "btnCreateRestorePoint", () =>
            {
                Log("[Mantenimiento] Creando Punto de Restauración del Sistema...");
                InvokeToolFunction("maintenance.ps1", "Invoke-CreateRestorePoint");
            });

            // 3. Tab Limpieza de Sistema
            SetupCleanerTab(mainWindow);

            // 4. Tab Red y Wi-Fi
            BindButton(mainWindow, "btnWlanProfiles", () =>
            {
                Log("[Wi-Fi] Extrayendo perfiles y contraseñas guardadas en modo offline...");
                InvokeToolFunction("network.ps1", "Invoke-GetWlanProfiles");
            });

            BindButton(mainWindow, "btnNetworkRepair", () =>
            {
                Log("[Red] Iniciando restablecimiento de red y Flush DNS...");
                InvokeToolFunction("network.ps1", "Invoke-RepairNetwork");
            });

            BindButton(mainWindow, "btnPingCheck", () =>
            {
                RunPingCheck();
            });

            // 5. Tab Utilidades Externas
            BindButton(mainWindow, "btnWinUtil", () =>
            {
                Log("[WinUtil] Verificando conexión a Internet...");
                if (!CheckInternet())
                {
                    Log("[ERROR] Se requiere conexión a Internet para ejecutar Chris Titus WinUtil.");
                    MessageBox.Show("No se detectó conexión a Internet. Chris Titus WinUtil requiere conexión activa para descargar sus componentes.", "WinTool - Sin Internet", MessageBoxButton.OK, MessageBoxImage.Warning);
                    return;
                }
                Log("[WinUtil] Lanzando utilitario de Chris Titus Tech...");
                RunPowerShellCommand(
                    "[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072; irm christitus.com/win | iex",
                    keepOpen: false
                );
            });

            BindButton(mainWindow, "btnActivarWin", () =>
            {
                Log("[Massgrave] Verificando conexión a Internet...");
                if (!CheckInternet())
                {
                    Log("[ERROR] Se requiere conexión a Internet para ejecutar el script de Massgrave.");
                    MessageBox.Show("No se detectó conexión a Internet. La herramienta de activación requiere conexión activa.", "WinTool - Sin Internet", MessageBoxButton.OK, MessageBoxImage.Warning);
                    return;
                }
                Log("[Massgrave] Lanzando utilitario oficial de Massgrave...");
                RunPowerShellCommand(
                    "[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072; irm https://get.activated.win | iex",
                    keepOpen: false
                );
            });

            // 6. Botones de Consola
            var btnClearConsole = mainWindow.FindName("btnClearConsole") as Button;
            if (btnClearConsole != null)
            {
                btnClearConsole.Click += (s, e) =>
                {
                    if (consoleBox != null)
                    {
                        consoleBox.Text = string.Format("[{0:HH:mm:ss}] Registro limpiado.\n", DateTime.Now);
                    }
                };
            }

            var btnCopyConsole = mainWindow.FindName("btnCopyConsole") as Button;
            if (btnCopyConsole != null)
            {
                btnCopyConsole.Click += (s, e) =>
                {
                    if (consoleBox != null && !string.IsNullOrEmpty(consoleBox.Text))
                    {
                        Clipboard.SetText(consoleBox.Text);
                        MessageBox.Show("Registro copiado al portapapeles.", "WinTool", MessageBoxButton.OK, MessageBoxImage.Information);
                    }
                };
            }

            mainWindow.ShowDialog();
        }

        private static void Log(string message)
        {
            if (consoleBox == null) return;

            mainWindow.Dispatcher.Invoke(new Action(() =>
            {
                string line = string.Format("[{0:HH:mm:ss}] {1}\n", DateTime.Now, message);
                consoleBox.AppendText(line);
                consoleBox.ScrollToEnd();
            }));
        }

        private static void LoadSysInfo(Window window)
        {
            var txtOS = window.FindName("txtSysOS") as TextBlock;
            var txtCPU = window.FindName("txtSysCPU") as TextBlock;
            var txtRAM = window.FindName("txtSysRAM") as TextBlock;
            var txtDisk = window.FindName("txtSysDisk") as TextBlock;

            // OS Info
            try
            {
                using (var key = Registry.LocalMachine.OpenSubKey(@"SOFTWARE\Microsoft\Windows NT\CurrentVersion"))
                {
                    if (key != null)
                    {
                        string prodName = key.GetValue("ProductName") as string ?? "Windows";
                        string dispVer = key.GetValue("DisplayVersion") as string ?? key.GetValue("ReleaseId") as string ?? "";
                        string build = key.GetValue("CurrentBuildNumber") as string ?? "";

                        int bNum;
                        if (int.TryParse(build, out bNum) && bNum >= 22000 && prodName.Contains("Windows 10"))
                        {
                            prodName = prodName.Replace("Windows 10", "Windows 11");
                        }

                        string arch = Environment.Is64BitOperatingSystem ? "64-bit" : "32-bit";
                        if (txtOS != null)
                        {
                            txtOS.Text = string.Format("{0} {1} ({2})", prodName, dispVer, arch).Trim();
                        }
                    }
                }
            }
            catch
            {
                if (txtOS != null) txtOS.Text = Environment.OSVersion.VersionString;
            }

            // CPU Info
            try
            {
                using (var key = Registry.LocalMachine.OpenSubKey(@"HARDWARE\DESCRIPTION\System\CentralProcessor\0"))
                {
                    if (key != null)
                    {
                        string cpu = key.GetValue("ProcessorNameString") as string ?? "CPU x86/x64";
                        while (cpu.Contains("  ")) cpu = cpu.Replace("  ", " ");
                        if (txtCPU != null) txtCPU.Text = cpu.Trim();
                    }
                }
            }
            catch
            {
                if (txtCPU != null) txtCPU.Text = "Procesador x86/x64";
            }

            // RAM Info
            try
            {
                var mem = new MEMORYSTATUSEX();
                if (GlobalMemoryStatusEx(mem))
                {
                    double totalGB = Math.Round((double)mem.ullTotalPhys / (1024 * 1024 * 1024), 1);
                    double freeGB = Math.Round((double)mem.ullAvailPhys / (1024 * 1024 * 1024), 1);
                    double usedGB = Math.Round(totalGB - freeGB, 1);
                    int pctFree = (int)Math.Round((freeGB / totalGB) * 100);

                    if (txtRAM != null)
                    {
                        txtRAM.Text = string.Format("{0} GB / {1} GB ({2}% libre)", usedGB, totalGB, pctFree);
                    }
                }
            }
            catch
            {
                if (txtRAM != null) txtRAM.Text = "RAM del Sistema";
            }

            // Disk C: Info
            try
            {
                var drive = new DriveInfo("C");
                if (drive.IsReady)
                {
                    double freeGB = Math.Round((double)drive.TotalFreeSpace / (1024 * 1024 * 1024), 1);
                    double totalGB = Math.Round((double)drive.TotalSize / (1024 * 1024 * 1024), 1);
                    int pctFree = (int)Math.Round(((double)drive.TotalFreeSpace / drive.TotalSize) * 100);

                    if (txtDisk != null)
                    {
                        txtDisk.Text = string.Format("{0} GB libres de {1} GB ({2}%)", freeGB, totalGB, pctFree);
                    }
                }
            }
            catch
            {
                if (txtDisk != null) txtDisk.Text = "Unidad C:";
            }
        }

        private static void SetupCleanerTab(Window window)
        {
            var chkUserTemp = window.FindName("chkUserTemp") as CheckBox;
            var chkWinTemp = window.FindName("chkWinTemp") as CheckBox;
            var chkUpdateCache = window.FindName("chkUpdateCache") as CheckBox;
            var chkRecycleBin = window.FindName("chkRecycleBin") as CheckBox;
            var chkThumbCache = window.FindName("chkThumbCache") as CheckBox;
            var chkDnsCache = window.FindName("chkDnsCache") as CheckBox;

            var lblUserTemp = window.FindName("lblSizeUserTemp") as TextBlock;
            var lblWinTemp = window.FindName("lblSizeWinTemp") as TextBlock;
            var lblUpdateCache = window.FindName("lblSizeUpdateCache") as TextBlock;
            var lblRecycleBin = window.FindName("lblSizeRecycleBin") as TextBlock;
            var lblThumbCache = window.FindName("lblSizeThumbCache") as TextBlock;
            var lblDnsCache = window.FindName("lblSizeDnsCache") as TextBlock;

            var lblStatus = window.FindName("lblCleanStatus") as TextBlock;
            var lblTotal = window.FindName("lblTotalCleanable") as TextBlock;

            var btnSelectAll = window.FindName("btnSelectAll") as Button;
            var btnDeselectAll = window.FindName("btnDeselectAll") as Button;
            var btnAnalyze = window.FindName("btnAnalyzeClean") as Button;
            var btnExecute = window.FindName("btnExecuteClean") as Button;

            Action<bool> setAllChecks = (state) =>
            {
                if (chkUserTemp != null) chkUserTemp.IsChecked = state;
                if (chkWinTemp != null) chkWinTemp.IsChecked = state;
                if (chkUpdateCache != null) chkUpdateCache.IsChecked = state;
                if (chkRecycleBin != null) chkRecycleBin.IsChecked = state;
                if (chkThumbCache != null) chkThumbCache.IsChecked = state;
                if (chkDnsCache != null) chkDnsCache.IsChecked = state;
            };

            if (btnSelectAll != null) btnSelectAll.Click += (s, e) => setAllChecks(true);
            if (btnDeselectAll != null) btnDeselectAll.Click += (s, e) => setAllChecks(false);

            // Acción: Analizar tamaños en segundo plano
            Action runAnalysis = () =>
            {
                if (lblStatus != null) lblStatus.Text = "Analizando carpetas y componentes...";
                if (btnAnalyze != null) btnAnalyze.IsEnabled = false;

                Log("[Limpieza] Analizando espacio recuperable en las carpetas seleccionadas...");

                Task.Factory.StartNew(() =>
                {
                    double userTempBytes = GetDirectorySize(Path.GetTempPath());
                    double winTempBytes = GetDirectorySize(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Windows), "Temp"));
                    double updateBytes = GetDirectorySize(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Windows), @"SoftwareDistribution\Download"));

                    double recycleBytes = 0;
                    try
                    {
                        foreach (var d in DriveInfo.GetDrives())
                        {
                            if (d.IsReady && d.DriveType == DriveType.Fixed)
                            {
                                recycleBytes += GetDirectorySize(Path.Combine(d.RootDirectory.FullName, "$Recycle.Bin"));
                            }
                        }
                    }
                    catch { }

                    string wer = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), @"Microsoft\Windows\WER");
                    double thumbBytes = GetDirectorySize(wer);

                    double total = userTempBytes + winTempBytes + updateBytes + recycleBytes + thumbBytes;

                    window.Dispatcher.Invoke(new Action(() =>
                    {
                        if (lblUserTemp != null) lblUserTemp.Text = FormatBytes(userTempBytes);
                        if (lblWinTemp != null) lblWinTemp.Text = FormatBytes(winTempBytes);
                        if (lblUpdateCache != null) lblUpdateCache.Text = FormatBytes(updateBytes);
                        if (lblRecycleBin != null) lblRecycleBin.Text = FormatBytes(recycleBytes);
                        if (lblThumbCache != null) lblThumbCache.Text = FormatBytes(thumbBytes);
                        if (lblDnsCache != null) lblDnsCache.Text = "Caché activa";

                        if (lblStatus != null) lblStatus.Text = "Análisis completado.";
                        if (lblTotal != null) lblTotal.Text = "Espacio total recuperable estimado: " + FormatBytes(total);
                        if (btnAnalyze != null) btnAnalyze.IsEnabled = true;

                        Log(string.Format("[Limpieza] Análisis finalizado. Espacio recuperable detectado: {0}.", FormatBytes(total)));
                    }));
                });
            };

            if (btnAnalyze != null)
            {
                btnAnalyze.Click += (s, e) => runAnalysis();
            }

            // Acción: Limpiar seleccionados
            if (btnExecute != null)
            {
                btnExecute.Click += (s, e) =>
                {
                    var targets = new List<string>();
                    if (chkUserTemp != null && chkUserTemp.IsChecked == true) targets.Add("'UserTemp'");
                    if (chkWinTemp != null && chkWinTemp.IsChecked == true) targets.Add("'WinTemp'");
                    if (chkUpdateCache != null && chkUpdateCache.IsChecked == true) targets.Add("'UpdateCache'");
                    if (chkRecycleBin != null && chkRecycleBin.IsChecked == true) targets.Add("'RecycleBin'");
                    if (chkThumbCache != null && chkThumbCache.IsChecked == true) targets.Add("'ThumbCache'");
                    if (chkDnsCache != null && chkDnsCache.IsChecked == true) targets.Add("'DnsCache'");

                    if (targets.Count == 0)
                    {
                        MessageBox.Show("Por favor marca al menos una casilla para realizar la limpieza.", "WinTool - Limpieza", MessageBoxButton.OK, MessageBoxImage.Information);
                        return;
                    }

                    string targetArg = string.Join(",", targets.ToArray());
                    Log(string.Format("[Limpieza] Ejecutando limpieza de {0} componentes seleccionados...", targets.Count));
                    InvokeToolFunction("cleaner.ps1", string.Format("Invoke-SystemCleaning -Targets @({0})", targetArg));
                };
            }
        }

        private static double GetDirectorySize(string path)
        {
            if (string.IsNullOrEmpty(path) || !Directory.Exists(path)) return 0;
            double size = 0;
            try
            {
                var files = Directory.GetFiles(path, "*.*", SearchOption.AllDirectories);
                foreach (var f in files)
                {
                    try
                    {
                        var fi = new FileInfo(f);
                        size += fi.Length;
                    }
                    catch { }
                }
            }
            catch { }
            return size;
        }

        private static string FormatBytes(double bytes)
        {
            if (bytes >= 1024 * 1024 * 1024)
                return string.Format("{0:0.00} GB", bytes / (1024 * 1024 * 1024));
            if (bytes >= 1024 * 1024)
                return string.Format("{0:0.00} MB", bytes / (1024 * 1024));
            if (bytes >= 1024)
                return string.Format("{0:0.0} KB", bytes / 1024);
            return string.Format("{0} B", (long)bytes);
        }

        private static void RunPingCheck()
        {
            Log("[Red] Realizando comprobación de conectividad y latencia...");
            Task.Factory.StartNew(() =>
            {
                try
                {
                    using (var pinger = new Ping())
                    {
                        var reply = pinger.Send("1.1.1.1", 2500);
                        if (reply.Status == IPStatus.Success)
                        {
                            Log(string.Format("[Red] Ping exitoso a 1.1.1.1 (Cloudflare DNS) - Latencia: {0} ms.", reply.RoundtripTime));
                        }
                        else
                        {
                            var replyGoogle = pinger.Send("8.8.8.8", 2500);
                            if (replyGoogle.Status == IPStatus.Success)
                            {
                                Log(string.Format("[Red] Ping exitoso a 8.8.8.8 (Google DNS) - Latencia: {0} ms.", replyGoogle.RoundtripTime));
                            }
                            else
                            {
                                Log("[Red] No hubo respuesta en las pruebas de ping. Revisa tu adaptador de red.");
                            }
                        }
                    }
                }
                catch (Exception ex)
                {
                    Log(string.Format("[Red] Error al probar conectividad: {0}", ex.Message));
                }
            });
        }

        private static bool CheckInternet()
        {
            try
            {
                using (var ping = new Ping())
                {
                    var reply = ping.Send("1.1.1.1", 1800);
                    if (reply != null && reply.Status == IPStatus.Success) return true;
                }
            }
            catch { }

            try
            {
                var req = (HttpWebRequest)WebRequest.Create("http://www.msftconnecttest.com/connecttest.txt");
                req.Timeout = 2500;
                using (var resp = req.GetResponse())
                {
                    return true;
                }
            }
            catch { }

            return false;
        }

        private static void BindButton(Window window, string buttonName, Action onClick)
        {
            var button = window.FindName(buttonName) as Button;
            if (button != null)
            {
                button.Click += (sender, args) =>
                {
                    try
                    {
                        onClick();
                    }
                    catch (Exception ex)
                    {
                        MessageBox.Show("Error al ejecutar la acción:\n\n" + ex.Message, "WinTool - Error", MessageBoxButton.OK, MessageBoxImage.Error);
                    }
                };
            }
        }

        private static void InvokeToolFunction(string resourceName, string functionCall)
        {
            string tempScript = Path.Combine(Path.GetTempPath(), "mwt_" + resourceName);

            using (Stream stream = Assembly.GetExecutingAssembly().GetManifestResourceStream(resourceName))
            {
                if (stream == null)
                {
                    throw new InvalidOperationException("No se encontró el recurso incrustado: " + resourceName);
                }

                using (var reader = new StreamReader(stream, Encoding.UTF8))
                {
                    string content = reader.ReadToEnd();
                    File.WriteAllText(tempScript, content, new UTF8Encoding(encoderShouldEmitUTF8Identifier: true));
                }
            }

            string cmd = string.Format("[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072; . '{0}'; {1}", tempScript.Replace("'", "''"), functionCall);
            RunPowerShellCommand(cmd, keepOpen: true);
        }

        private static void RunPowerShellCommand(string command, bool keepOpen)
        {
            string noExitFlag = keepOpen ? "-NoExit " : string.Empty;
            string escapedCommand = command.Replace("\"", "\\\"");

            var psi = new ProcessStartInfo
            {
                FileName = "powershell.exe",
                Arguments = string.Format("{0}-NoProfile -ExecutionPolicy Bypass -Command \"{1}\"", noExitFlag, escapedCommand),
                Verb = "runas",
                UseShellExecute = true
            };

            Process.Start(psi);
        }
    }
}
