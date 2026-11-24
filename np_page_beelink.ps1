# Beelink page server (raw TcpListener :5197). GET / -> composed card HTML; /push caches state pushed from MAIN. Artwork fetched here on change.
$ProgressPreference='SilentlyContinue'
$label='Now playing'; $ttl=''; $artB64=$null; $lastArt=''
function Compose-Page{
  if($script:ttl -eq ''){ return '<!DOCTYPE html><html><body style="margin:0"></body></html>' }
  if($script:artB64){ $imgSrc='data:image/jpeg;base64,'+$script:artB64 } else { $imgSrc='data:image/gif;base64,R0lGODlhAQABAAAAACH5BAEKAAEALAAAAAABAAEAAAICTAEAOw==' }
  $esc=$script:ttl -replace '&','&amp;' -replace '<','&lt;' -replace '>','&gt;'
  $lblTxt='Now playing'
  if($script:label -eq 'Paused'){ $lblTxt='Paused' }
  $h='<!DOCTYPE html>'
  $h=$h+'<html><head><meta charset="utf-8"><meta http-equiv="refresh" content="5"><style>'
  $h=$h+'html,body{margin:0;padding:0;background:transparent;overflow:hidden;}'
  $h=$h+'.card{display:flex;align-items:center;gap:14px;height:96px;padding:0 22px 0 14px;box-sizing:border-box;background:rgba(6,10,14,0.85);border:1px solid rgba(55,255,154,0.45);border-radius:10px;}'
  $h=$h+'img{width:76px;height:76px;border-radius:10px;border:1px solid rgba(255,255,255,0.18);flex:none;}'
  $h=$h+'.txt{min-width:0;}'
  $h=$h+'.lbl{font:600 14px Segoe UI;letter-spacing:2px;text-transform:uppercase;color:#37ff9a;margin-bottom:4px;}'
  $h=$h+'.ttl{font:600 26px Segoe UI;color:#DEDED0;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;max-width:470px;}'
  $h=$h+'</style></head><body><div class="card">'
  $h=$h+'<img src="'+$imgSrc+'" alt="">'
  $h=$h+'<div class="txt"><div class="lbl">'+$lblTxt+'</div><div class="ttl">'+$esc+'</div></div>'
  $h=$h+'</div></body></html>'
  return $h
}
function Update-Cache([string]$payload){
  if(-not $payload){ return }
  $ci=$payload.IndexOf('|')
  if($ci -gt 0){ $script:label=$payload.Substring(0,$ci); $script:ttl=$payload.Substring($ci+1) }
  else { $script:ttl=$payload; $script:label='Now playing' }
  if($script:ttl -ne $script:lastArt){
    $script:lastArt=$script:ttl
    try{
      $w=New-Object System.Net.WebClient
      $w.Encoding=[Text.Encoding]::UTF8
      $q=[Uri]::EscapeDataString($script:ttl)
      $j=$w.DownloadString('https://itunes.apple.com/search?term='+$q+'&entity=song&limit=1')
      $u=([regex]'"artworkUrl100":"([^"]+)"').Match($j).Groups[1].Value
      if($u){
        $u=$u -replace '\d+x\d+(bb)?\.jpg','100x100bb.jpg'
        $img=$w.DownloadData($u)
        if($img.Length -gt 500){ $script:artB64=[Convert]::ToBase64String($img) }
      }
    }catch{}
  }
}
$ip=[Net.IPAddress]::Any
$lst=New-Object System.Net.Sockets.TcpListener($ip,5197)
$lst.Start()
while($true){
  try{
    $c=$lst.AcceptTcpClient()
    $s=$c.GetStream()
    $s.ReadTimeout=3000
    $buf=New-Object byte[] 8192
    $n=$s.Read($buf,0,8192)
    $txt=[Text.Encoding]::UTF8.GetString($buf,0,$n)
    $hl=$txt.IndexOf([string][char]13+[char]10+[char]13+[char]10)
    $head=$txt; $body=''
    if($hl -ge 0){ $head=$txt.Substring(0,$hl); $body=$txt.Substring($hl+4) }
    if($head -match 'Content-Length:\s*(\d+)'){
      $cl=[int]$Matches[1]
      while($body.Length -lt $cl){
        $n=$s.Read($buf,0,8192)
        if($n -le 0){ break }
        $body=$body+[Text.Encoding]::UTF8.GetString($buf,0,$n)
      }
      if($body.Length -gt $cl){ $body=$body.Substring(0,$cl) }
    }
    $path='/'
    if($head -match '(?:GET|POST)\s+(\S+)'){ $path=$Matches[1] }
    if($path -like '/push*'){ Update-Cache $body }
    $out=Compose-Page
    $b=[Text.Encoding]::UTF8.GetBytes($out)
    $nl=[char]13+[char]10
    $hdr='HTTP/1.1 200 OK'+$nl+'Content-Type: text/html; charset=utf-8'+$nl+'Content-Length: '+$b.Length.ToString()+$nl+'Cache-Control: no-cache'+$nl+'Connection: close'+$nl+$nl
    $hb=[Text.Encoding]::ASCII.GetBytes($hdr)
    $s.Write($hb,0,$hb.Length)
    $s.Write($b,0,$b.Length)
    $s.Flush()
    $c.Close()
  }catch{}
}
