# WinTool

> Una caja de herramientas ligera de Windows con una interfaz visual. Optimice, repare y administre su sistema: sin instalación, solo ejecútelo.

<!--![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue?logo=powershell) ![Windows](https://img.shields.io/badge/Windows-10%2F11-0078D4?logo=windows) ![License](https://img.shields.io/badge/license-MIT-green)-->

---

## Uso

Abre PowerShell como **Administrador** y ejecuta:

```powershell
irm https://raw.githubusercontent.com/migzam10/WinTool/refs/heads/main/WinTool.ps1 | iex
```

No requiere instalación. Todo corre en memoria directamente desde el repositorio.

---

## Herramientas incluidas

| Botón | Descripción |
|---|---|
| 💽 **Optimizar unidad** | Detecta HDD o SSD automáticamente. Ejecuta defragmentación o TRIM según corresponda. |
| 🔍 **SFC Scannow** | Analiza y repara archivos del sistema corruptos con `sfc /scannow`. |
| 🛠️ **DISM RestoreHealth** | Ejecuta el flujo completo: `CheckHealth → ScanHealth → RestoreHealth`. |
| 📡 **Obtener WI-FI** | Exporta y gestiona los perfiles WiFi guardados en el equipo. |
| 🚀 **Chris Titus WinUtil** | Lanza el utilitario de optimización de Windows de [ChrisTitusTech](https://github.com/ChrisTitusTech/winutil). |
| ✅ **Massgrave** | Lanza el herramienta de activacion para Windows [massgrave](https://massgrave.dev/). |

---

## Estructura del repositorio

```
WinTool/
├── WinTool.ps1   # Punto de entrada
├── MainWindow.xaml         # Interfaz WPF
└── scripts/
    └── maintenance.ps1     # Optimize Drive, SFC, DISM
```
 
---

## Probar en local

Clona el repo y ejecuta desde PowerShell como Administrador:

```powershell
git clone https://github.com/migzam10/WinTool
cd WinTool
powershell -ExecutionPolicy Bypass -File .\WinTool.ps1
```

---

## Requisitos

- Windows 10 / 11
- PowerShell 5.1 o superior
- Ejecutar como **Administrador**

---

## Scripts relacionados

- [Get-WlanProfiles](https://github.com/migzam10/Get-WlanProfiles) — exporta perfiles WiFi del sistema.
- [ChrisTitusTech/winutil](https://github.com/ChrisTitusTech/winutil) — utilitario de optimización integrado como botón.
- [massgrave](https://massgrave.dev/) - Metodos de activacion de Windows

---

## 📄 Licencia

MIT — libre de usar, modificar y distribuir.
