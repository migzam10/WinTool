# WinTool PRO

> Caja de herramientas avanzada de optimización, limpieza, mantenimiento y reparación para Windows con interfaz gráfica moderna. Sin instalador: ejecutable portátil `.exe` o directo en memoria con PowerShell.

---

## ⚡ Modos de Uso

### Opción 1: Ejecutable Portátil (.exe) - *Recomendado*
Descarga la última versión de **`WinTool.exe`** desde la sección [Releases](https://github.com/migzam10/WinTool/releases) y ejecútala. Solicita permisos de Administrador automáticamente y es compatible con **Windows 8, 8.1, 10 y 11**.

### Opción 2: Sin Descargar (Directo en Memoria)
Abre PowerShell como **Administrador** y pega:

```powershell
irm https://raw.githubusercontent.com/migzam10/WinTool/main/WinTool.ps1 | iex
```

---

## 🧰 Herramientas y Módulos Incluidos

### 📊 Mini-Dashboard de Hardware (En Tiempo Real)
* **Sistema Operativo:** Detecta edición, arquitectura de 32/64 bits y número de compilación (Build).
* **Procesador (CPU):** Modelo y frecuencia detectados al instante.
* **Memoria RAM:** Consumo en vivo, total visible y porcentaje disponible.
* **Almacenamiento:** Espacio libre vs total en la unidad `C:`.

---

### 🛠️ Pestaña 1: Mantenimiento y Reparación
| Herramienta | Descripción |
|---|---|
| 💽 **Optimizar Unidad C:** | Detecta automáticamente si la unidad es SSD (ejecuta TRIM) o HDD (defragmentación). |
| 🔍 **SFC Scannow** | Analiza y repara archivos dañados del sistema mediante `sfc /scannow`. |
| 🛠️ **DISM RestoreHealth** | Ejecuta el flujo de reparación del almacén de componentes de Windows (`CheckHealth → ScanHealth → RestoreHealth`). |
| 🔄 **Reparar Windows Update** | Detiene servicios (`wuauserv`, `bits`, `cryptsvc`), purga la caché de descargas corruptas y reinicia el catálogo. |
| 🛡️ **Punto de Restauración** | Crea un respaldo del sistema con un solo clic antes de realizar cambios profundos. |

---

### 🧹 Pestaña 2: Limpieza de Sistema (Con Selección Personalizada)
Permite **analizar el espacio ocupado** y **seleccionar exactamente qué limpiar**:
* [x] **Temporales de Usuario (`%TEMP%`):** Archivos temporales generados por programas y navegadores.
* [x] **Temporales de Windows (`C:\Windows\Temp`):** Archivos temporales del sistema operativo y servicios.
* [x] **Caché de Windows Update:** Instaladores antiguos en `SoftwareDistribution\Download`.
* [x] **Papelera de Reciclaje:** Vaciado seguro de todas las unidades de disco.
* [x] **Miniaturas y Reportes WER:** Archivos de caché de iconos y reportes de errores de Windows.
* [ ] **Caché DNS:** Limpieza de registros y tablas de resolución DNS.

---

### 🌐 Pestaña 3: Red y Wi-Fi
| Herramienta | Descripción |
|---|---|
| 📡 **Claves Wi-Fi (100% Offline)** | Extrae las contraseñas de todas las redes guardadas en el equipo sin necesidad de internet y exporta un reporte a tu Escritorio (`WiFi-Passwords.txt`). |
| 🌐 **Reparar Red y DNS** | Ejecuta Flush DNS, renovación de IP (`release/renew`), restablecimiento de Winsock y de la pila TCP/IP. |
| 📶 **Probar Conectividad** | Test rápido de latencia y salida a internet mediante ping a servidores DNS públicos. |

---

### 🚀 Pestaña 4: Utilidades Externas
| Herramienta | Descripción |
|---|---|
| 🚀 **Chris Titus WinUtil** | Acceso directo al popular utilitario de optimización, tweaks y desinstalación de bloatware de [ChrisTitusTech](https://github.com/ChrisTitusTech/winutil) (con verificación previa de internet). |
| 🔑 **Activar Windows / Office** | Lanzador oficial del método de activación de [Massgrave](https://massgrave.dev/) (con verificación previa de internet). |

---

## 💻 Consola de Registro Integrada
La ventana principal incorpora un **Registro de Actividad en vivo** con botones para:
* **Copiar:** Copia todo el historial de acciones y salidas al portapapeles.
* **Limpiar:** Restablece la consola para un nuevo seguimiento.

---

## 📁 Estructura del Proyecto

```
WinTool/
├── WinTool.csproj                  # Proyecto C# (.NET Framework 4.5 para Windows 8 a 11)
├── WinTool.ps1                     # Script lanzador PowerShell
├── MainWindow.xaml                 # Interfaz visual WPF con estilo oscuro
├── src/
│   ├── Program.cs                  # Código principal C# (incrusta XAML y scripts)
│   ├── app.manifest                # Manifiesto UAC (solicita Administrador)
│   └── icon.ico                    # Icono de la aplicación multi-resolución
├── scripts/
│   ├── maintenance.ps1             # Defrag/TRIM, SFC, DISM, Windows Update, Restore Point
│   ├── cleaner.ps1                 # Escáner y motor de limpieza seleccionable
│   ├── network.ps1                 # Extractor Wi-Fi offline y reparación de red
│   └── sysinfo.ps1                 # Analizador de hardware para el dashboard
└── .github/workflows/
    └── build-exe.yml               # CI/CD: Compila WinTool.exe automáticamente en GitHub Actions
```

---

## 🛠️ Probar en Local

Clona el repositorio y ejecuta desde PowerShell como Administrador:

```powershell
git clone https://github.com/migzam10/WinTool.git
cd WinTool
powershell -ExecutionPolicy Bypass -File .\WinTool.ps1
```

O abre `WinTool.csproj` en Visual Studio / compila con:
```powershell
dotnet build -c Release
```

---

## 📄 Licencia

MIT — libre de usar, modificar y distribuir.
