# Verifica o estado de uma instalacao do AGHUse no Windows.  Uso (Administrador): verificar.bat [-Conf arquivo.conf]
param([string]$Conf = '')
. (Join-Path $PSScriptRoot 'lib\comum.ps1')
. (Join-Path $PSScriptRoot 'lib\ldaplocal.ps1')
if (-not $Conf) { $Conf = Join-Path $PSScriptRoot 'aghuse.conf' }
$ST = 0
$TMPD = $null
function chk([string]$Rotulo, [scriptblock]$Teste) {
  $ok = $false
  try { $ok = [bool](& $Teste) } catch { $ok = $false }
  if ($ok) { Write-Host '  [' -NoNewline; Write-Host 'OK' -ForegroundColor Green -NoNewline; Write-Host "] $Rotulo" }
  else { Write-Host '  [' -NoNewline; Write-Host 'FALHA' -ForegroundColor Red -NoNewline; Write-Host "] $Rotulo"; $script:ST = 1 }
}
try {
  Exigir-Admin 'verificar.bat'
  $C = Ler-Conf $Conf
  foreach ($k in $C.Keys) { Set-Variable -Name $k -Value $C[$k] }
  $PREFIXO = $PREFIXO.TrimEnd('\')
  $WFD = Join-Path $PREFIXO $WILDFLY_NOME
  $PG_BIN = Join-Path $PREFIXO 'pgsql\bin'
  $PG_PORTA = Porta-PgDados (Join-Path $PREFIXO 'pgdata')
  $PH = 8080 + [int]$PORT_OFFSET
  $PG_SERVICO = "$SERVICO-postgresql"
  $arq = Arquivo-SenhaPostgres $SERVICO
  if (Test-Path -LiteralPath $arq) { $env:PGPASSWORD = ([IO.File]::ReadAllText($arq)).Trim() }
  $TMPD = Novo-DirTemp

  Write-Host "AGHUse - verificacao ($SERVICO, login: $MODO_LOGIN)"
  chk "Java instalado ($PREFIXO\$JDK_NOME)" { Test-Path (Join-Path $PREFIXO "$JDK_NOME\bin\java.exe") }
  chk "PostgreSQL 15 ativo (servico $PG_SERVICO, porta $PG_PORTA)" { (Get-Service $PG_SERVICO).Status -eq 'Running' }
  chk "Banco $DB_NOME existente" { ((Psql -Valor -Sql "select 1 from pg_database where datname='$DB_NOME'") -join '') -eq '1' }
  if ($MODO_LOGIN -eq 'ldap-local') {
    $ADAM = LdapLocal-Servico $SERVICO
    $pr = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\$ADAM\Parameters" -ErrorAction SilentlyContinue
    $LP = $LDAP_LOCAL_PORTA; if ($pr -and $pr.PSObject.Properties['Port LDAP']) { $LP = $pr.'Port LDAP' }
    chk "LDAP local ativo (AD LDS, servico $ADAM, porta $LP)" { (Get-Service $ADAM).Status -eq 'Running' -and (Testar-Tcp '127.0.0.1' ([int]$LP)) }
  }
  chk "Servico $SERVICO ativo" { (Get-Service $SERVICO).Status -eq 'Running' }
  chk 'Aplicacao implantada (aghu.ear.deployed)' { Test-Path (Join-Path $WFD 'standalone\deployments\aghu.ear.deployed') }
  $h = $HTTP_BIND; if ($h -eq '0.0.0.0') { $h = '127.0.0.1' }
  $PAG = Obter-Pagina "http://${h}:$PH/aghu/pages/casca/casca.xhtml"
  chk "Tela de login respondendo na porta $PH" { $PAG -match 'formLogin' }
  if ($PAG -cmatch 'Vers[^<]*') { Write-Host "  $($Matches[0] -replace '\s+', ' ')" }
  $log = Join-Path $WFD 'standalone\log\server.log'
  $n = 0; if (Test-Path $log) { $n = @(Select-String -LiteralPath $log -Pattern ' ERROR ' -SimpleMatch).Count }
  Write-Host "  Linhas de ERROR no server.log atual: $n"
}
catch { Write-Host $_.Exception.Message -ForegroundColor Red; $ST = 1 }
finally {
  Remove-Item Env:\PGPASSWORD -ErrorAction SilentlyContinue
  if ($TMPD -and (Test-Path -LiteralPath $TMPD)) { Remove-Item -LiteralPath $TMPD -Recurse -Force -ErrorAction SilentlyContinue }
}
exit $ST
