
Configuration UserConfig {
  Import-DscResource -ModuleName PSDesiredStateConfiguration
  File RootHome {
    Type = 'Directory'
    DestinationPath = ('{0}\Users\root' -f $env:SystemDrive)
    Ensure = 'Present'
  }
  Script RootUserCreate {
    DependsOn = '[File]RootHome'
    GetScript = { @{ Result = (Get-WMiObject -class Win32_UserAccount | Where { $_.Name -eq 'root' }) } }
    SetScript = {
      & net @('user', 'root', [Guid]::NewGuid().ToString().Substring(0, 13), '/ADD', '/active:yes', '/expires:never')
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
}