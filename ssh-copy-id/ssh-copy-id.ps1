<#
 .NAME
    ssh-copy-id.ps1
 .SYNOPSIS
    Copy public key to remote hosts
 .DESCRIPTION
    See Synopsis
 .SYNTAX
    Invoke directly from the powershell command line
 .EXAMPLES
    .\Scriptname -i idtest.pub user@example.com 
    .\ScriptName user@example.com 
.NOTES
    AUTHOR: VijayS / deevus
    DATE:   2015-03-22
    COMMENT: Modified to work with Scoop.sh
    DEPENDENCIES: 
        ssh
 .HELPURL
    http://stackoverflow.com
 .SEEALSO
 .REFERENCE
    http://www.christowles.com/2011/06/how-to-ssh-from-powershell-using.html
#>

Param(
    [Parameter(Position=0,Mandatory=$true,HelpMessage="The remote computer")]
    [String]$remoteHost,

    [Parameter(HelpMessage="The public key file to copy")]
    [ValidateScript({Test-Path $_})]
    [Alias("i")]
    [String]$identity="id_rsa.pub",

    [switch]$ConnectOnceToAcceptHostKey=$false
    )

####################################
Function Get-SSHCommands {
 Param($Target, $CommandArray, $PlinkAndPath, $ConnectOnceToAcceptHostKey = $true)
 
 $plinkoptions = "$Target"
 
 #Build ssh Commands
 $CommandArray += "exit"
 $remoteCommand = ""
 $CommandArray | % {
  $remoteCommand += [string]::Format('{0}; ', $_)
 }
 
 #plist prompts to accept client host key. This section will
 #login and accept the host key then logout.
 if($ConnectOnceToAcceptHostKey)
 {
  $PlinkCommand  = [string]::Format("echo y | & '{0}' {1} exit",
   $PlinkAndPath, $plinkoptions )
  #Write-Host $PlinkCommand
  $msg = Invoke-Expression $PlinkCommand
 }
 
 #format plist command
 # $PlinkCommand = [string]::Format("'{0}' {1} '{2}'",
 #  $PlinkAndPath, $plinkoptions , $remoteCommand)
 $PlinkCommand = [string]::Format('{0} {1} "{2}"',
  $PlinkAndPath, $plinkoptions , $remoteCommand)
 
 #ready to run the following command
 return "$PlinkCommand"
}
###
Function Invoke-DOSCommands {
    Param(
        [Parameter(Position=0,Mandatory=$true)]
        [String]$cmd,
        [String]$tmpname = $(([string](Get-Random -Minimum 10000 -Maximum 99999999)) + ".cmd"),
        [switch]$tmpdir = $true)
    if ($tmpdir) {
        $cmdpath = $(Join-Path -Path $env:TEMP -ChildPath $tmpname);
    }
    else {
        $cmdpath = ".\" + $tmpname
    }
    Write-Debug "tmpfile: " + $cmdpath
    Write-Debug "cmd: " + $cmd
    echo $cmd | Out-File -FilePath $cmdpath -Encoding ascii;
    & cmd.exe /c $cmdpath | Out-Null
}
##################
$ErrorActionPreference = "Stop" # "Continue" "SilentlyContinue" "Stop" "Inquire"
$DebugPreference = "Continue"
trap { #Stop on all errors
    Write-Error "ERROR: $_"
}

$PlinkAndPath = $((Get-Command -Name ssh).Source)
 
#from http://serverfault.com/questions/224810/is-there-an-equivalent-to-ssh-copy-id-for-windows
$Commands = @()
$Commands += "umask 077" #change permissions to be restrictive
$Commands += "test -d .ssh || mkdir .ssh" #test and create .ssh director if it doesn't exist
$Commands += "cat >> .ssh/authorized_keys" #append the public key to file

Try {
    $tmp = Get-ItemProperty -Path $identity
    $tmp = Get-ItemProperty -Path $PlinkAndPath
    
    [String]$cmdline = Get-SSHCommands -Target $remoteHost `
     -PlinkAndPath $PlinkAndPath `
     -CommandArray $Commands `
     -ConnectOnceToAcceptHostKey $ConnectOnceToAcceptHostKey

     # pipe the public key to the plink session to get it appended in the right place
     $cmdline = "type ""$identity"" | " + $cmdline

     Invoke-Expression $cmdline
}
Catch {
    Write-Error "$($_.Exception.Message)"
}
