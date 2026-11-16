###############################################################################
#  Gera o instalador grafico aghuse_setup_13.250-STABLE_Windows.exe
#
#  Uso:  powershell -ExecutionPolicy Bypass -File windows\setup\gerar-setup.ps1 [-Iscc <ISCC.exe>] [-Variante <pasta>]
#
#  -Variante <pasta>: gera o instalador de uma VARIANTE NAO OFICIAL. A pasta contem o aghu.ear
#  modificado e o arquivo VARIANTE (NOME, VERSAO, DESCRICAO...). Ver modificacoes/ no repositorio.
#
#  1. reconstroi pacote\ (aghu.ear, dbaghu.dmp ...) e o zip do WildFly a partir
#     das partes do repositorio e confere os SHA-256;
#  2. obtem o OpenJDK 17.0.2 e o PostgreSQL 15 para Windows (cache\ ou download
#     das fontes oficiais), confere os SHA-256 e extrai;
#  3. compila aghuse.iss com o Inno Setup 6.3+ (saida\).
###############################################################################
param([string]$Iscc = '', [string]$Variante = '')
. (Join-Path (Split-Path -Parent $PSScriptRoot) 'lib\comum.ps1')

$RAIZ = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$BUILD = Join-Path $PSScriptRoot 'build'
$CACHE = Join-Path $PSScriptRoot 'cache'
$SAIDA = Join-Path $PSScriptRoot 'saida'

function Juntar-Partes([string]$Primeira, [string]$Destino) {
  $base = $Primeira.Substring(0, $Primeira.Length - '.parte-001'.Length)
  $partes = Get-ChildItem -LiteralPath (Split-Path $Primeira) -File -Filter ((Split-Path $base -Leaf) + '.parte-*') | Sort-Object Name
  $s = [IO.File]::Create($Destino)
  try { foreach ($p in $partes) { $e = [IO.File]::OpenRead($p.FullName); try { $e.CopyTo($s) } finally { $e.Close() } } } finally { $s.Close() }
}
function Conferir([string]$Arq, [string]$Sha) {
  if ((Get-FileHash -LiteralPath $Arq -Algorithm SHA256).Hash -ne $Sha.ToUpper()) { erro "hash SHA-256 nao confere: $Arq" }
}

