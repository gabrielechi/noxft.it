# NOX server installer for Windows x64.
#   powershell -c "irm https://noxft.it/install-server.ps1 | iex"
# Checks that this is 64-bit Windows on an x64 processor, downloads the official package from the
# NOX GitHub release and installs it in %LOCALAPPDATA%\NOX Server (or $env:NOX_SERVER_DIR).
# An existing appsettings.json and the data folder are kept. No administrator rights are needed
# and the server is not started automatically.
& {
  $ErrorActionPreference = 'Stop'
  $ProgressPreference = 'SilentlyContinue'
  $url = 'https://github.com/gabrielechi/Nox/releases/download/v.3.4/NOX-Server-win-x64.zip'
  $dir = if ($env:NOX_SERVER_DIR) { $env:NOX_SERVER_DIR } else { Join-Path $env:LOCALAPPDATA 'NOX Server' }

  try {
    # 1. operating system and architecture
    if ($env:OS -ne 'Windows_NT') {
      throw 'this installer is for Windows. On Linux use: curl -fsSL https://noxft.it/install-server.sh | bash'
    }
    if (-not [Environment]::Is64BitOperatingSystem) {
      throw 'a 64-bit Windows is required; this system is 32-bit.'
    }
    $arch = $null
    try { $arch = [string][System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture } catch { }
    if (-not $arch) { $arch = if ($env:PROCESSOR_ARCHITEW6432) { $env:PROCESSOR_ARCHITEW6432 } else { $env:PROCESSOR_ARCHITECTURE } }
    if ($arch -notin @('X64', 'AMD64')) {
      throw "the NOX server is built for Windows x64; this system is $arch, so it is not installed."
    }

    # 2. download and unpack in a temporary folder (TLS 1.2 for older PowerShell)
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    $tmp = Join-Path ([IO.Path]::GetTempPath()) ('nox-server-' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tmp | Out-Null
    try {
      Write-Host 'Downloading the NOX server for Windows x64...'
      $zip = Join-Path $tmp 'server.zip'
      Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
      Expand-Archive -Path $zip -DestinationPath (Join-Path $tmp 'package') -Force
      $src = Join-Path $tmp 'package\NOX-Server-win-x64'
      if (-not (Test-Path (Join-Path $src 'Server.exe'))) { throw 'unexpected package contents (Server.exe not found).' }

      # 3. install, keeping an existing configuration and data
      $running = Get-Process -Name 'Server' -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq (Join-Path $dir 'Server.exe') }
      if ($running) { throw 'the NOX server is running from this folder: stop it and run the command again.' }
      New-Item -ItemType Directory -Force -Path $dir | Out-Null
      if (Test-Path (Join-Path $dir 'appsettings.json')) {
        Copy-Item (Join-Path $src 'appsettings.json') (Join-Path $dir 'appsettings.json.new') -Force
        Write-Host 'Your appsettings.json was kept; the new default is in appsettings.json.new'
      } else {
        Copy-Item (Join-Path $src 'appsettings.json') $dir -Force
      }
      Copy-Item (Join-Path $src 'Server.exe'), (Join-Path $src 'README.txt') $dir -Force
      Unblock-File (Join-Path $dir 'Server.exe')
    } finally {
      Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
    }

    Write-Host ''
    Write-Host "NOX server installed in $dir" -ForegroundColor Green
    Write-Host ''
    Write-Host "Start it:          & '$dir\Server.exe'"
    Write-Host "Settings:          $dir\appsettings.json (port, address, HTTPS)"
    Write-Host "Data and backups:  $dir\data (created on first start)"
    Write-Host ''
    Write-Host 'On first start Windows may ask to allow the server through the firewall.'
    Write-Host 'Over plain HTTP passwords travel unencrypted: set up HTTPS before using it outside your own network.'
  } catch {
    Write-Host ''
    Write-Host ("NOX: " + $_.Exception.Message) -ForegroundColor Red
  }
}
