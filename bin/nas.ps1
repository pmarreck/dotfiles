<#
.SYNOPSIS
    Mount the home NAS as a network drive on Windows (PowerShell).

.DESCRIPTION
    Cross-platform companion to `bin/nas` (the Bash script for macOS/Linux/NixOS).
    Maps a drive letter to the NAS over SMB (default) or NFS, optionally making
    the mapping persist across reboots, then opens Explorer at the drive.

    SMB is preferred on Windows — it works out of the box on every modern
    Windows version (Win10/Win11/Server) and requires no optional features.

    NFS works too, but only after you enable the optional "Client for NFS"
    Windows feature once (Settings → Apps → Optional Features → "NFS Client",
    OR `Enable-WindowsOptionalFeature -Online -FeatureName ServicesForNFS-ClientOnly,ClientForNFS-Infrastructure`).
    The NFS server on the NAS exports the path `/mnt/Coruscatology/Fileserver`.

.PARAMETER Protocol
    SMB (default) or NFS.

.PARAMETER DriveLetter
    Single letter to map (default: Z). Do NOT include the colon.

.PARAMETER NasHost
    Host or IP of the NAS (default: 192.168.7.234).

.PARAMETER SmbShare
    SMB share name (default: Fileserver). Used only when -Protocol SMB.

.PARAMETER NfsPath
    NFS export path (default: /mnt/Coruscatology/Fileserver). Used only when
    -Protocol NFS. Windows' Mount command converts forward slashes itself; you
    can pass the path either with forward or back slashes.

.PARAMETER Persist
    Make the mapping survive reboots:
      SMB: New-SmbMapping -Persistent $true
      NFS: -Persistent (mount /persistent:yes equivalent)
    Default: not persistent (ephemeral, gone at logoff/reboot).

.PARAMETER NoOpen
    Skip opening Explorer at the mounted drive after success.

.PARAMETER DryRun
    Print the commands that would be executed; do not actually mount.

.PARAMETER Help
    Show this help and exit.

.EXAMPLE
    .\nas.ps1
    # Map \\192.168.7.234\Fileserver to Z: via SMB, ephemeral, open Explorer.

.EXAMPLE
    .\nas.ps1 -Persist -DriveLetter N
    # Map to N: via SMB and remember it across reboots.

.EXAMPLE
    .\nas.ps1 -Protocol NFS -DriveLetter M -Persist
    # NFS mount on M:, persistent. Requires Windows "Client for NFS" enabled.

.NOTES
    Counterpart to dotfiles/bin/nas (Bash). Same NAS, same defaults where
    they make sense.
#>
[CmdletBinding()]
param(
    [ValidateSet('SMB', 'NFS')]
    [string]$Protocol = 'SMB',

    [ValidatePattern('^[A-Za-z]$')]
    [string]$DriveLetter = 'Z',

    [string]$NasHost = '192.168.7.234',

    [string]$SmbShare = 'Fileserver',

    [string]$NfsPath = '/mnt/Coruscatology/Fileserver',

    [switch]$Persist,

    [switch]$NoOpen,

    [switch]$DryRun,

    [switch]$Help
)

if ($Help) {
    Get-Help -Detailed $MyInvocation.MyCommand.Path
    exit 0
}

$ErrorActionPreference = 'Stop'
$drive = $DriveLetter.ToUpper()
$drivePath = "${drive}:"

function Invoke-OrDryRun {
    param(
        [Parameter(Mandatory)] [string]$Description,
        [Parameter(Mandatory)] [scriptblock]$Action
    )
    if ($DryRun) {
        Write-Host "DRY: $Description"
    } else {
        Write-Host ">>> $Description"
        & $Action
    }
}

function Test-DriveInUse {
    param([string]$Letter)
    # Both PSDrive and SmbMapping perspectives — a drive can show up via either.
    if (Get-PSDrive -Name $Letter -ErrorAction SilentlyContinue) { return $true }
    if (Get-SmbMapping -LocalPath "${Letter}:" -ErrorAction SilentlyContinue) { return $true }
    return $false
}

switch ($Protocol) {

    'SMB' {
        $remote = "\\$NasHost\$SmbShare"
        Write-Host "Target: $remote -> ${drivePath}  (SMB, Persist=$Persist)"

        if (Test-DriveInUse -Letter $drive) {
            Write-Warning "${drivePath} is already in use. Skipping mount; unmap first if you want to remap."
            if (-not $NoOpen -and -not $DryRun) { Start-Process explorer.exe $drivePath }
            return
        }

        Invoke-OrDryRun -Description "New-SmbMapping -LocalPath $drivePath -RemotePath $remote -Persistent:`$$Persist" -Action {
            # New-SmbMapping is the modern, supported API (Windows 8+/Server 2012+).
            # `net use` would also work but is being deprecated in favor of the SMB cmdlets.
            New-SmbMapping -LocalPath $drivePath -RemotePath $remote -Persistent:$Persist | Out-Null
        }
    }

    'NFS' {
        # Windows Mount.exe accepts UNC-style forward-slash NFS paths:
        #   mount -o anon \\host\path\to\share Z:
        # Normalize whichever slash style the user passed.
        $nfsBackslashPath = ($NfsPath -replace '/', '\').TrimStart('\')
        $remote = "\\$NasHost\$nfsBackslashPath"

        Write-Host "Target: $remote -> ${drivePath}  (NFS, Persist=$Persist)"

        $haveNfs = Get-Command mount.exe -ErrorAction SilentlyContinue
        if (-not $haveNfs) {
            Write-Error @"
NFS client not available. Enable the Windows feature 'Client for NFS' first:
  Enable-WindowsOptionalFeature -Online -FeatureName ServicesForNFS-ClientOnly,ClientForNFS-Infrastructure -NoRestart
(then reopen PowerShell). Or just use the default protocol: -Protocol SMB.
"@
            exit 1
        }

        if (Test-DriveInUse -Letter $drive) {
            Write-Warning "${drivePath} is already in use. Skipping mount; unmap first if you want to remap."
            if (-not $NoOpen -and -not $DryRun) { Start-Process explorer.exe $drivePath }
            return
        }

        $mountArgs = @('-o', 'anon,rsize=65536,wsize=65536,timeout=10,retry=3')
        if ($Persist) { $mountArgs += @('-o', 'fileaccess=755') }  # cosmetic; real persistence is /persistent
        $mountArgs += @($remote, $drivePath)

        Invoke-OrDryRun -Description "mount.exe $($mountArgs -join ' ')" -Action {
            & mount.exe @mountArgs
            if ($LASTEXITCODE -ne 0) { throw "mount.exe failed (exit $LASTEXITCODE)" }

            if ($Persist) {
                # Windows NFS persistence is per-user, configured via registry
                # under HKCU\Software\Microsoft\ClientForNFS\CurrentVersion\Default
                # OR via `nfsadmin client config` for system-wide. The simplest
                # cross-machine approach is `net use` with /persistent:yes,
                # which works for NFS too via the same redirector.
                & net.exe use $drivePath $remote /persistent:yes | Out-Null
                if ($LASTEXITCODE -ne 0) {
                    Write-Warning "Mount succeeded but persistence registration via 'net use' failed (exit $LASTEXITCODE)."
                }
            }
        }
    }
}

if (-not $NoOpen -and -not $DryRun) {
    Write-Host ">>> opening Explorer at $drivePath"
    Start-Process explorer.exe $drivePath
}

Write-Host "Done."
