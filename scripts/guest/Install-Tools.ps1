<#
2	.SYNOPSIS
3	    Guest Script: Installs developer toolchains (Git, Node.js LTS, Python 3, PowerShell 7, OmniGet).
4	.DESCRIPTION
5	    Automates silent downloading and installation of core developer runtimes and tools
6	    needed for Windows development and AI Agent execution, delegating to OmniGet.
7	#>
8	[CmdletBinding()]
9	param(
10	    [switch]$SkipDotNet,
11	    [switch]$SkipNode,
12	    [switch]$SkipGit,
13	    [switch]$SkipGh,
14	    [switch]$SkipPython,
15	    [switch]$SkipPwsh,
16	    [switch]$SkipDocker
17	)
18
19	$ErrorActionPreference = 'Stop'
20	Set-StrictMode -Version Latest
21
22	function Write-Step { param([string]$Msg) Write-Host "[INFO] $Msg" -ForegroundColor Cyan }
23	function Write-Success { param([string]$Msg) Write-Host "[SUCCESS] $Msg" -ForegroundColor Green }
24	function Write-WarnMsg { param([string]$Msg) Write-Host "[WARN] $Msg" -ForegroundColor Yellow }
25
26	[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
27
28	$TempDir = "$env:TEMP\win_tools_installer"
29	if (-not (Test-Path $TempDir)) {
30	    New-Item -ItemType Directory -Path $TempDir -Force | Out-Null
31	}
32
33	function Refresh-EnvironmentPath {
34	    $machinePath = [System.Environment]::GetEnvironmentVariable('Path', [System.EnvironmentVariableTarget]::Machine)
35	    $userPath    = [System.Environment]::GetEnvironmentVariable('Path', [System.EnvironmentVariableTarget]::User)
36	    $extraPaths  = @(
37	        'C:\Program Files\OmniGet\bin',
38	        'C:\Program Files\dotnet',
39	        'C:\Program Files\Docker',
40	        'C:\Program Files\Git\bin',
41	        'C:\Program Files\Git\cmd',
42	        'C:\Program Files\GitHub CLI',
43	        'C:\Program Files\nodejs',
44	        "$env:APPDATA\npm",
45	        "$env:USERPROFILE\AppData\Roaming\npm",
46	        'C:\Program Files\PowerShell\7',
47	        'C:\Program Files\Python312',
48	        'C:\Program Files\Python312\Scripts'
49	    )
50	    $env:Path = ("$machinePath;$userPath;" + ($extraPaths -join ';')).Trim(';')
51	}
52
53	function Main {
54	    Write-Host "=============================================================================="
55	    Write-Host "  Windows Core Guest - Developer Toolchain Installer"
56	    Write-Host "=============================================================================="
57
58	    # 1. Deploy OmniGet Package Engine
59	    $installOmniGet = Join-Path $PSScriptRoot "Install-OmniGet.ps1"
60	    if (Test-Path $installOmniGet) {
61	        Write-Step "Deploying OmniGet Universal Package Engine..."
62	        & $installOmniGet -DeployOnly
63	    }
64
65	    # 2. Run DevStack Preset via OmniGet
66	    $omniExe = "C:\Program Files\OmniGet\src\OmniGet.ps1"
67	    if (Test-Path $omniExe) {
68	        Write-Step "Executing DevStack toolchain preset via OmniGet..."
69	        & pwsh.exe -ExecutionPolicy Bypass -File $omniExe -Preset DevStack -Silent
70	    }
71
72	    Refresh-EnvironmentPath
73
74	    # 3. Post-install Desktop Shell & Terminal setup
75	    $desktopShellScript = Join-Path $PSScriptRoot "Install-DesktopShell.ps1"
76	    if (Test-Path $desktopShellScript) {
77	        try {
78	            & $desktopShellScript
79	        }
80	        catch {
81	            Write-WarnMsg "Install-DesktopShell warning: $_"
82	        }
83	    }
84
85	    $terminalScript = Join-Path $PSScriptRoot "Install-WindowsTerminal.ps1"
86	    if (Test-Path $terminalScript) {
87	        try {
88	            & $terminalScript
89	        }
90	        catch {
91	            Write-WarnMsg "Install-WindowsTerminal warning: $_"
92	        }
93	    }
94
95	    $sconfigScript = Join-Path $PSScriptRoot "Install-SConfigPatch.ps1"
96	    if (Test-Path $sconfigScript) {
97	        try {
98	            & $sconfigScript
99	        }
100	        catch {
101	            Write-WarnMsg "Install-SConfigPatch warning: $_"
102	        }
103	    }
104
105	    Write-Success "Developer toolchains and OmniGet installed successfully."
106	}
107
108	Main
