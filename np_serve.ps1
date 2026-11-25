# MAIN publisher: GSMTCS media-properties (covers Spotify, Chrome/YouTube, etc) -> writes np.txt + pushes 'Artist - Title' to Beelink :5197/push.
$ProgressPreference='SilentlyContinue'
Add-Type -AssemblyName System.Runtime.WindowsRuntime
[Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager,Windows.Media.Control,ContentType=WindowsRuntime] | Out-Null
[Windows.Media.Control.GlobalSystemMediaTransportControlsSessionMediaProperties,Windows.Media.Control,ContentType=WindowsRuntime] | Out-Null
$tm=([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { $_.Name -eq 'AsTask' -and $_.IsGenericMethodDefinition } | Select-Object -First 1)
$npp='C:\Users\red\stream\streamstuff\np.txt'
$hb='C:\Users\red\stream\streamstuff\hb.txt'
$last=$null; $prev=''; $cycle=0
function Get-Titles{
  $res=@($null,$null,'Playing','other')
  try{
    $op=[Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager]::RequestAsync()
    $task=$tm.MakeGenericMethod([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager]).Invoke($null,@($op))
    $null=$task.Wait(1500)
    if(-not $task.IsCompleted){ return $res }
    $s=$task.Result.GetCurrentSession()
    if($s -eq $null){ return $res }
    $aop=$s.TryGetMediaPropertiesAsync()
    $atask=$tm.MakeGenericMethod([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionMediaProperties]).Invoke($null,@($aop))
    $null=$atask.Wait(1500)
    if($atask.IsCompleted){
      $mp=$atask.Result
      $ttl=[string]$mp.Title
      if($ttl){
        $au=[string]$s.SourceAppUserModelId
        $src='other'
        if($au -like 'SpotifyAB*'){ $src='spotify' }
        elseif($au -eq '308046B0AF4A39CB' -or $au -like '*Chrome*' -or $au -like '*chromium*'){ $src='youtube' }
        elseif($au){ $src=$au.ToLower() }
        $res=@($ttl,[string]$mp.Artist,[string]$s.GetPlaybackInfo().PlaybackStatus,$src)
      }
    }
  }catch{}
  return $res
}
$wc=New-Object System.Net.WebClient
while($true){
  try{
    $pair=Get-Titles
    $t=$pair[0]; $ar=$pair[1]; $st=[string]$pair[2]; $src=[string]$pair[3]
    $s=''
    if($ar){ $s=$ar+' - ' }
    if($t){ $s=$s+$t }
    if($s){ $last=$s } elseif($last){ $s=[string]$last }
    if($s){
      $lbl='Now playing'
      if($st -eq 'Paused'){ $lbl='Paused' }
      $key=$lbl+'|'+$src+'|'+$s
      $cycle++
      $beat=(($cycle % 20) -eq 0)
      if(($key -ne $prev) -or $beat){
        $prev=$key
        [IO.File]::WriteAllText($npp,('['+$src+'] '+$lbl+': '+$s),(New-Object System.Text.UTF8Encoding $false))
        try{ $wc.UploadString('http://192.168.15.16:5197/push',($lbl+'|'+$s)) }catch{}
      }
    }
    [IO.File]::WriteAllText($hb,(Get-Date).ToString('HH:mm:ss'),(New-Object System.Text.UTF8Encoding $false))
  }catch{
    try{ [IO.File]::AppendAllText($hb,(' ERR '+$_.Exception.Message+' @'+(Get-Date).ToString('HH:mm:ss'))) }catch{}
  }
  Start-Sleep -Seconds 3
}
