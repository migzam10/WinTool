using System;
using System.Diagnostics;
using System.IO;
using System.Net;
using System.Reflection;
using System.Text;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Markup;

namespace WinTool
{
    internal static class Program
    {
        [STAThread]
        private static void Main()
        {
            // Habilitar TLS 1.2 (3072) para conexiones HTTPS en Windows 8 / 8.1 / 10 / 11
            ServicePointManager.SecurityProtocol |= (SecurityProtocolType)3072;

            Window window;
            try
            {
                using (Stream stream = Assembly.GetExecutingAssembly().GetManifestResourceStream("MainWindow.xaml"))
                {
                    if (stream == null)
                    {
                        MessageBox.Show(
                            "No se encontró el recurso incrustado MainWindow.xaml.",
                            "WinTool - Error",
                            MessageBoxButton.OK,
                            MessageBoxImage.Error
                        );
                        return;
                    }

                    window = (Window)XamlReader.Load(stream);
                }
            }
            catch (Exception ex)
            {
                MessageBox.Show(
                    "No se pudo cargar la interfaz.\n\nDetalle: " + ex.Message,
                    "WinTool - Error",
                    MessageBoxButton.OK,
                    MessageBoxImage.Error
                );
                return;
            }

            BindButton(window, "btnOptimizeDrive", () => InvokeToolFunction("Invoke-OptimizeDrive"));
            BindButton(window, "btnSFC", () => InvokeToolFunction("Invoke-SFC"));
            BindButton(window, "btnDISM", () => InvokeToolFunction("Invoke-DISM"));

            BindButton(window, "btnWlanProfiles", () =>
            {
                InvokeExternalScript("https://raw.githubusercontent.com/migzam10/Get-WlanProfiles/main/On-Get-WlanProfiles.ps1");
                InvokeExternalScript("https://raw.githubusercontent.com/migzam10/Get-WlanProfiles/main/Extras/extra1.ps1");
            });

            BindButton(window, "btnWinUtil", () =>
            {
                RunPowerShellCommand(
                    "[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072; irm christitus.com/win | iex",
                    keepOpen: false
                );
            });

            BindButton(window, "btnActivarWin", () =>
            {
                RunPowerShellCommand(
                    "[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072; irm https://get.activated.win | iex",
                    keepOpen: false
                );
            });

            window.ShowDialog();
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
                        MessageBox.Show(
                            "Error al ejecutar la acción:\n\n" + ex.Message,
                            "WinTool - Error",
                            MessageBoxButton.OK,
                            MessageBoxImage.Error
                        );
                    }
                };
            }
        }

        private static void InvokeToolFunction(string functionCall)
        {
            string tempScript = Path.Combine(Path.GetTempPath(), "mwt_maintenance.ps1");

            using (Stream stream = Assembly.GetExecutingAssembly().GetManifestResourceStream("maintenance.ps1"))
            {
                if (stream == null)
                {
                    throw new InvalidOperationException("No se encontró el recurso maintenance.ps1.");
                }

                using (var reader = new StreamReader(stream, Encoding.UTF8))
                {
                    string content = reader.ReadToEnd();
                    // Guardar con UTF-8 BOM para que Windows PowerShell 3.0-5.1 respete tildes y caracteres especiales
                    File.WriteAllText(tempScript, content, new UTF8Encoding(encoderShouldEmitUTF8Identifier: true));
                }
            }

            string cmd = string.Format(". '{0}'; {1}", tempScript.Replace("'", "''"), functionCall);
            RunPowerShellCommand(cmd, keepOpen: true);
        }

        private static void InvokeExternalScript(string url)
        {
            string tempScript = Path.Combine(Path.GetTempPath(), "mwt_ext_" + Guid.NewGuid().ToString("N").Substring(0, 8) + ".ps1");

            using (var client = new WebClient())
            {
                client.Encoding = Encoding.UTF8;
                string content = client.DownloadString(url);
                File.WriteAllText(tempScript, content, new UTF8Encoding(encoderShouldEmitUTF8Identifier: true));
            }

            var psi = new ProcessStartInfo
            {
                FileName = "powershell.exe",
                Arguments = string.Format("-NoProfile -ExecutionPolicy Bypass -File \"{0}\"", tempScript),
                Verb = "runas",
                UseShellExecute = true
            };

            Process.Start(psi);
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
