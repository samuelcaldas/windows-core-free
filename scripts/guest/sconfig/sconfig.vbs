'----------------------------------------------------------------------------
' Windows Core Developer Edition - Server Control Center (sconfig.vbs)
' Modular TUI Control Panel replacement for Windows Server Core RS5 / Hyper-V Server
'----------------------------------------------------------------------------

Option Explicit

Const cnWshRunning = 0
Const cnWshFinished = 1
Const cnWshFailed = 2

Dim oShell, objShell, oUACExec
Dim objWMIService, colSettings, objComputer
Dim pcname, groupname, group_type
Dim MgmtNIC, DisplayIP, OptionSelection
Dim strModulesDir

Set oShell = WScript.CreateObject("WScript.Shell")

' Verify Administrator Privileges
Set oUACExec = oShell.Exec("cmd /c " & Chr(34) & "whoami /groups | find " & Chr(34) & "S-1-16-12288" & Chr(34) & Chr(34))
Do While (oUACExec.Status = cnWshRunning)
    WScript.Sleep 100
Loop

If oUACExec.ExitCode <> 0 Then
    Set objShell = CreateObject("Shell.Application")
    objShell.ShellExecute "cscript", Chr(34) & WScript.ScriptFullName & Chr(34), "", "runas", 1
    WScript.Quit
End If

Set objWMIService = GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\cimv2")

strModulesDir = oShell.ExpandEnvironmentStrings("%SystemRoot%\System32\sconfig-modules")
If Not CreateObject("Scripting.FileSystemObject").FolderExists(strModulesDir) Then
    strModulesDir = "C:\Provisioning\scripts\sconfig\modules"
End If

'----------------------------------------------------------------------------
' Main Loop
'----------------------------------------------------------------------------
Do
    RefreshSystemInfo()

    WScript.Echo ""
    WScript.Echo "============================================================================"
    WScript.Echo "           Windows Core Developer Edition - Server Control Center           "
    WScript.Echo "============================================================================"
    WScript.Echo ""
    WScript.Echo " [ System & Identity ]"
    WScript.Echo "  1) Computer Name:                  " & pcname
    WScript.Echo "  2) Workgroup Name:                  " & groupname
    WScript.Echo "  3) Add Local Administrator Account"
    WScript.Echo "  4) Date and Time Settings"
    WScript.Echo ""
    WScript.Echo " [ Network & Remote Access ]"
    WScript.Echo "  5) Network Adapter & IP Settings:  " & DisplayIP
    WScript.Echo "  6) OpenSSH Server & Remote Access Dashboard"
    WScript.Echo ""
    WScript.Echo " [ Developer Tools & Distro Utilities ]"
    WScript.Echo "  7) Distro App Store & Toolchains (Ninite / .NET / Python / Node)"
    WScript.Echo "  8) Desktop Shell & File Manager (WinXShell / WinFile / ReactShell)"
    WScript.Echo "  9) System Performance & Memory Pruning (Atlas / Core Tuning)"
    WScript.Echo ""
    WScript.Echo " [ Power & Session ]"
    WScript.Echo " 10) Log Off User"
    WScript.Echo " 11) Restart Server"
    WScript.Echo " 12) Shut Down Server"
    WScript.Echo " 13) Exit to PowerShell 7 / Command Line"
    WScript.Echo "============================================================================"
    WScript.Echo ""
    WScript.StdOut.Write "Enter number to select an option (1-13): "

    OptionSelection = Trim(WScript.StdIn.ReadLine())
    WScript.Echo ""

    Select Case OptionSelection
        Case "1"
            ChangeComputerName()

        Case "2"
            JoinWorkgroup()

        Case "3"
            AddToAdminGroup()

        Case "4"
            oShell.Run "control.exe timedate.cpl", 1, True

        Case "5"
            ManagementNICsettings()

        Case "6"
            RunPowerShellModule "mod-ssh.ps1"

        Case "7"
            RunPowerShellModule "mod-tools.ps1"

        Case "8"
            RunPowerShellModule "mod-shell.ps1"

        Case "9"
            RunPowerShellModule "mod-optimize.ps1"

        Case "10"
            If MsgBox("Are you sure you want to log off?", vbYesNo + vbDefaultButton2, "Log Off") = vbYes Then
                oShell.Run "logoff", 7, True
            End If

        Case "11"
            If MsgBox("Are you sure you want to restart?", vbYesNo + vbDefaultButton2, "Restart Server") = vbYes Then
                oShell.Run "shutdown /r /t 0", 1, True
            End If

        Case "12"
            If MsgBox("Are you sure you want to shut down?", vbYesNo + vbDefaultButton2, "Shut Down Server") = vbYes Then
                oShell.Run "shutdown /s /t 0", 1, True
            End If

        Case "13"
            WScript.Quit

        Case Else
            ' Invalid selection - loop again
    End Select
