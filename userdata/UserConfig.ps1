
Configuration UserConfig {
  Import-DscResource -ModuleName PSDesiredStateConfiguration
  Script RootUserCreate {
    GetScript = { @{ Result = (Get-WMiObject -class Win32_UserAccount | Where { $_.Name -eq 'root' }) } }
    SetScript = {
      $password = [regex]::matches((New-Object Net.WebClient).DownloadString('http://169.254.169.254/latest/user-data'), '(?s)<rootPassword>(.*)</rootPassword>').Groups[1].Value
      if (!$password) {
        $password = [Guid]::NewGuid().ToString().Substring(0, 13)
      }
      Start-Process 'net' -ArgumentList @('user', 'root', $password, '/ADD', '/active:yes', '/expires:never') -Wait -NoNewWindow -PassThru -RedirectStandardOutput ('{0}\log\{1}.net-user-root.stdout.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss")) -RedirectStandardError ('{0}\log\{1}.net-user-root.stderr.log' -f $env:SystemDrive, [DateTime]::Now.ToString("yyyyMMddHHmmss"))
      Start-Job -ScriptBlock {

        # show file extensions in explorer
        Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\' -Type 'DWord' -Name 'HideFileExt' -Value '0x00000000' # off

        # a larger console, with a larger buffer
        Set-ItemProperty 'HKCU:\Console\' -Type 'DWord' -Name 'QuickEdit' -Value '0x00000001' # on
        Set-ItemProperty 'HKCU:\Console\' -Type 'DWord' -Name 'InsertMode' -Value '0x00000001' # on
        Set-ItemProperty 'HKCU:\Console\' -Type 'DWord' -Name 'ScreenBufferSize' -Value '0x0bb800a0' # 160x3000
        Set-ItemProperty 'HKCU:\Console\' -Type 'DWord' -Name 'WindowSize' -Value '0x003c00a0' # 160x60
        Set-ItemProperty 'HKCU:\Console\' -Type 'DWord' -Name 'HistoryBufferSize' -Value '0x000003e7' # 999 (max)
        Set-ItemProperty 'HKCU:\Console\' -Type 'DWord' -Name 'ScreenColors' -Value '0x0000000a' # green on black
        Set-ItemProperty 'HKCU:\Console\' -Type 'DWord' -Name 'FontSize' -Value '0x000c0000' # 12
        Set-ItemProperty 'HKCU:\Console\' -Type 'DWord' -Name 'FontFamily' -Value '0x00000036' # default console fonts
        Set-ItemProperty 'HKCU:\Console\' -Type 'String' -Name 'FaceName' -Value 'Lucida Console'

        # a visible cursor on dark backgrounds (as well as light)
        Set-ItemProperty 'HKCU:\Control Panel\Cursors\' -Type 'String' -Name 'IBeam' -Value '%SYSTEMROOT%\Cursors\beam_r.cur'

        # cmd and subl pinned to taskbar
        ((New-Object -c Shell.Application).Namespace('{0}\system32' -f $env:SystemRoot).parsename('cmd.exe')).InvokeVerb('taskbarpin')
        ((New-Object -c Shell.Application).Namespace('{0}\Sublime Text 3' -f $env:ProgramFiles).parsename('sublime_text.exe')).InvokeVerb('taskbarpin')

        # ssh authorized_keys
        New-Item ('{0}\.ssh' -f $env:UserProfile) -type directory -force
        (New-Object Net.WebClient).DownloadFile('https://raw.githubusercontent.com/MozRelOps/OpenCloudConfig/master/userdata/Configuration/authorized_keys', ('{0}\.ssh\authorized_keys' -f $env:UserProfile))
        Unblock-File -Path ('{0}\.ssh\authorized_keys' -f $env:UserProfile)
        
      } -Credential (New-Object Management.Automation.PSCredential 'root', (ConvertTo-SecureString "$password" -AsPlainText -Force))
      #& icacls @(('{0}\Users\root' -f $env:SystemDrive), '/T', '/C', '/grant', 'Administrators:(F)')
    }
    TestScript = { if (Get-WMiObject -class Win32_UserAccount | Where { $_.Name -eq 'root' }) { $true } else { $false } }
  }
  Group RootAsAdministrator {
    DependsOn = '[Script]RootUserCreate'
    GroupName = 'Administrators'
    Ensure = 'Present'
    MembersToInclude = 'root'
  }
  Script PowershellProfileCreate {
    GetScript = { @{ Result = (Test-Path -Path ('{0}\Microsoft.PowerShell_profile.ps1' -f $PsHome) -ErrorAction SilentlyContinue ) } }
    SetScript = {
      Add-Content -Path ('{0}\Microsoft.PowerShell_profile.ps1' -f $PsHome) -Value '$user32 = Add-Type -Name ''User32'' -Namespace ''Win32'' -PassThru -MemberDefinition ''[DllImport("user32.dll")]public static extern int GetWindowLong(IntPtr hWnd, int nIndex);[DllImport("user32.dll")]public static extern int SetWindowLong(IntPtr hWnd, int nIndex, int dwNewLong);[DllImport("user32.dll", SetLastError = true)]public static extern bool SetLayeredWindowAttributes(IntPtr hWnd, uint crKey, int bAlpha, uint dwFlags);'''
      Add-Content -Path ('{0}\Microsoft.PowerShell_profile.ps1' -f $PsHome) -Value 'Get-Process | Where-Object { @(''powershell'', ''cmd'') -contains $_.ProcessName } | % { $user32::SetWindowLong($_.MainWindowHandle, -20, ($user32::GetWindowLong($_.MainWindowHandle, -20) -bor 0x80000)) | Out-Null;$user32::SetLayeredWindowAttributes($_.MainWindowHandle, 0, 200, 0x02) | Out-Null }'
      Set-ItemProperty 'HKLM:\Software\Microsoft\Command Processor' -Type 'String' -Name 'AutoRun' -Value 'powershell -NoLogo -NonInteractive'
    }
    TestScript = { if (Test-Path -Path ('{0}\Microsoft.PowerShell_profile.ps1' -f $PsHome) -ErrorAction SilentlyContinue ) { $true } else { $false } }
  }
}