try {
  if (-not $Iscc) {
    foreach ($c in @("$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe", "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe", "$env:ProgramFiles\Inno Setup 6\ISCC.exe")) {
      if (Test-Path -LiteralPath $c) { $Iscc = $c; break }
    }
  }
  if (-not $Iscc -or -not (Test-Path -LiteralPath $Iscc)) { erro 'ISCC.exe (Inno Setup 6.3 ou superior) nao encontrado. Instale de https://jrsoftware.org/isdl.php ou informe -Iscc.' }
  foreach ($d in @($BUILD, $CACHE, $SAIDA)) { if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d | Out-Null } }

  etapa 'Pacote da aplicacao'
  $pac = Join-Path $BUILD 'pacote'
  if (Test-Path $pac) { Remove-Item $pac -Recurse -Force }
  New-Item -ItemType Directory -Path $pac | Out-Null
  $somas = @{}
  foreach ($l in [IO.File]::ReadAllLines((Join-Path $RAIZ 'pacote\SHA256SUMS'))) { if ($l -match '^([0-9a-f]{64})\s+\*?(.+)$') { $somas[$Matches[2].Trim()] = $Matches[1] } }
  foreach ($n in @('aghu.ear', 'dbaghu.dmp', 'wildfly-aghuse-overlay.tar.gz', 'wildfly-aghuse-removidos.txt')) {
    $orig = Join-Path $RAIZ "pacote\$n"
    $dest = Join-Path $pac $n
    if (Test-Path -LiteralPath $orig) { Copy-Item -LiteralPath $orig -Destination $dest }
    elseif (Test-Path -LiteralPath "$orig.parte-001") { info "juntando $n"; Juntar-Partes "$orig.parte-001" $dest }
    else { erro "arquivo ausente: pacote\$n" }
    Conferir $dest $somas[$n]
  }
  Copy-Item -LiteralPath (Join-Path $RAIZ 'pacote\SHA256SUMS') -Destination $pac
  info 'pacote conferido'

  # Variante nao oficial: troca o aghu.ear e identifica o pacote
  $defsVariante = @()
  $arqVar = Join-Path $BUILD 'VARIANTE'
  if (Test-Path -LiteralPath $arqVar) { Remove-Item -LiteralPath $arqVar -Force }
  if ($Variante) {
    etapa "Variante: $Variante"
    $earVar = Join-Path $Variante 'aghu.ear'
    $defVar = Join-Path $Variante 'VARIANTE'
    if (-not (Test-Path -LiteralPath $earVar) -or -not (Test-Path -LiteralPath $defVar)) { erro "a pasta da variante precisa ter aghu.ear e VARIANTE: $Variante" }
    $v = Ler-Conf $defVar
    if ($v['SHA256_AGHU_EAR']) { Conferir $earVar $v['SHA256_AGHU_EAR'] }
    Copy-Item -LiteralPath $earVar -Destination (Join-Path $pac 'aghu.ear') -Force
    $hashVar = (Get-FileHash -LiteralPath (Join-Path $pac 'aghu.ear') -Algorithm SHA256).Hash.ToLower()
    $linhas = [IO.File]::ReadAllLines((Join-Path $pac 'SHA256SUMS')) | ForEach-Object { if ($_ -match '\saghu\.ear$') { "$hashVar  aghu.ear" } else { $_ } }
    [IO.File]::WriteAllText((Join-Path $pac 'SHA256SUMS'), (($linhas -join "`n") + "`n"), $UTF8_SEM_BOM)
    Copy-Item -LiteralPath $defVar -Destination $arqVar -Force
    $defsVariante = @("/DVarianteNome=$($v['DESCRICAO'])", "/DVarianteSufixo=_variante-$($v['NOME'])-$($v['VERSAO'])")
    info "$($v['DESCRICAO']) (aghu.ear $($hashVar.Substring(0,12))...)"
  }

  etapa 'WildFly 26.1.3'
  $wfd = Join-Path $BUILD 'dependencias\wildfly'
  if (-not (Test-Path $wfd)) { New-Item -ItemType Directory -Path $wfd | Out-Null }
  $wz = Join-Path $wfd 'wildfly-26.1.3.Final.zip'
  if (-not (Test-Path -LiteralPath $wz)) { Juntar-Partes (Join-Path $RAIZ 'dependencias\wildfly\wildfly-26.1.3.Final.zip.parte-001') $wz }
  Conferir $wz $PADROES.WILDFLY_SHA256
  info 'WildFly conferido'

  foreach ($comp in @(@{ Nome = 'OpenJDK 17.0.2'; Url = $PADROES.JDK_URL; Sha = $PADROES.JDK_SHA256; Pasta = 'jdk-17.0.2'; Excluir = @() },
                      @{ Nome = 'PostgreSQL 15'; Url = $PADROES.PG_URL; Sha = $PADROES.PG_SHA256; Pasta = 'pgsql'; Excluir = @('pgsql/pgAdmin*', 'pgsql/StackBuilder*', 'pgsql/doc', 'pgsql/include', 'pgsql/symbols') })) {
    etapa $comp.Nome
    $zip = Join-Path $CACHE (Split-Path $comp.Url -Leaf)
    if (-not (Test-Path -LiteralPath $zip)) {
      info "baixando $($comp.Url)"
      [void](Invoke-Nativo curl.exe @('-fSL', '--retry', '3', '-o', "$zip.tmp", $comp.Url))
      Move-Item "$zip.tmp" $zip
    }
    Conferir $zip $comp.Sha
    $dest = Join-Path $BUILD $comp.Pasta
    if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
    $a = @('-xf', $zip, '-C', $BUILD)
    foreach ($x in $comp.Excluir) { $a += @('--exclude', $x) }
    [void](Invoke-Nativo $TAR $a)
    info "$($comp.Nome) extraido"
  }

  etapa 'Compilando o instalador (Inno Setup)'
  [void](Invoke-Nativo $Iscc (@("/DBuildDir=$BUILD", "/DOutDir=$SAIDA") + $defsVariante + @((Join-Path $PSScriptRoot 'aghuse.iss'))) -Mostrar)
  $exe = Get-ChildItem $SAIDA -Filter 'aghuse_setup_*.exe' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  Write-Host ''
  Write-Host "Instalador gerado: $($exe.FullName) ($([math]::Round($exe.Length / 1MB)) MB)" -ForegroundColor Green
  Write-Host "SHA-256: $((Get-FileHash $exe.FullName -Algorithm SHA256).Hash.ToLower())"
}
catch { Write-Host $_.Exception.Message -ForegroundColor Red; exit 1 }