Loop

'----------------------------------------------------------------------------
' Helper Functions & Subroutines
'----------------------------------------------------------------------------

Sub RefreshSystemInfo()
    Dim colComputers, objComp, colNICs, objNIC
    Set colComputers = objWMIService.ExecQuery("SELECT * FROM Win32_ComputerSystem")
    For Each objComp In colComputers
        pcname = objComp.Name
        groupname = objComp.Workgroup
        If objComp.PartOfDomain Then
            group_type = "Domain"
            groupname = objComp.Domain
        Else
            group_type = "Workgroup"
        End If
    Next

    DisplayIP = "No IP Address"
    Set colNICs = objWMIService.ExecQuery("SELECT * FROM Win32_NetworkAdapterConfiguration WHERE IPEnabled = True")
    For Each objNIC In colNICs
        If Not IsNull(objNIC.IPAddress) Then
            DisplayIP = objNIC.IPAddress(0)
            MgmtNIC = objNIC.Index
            Exit For
        End If
    Next
End Sub

Sub RunPowerShellModule(strModuleName)
    Dim strScriptPath, strCommand, returnCode
    strScriptPath = strModulesDir & "\" & strModuleName
    If Not CreateObject("Scripting.FileSystemObject").FileExists(strScriptPath) Then
        strScriptPath = "C:\Provisioning\scripts\sconfig\modules\" & strModuleName
    End If

    strCommand = "pwsh.exe -NoProfile -ExecutionPolicy Bypass -File """ & strScriptPath & """"
    returnCode = oShell.Run(strCommand, 1, True)
End Sub

Sub ChangeComputerName()
    Dim NewComputerName, result, confirm
    WScript.Echo "Change Computer Name"
    WScript.Echo ""
    WScript.StdOut.Write "Enter new computer name (Blank=Cancel): "
    NewComputerName = Trim(WScript.StdIn.ReadLine())

    If NewComputerName <> "" Then
        WScript.Echo "Changing Computer name to " & NewComputerName & "..."
        result = oShell.Run("netdom renamecomputer %computername% /force /NewName:" & NewComputerName, 7, True)
        If result = 0 Then
            confirm = MsgBox("Computer name changed successfully." & vbCrLf & "You must restart your computer to apply changes. Restart now?", vbYesNo, "Restart")
            If confirm = vbYes Then oShell.Run "shutdown /r /t 0", 1, True
        Else
            MsgBox "Failed to rename computer. Error code: " & result, vbCritical, "Error"
        End If
    End If
End Sub

Sub JoinWorkgroup()
    Dim NewGroupName, targetstr, returncode
    WScript.Echo "Change Workgroup Membership"
    WScript.Echo ""
    WScript.StdOut.Write "Enter new workgroup name (Blank=Cancel): "
    NewGroupName = Trim(WScript.StdIn.ReadLine())

    If NewGroupName <> "" Then
        WScript.Echo "Joining workgroup " & NewGroupName & "..."
        targetstr = "wmic computersystem where name=""" & pcname & """ call joindomainorworkgroup name=""" & NewGroupName & """"
        returncode = oShell.Run(targetstr, 7, True)
        If returncode <> 0 Then
            MsgBox "Failed to join workgroup.", vbCritical, "Error"
        Else
            MsgBox "Successfully joined workgroup: " & NewGroupName, vbInformation, "Workgroup"
        End If
    End If
End Sub

Sub AddToAdminGroup()
    Dim AddUserAcct, targetstr
    WScript.Echo "Add Local Administrator"
    WScript.Echo ""
    WScript.StdOut.Write "Enter username to add to local Administrators group (Blank=Cancel): "
    AddUserAcct = Trim(WScript.StdIn.ReadLine())

    If AddUserAcct <> "" Then
        targetstr = "net localgroup Administrators /add " & AddUserAcct
        oShell.Run "cmd /c " & targetstr & " & pause", 1, True
    End If
End Sub

Sub ManagementNICsettings()
    Dim nics, nic, NIC_option, selectedIndex, targetNIC
    Do
        Set nics = objWMIService.ExecQuery("SELECT * FROM Win32_NetworkAdapterConfiguration WHERE IPEnabled = True")
        WScript.Echo "----------------------------------------------------------------------------"
        WScript.Echo "                        Network Adapter Settings                            "
        WScript.Echo "----------------------------------------------------------------------------"
        WScript.Echo " Index  IP Address       Description"
        WScript.Echo " -----  ---------------  --------------------------------------------------"

        For Each nic In nics
            WScript.Echo "   " & nic.Index & vbTab & nic.IPAddress(0) & vbTab & Left(nic.Description, 50)
        Next
        WScript.Echo "----------------------------------------------------------------------------"
        WScript.Echo ""
        WScript.StdOut.Write "Select Network Adapter Index# (Blank=Return to Main Menu): "
        NIC_option = Trim(WScript.StdIn.ReadLine())

        If NIC_option = "" Then Exit Sub

        Set targetNIC = Nothing
        For Each nic In nics
            If CStr(nic.Index) = NIC_option Then
                Set targetNIC = nic
                Exit For
            End If
        Next

        If Not targetNIC Is Nothing Then
            ConfigureSingleNIC(targetNIC)
        Else
            MsgBox "Invalid Adapter Index selected.", vbExclamation, "Network Settings"
        End If
    Loop
End Sub

Sub ConfigureSingleNIC(objNIC)
    Dim choice, ip_address, netmask, gateway, dns1, dns2, res
    Do
        WScript.Echo ""
        WScript.Echo "Adapter Index: " & objNIC.Index & " (" & objNIC.Description & ")"
        WScript.Echo "Current IP:    " & objNIC.IPAddress(0)
        WScript.Echo "DHCP Enabled:  " & objNIC.DHCPEnabled
        WScript.Echo ""
        WScript.Echo "  1) Set Static IP Address"
        WScript.Echo "  2) Set to DHCP (Automatic IP)"
        WScript.Echo "  3) Configure DNS Servers"
        WScript.Echo "  4) Return to Network Menu"
        WScript.Echo ""
        WScript.StdOut.Write "Select option (1-4): "
        choice = Trim(WScript.StdIn.ReadLine())

        Select Case choice
            Case "1"
                WScript.StdOut.Write "Enter static IP address: "
                ip_address = Trim(WScript.StdIn.ReadLine())
                If ip_address <> "" Then
                    WScript.StdOut.Write "Enter subnet mask (Default: 255.255.255.0): "
                    netmask = Trim(WScript.StdIn.ReadLine())
                    If netmask = "" Then netmask = "255.255.255.0"
                    WScript.StdOut.Write "Enter default gateway: "
                    gateway = Trim(WScript.StdIn.ReadLine())

                    res = objNIC.EnableStatic(Array(ip_address), Array(netmask))
                    If gateway <> "" Then objNIC.SetGateways Array(gateway), Array(1)
                    MsgBox "Static IP applied with result: " & res, vbInformation, "Network Settings"
                End If

            Case "2"
                res = objNIC.EnableDHCP()
                MsgBox "DHCP enabled with result: " & res, vbInformation, "Network Settings"

            Case "3"
                WScript.StdOut.Write "Enter Preferred DNS (e.g. 1.1.1.1 or Blank=Cancel): "
                dns1 = Trim(WScript.StdIn.ReadLine())
                If dns1 <> "" Then
                    WScript.StdOut.Write "Enter Alternate DNS (Blank=None): "
                    dns2 = Trim(WScript.StdIn.ReadLine())
                    If dns2 <> "" Then
                        res = objNIC.SetDNSServerSearchOrder(Array(dns1, dns2))
                    Else
                        res = objNIC.SetDNSServerSearchOrder(Array(dns1))
                    End If
                    MsgBox "DNS server configuration applied with result: " & res, vbInformation, "Network Settings"
                End If

            Case "4"
                Exit Sub
        End Select
    Loop
End Sub
