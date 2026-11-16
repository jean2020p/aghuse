###############################################################################
#  AGHUse - remocao da instalacao no Windows
#  Uso (Administrador): desinstalar.bat [-ManterBanco] [-Sim] [-Conf arquivo.conf]
#    -ManterBanco  mantem o PostgreSQL (servico, binarios e dados em <PREFIXO>\pgdata)
#                  e o LDAP local (AD LDS, servico ADAM_<SERVICO>ldap, contas de acesso)
#    -Sim          nao pede confirmacao
#  Remove: servico do WildFly, WildFly, Java, regra de firewall e credenciais.
###############################################################################
param([switch]$ManterBanco, [switch]$Sim, [string]$Conf = '')
. (Join-Path $PSScriptRoot 'lib\comum.ps1')
. (Join-Path $PSScriptRoot 'lib\ldaplocal.ps1')
if (-not $Conf) { $Conf = Join-Path $PSScriptRoot 'aghuse.conf' }
$codigo = 0
try {
  Exigir-Admin 'desinstalar.bat'
  $C = Ler-Conf $Conf
  foreach ($k in $C.Keys) { Set-Variable -Name $k -Value $C[$k] }
  $PREFIXO = $PREFIXO.TrimEnd('\')
  if ($PREFIXO -notmatch '^[A-Za-z]:\\[A-Za-z0-9_.\\-]+$') { erro "PREFIXO invalido: $PREFIXO" }
  $WFD = Join-Path $PREFIXO $WILDFLY_NOME
  $PG_SERVICO = "$SERVICO-postgresql"

  if (-not $Sim) {
    Write-Host "Sera removida a instalacao do AGHUse em $PREFIXO (servico $SERVICO)." -ForegroundColor Yellow
    if (-not $ManterBanco) { Write-Host "O BANCO DE DADOS ($PREFIXO\pgdata) TAMBEM SERA APAGADO." -ForegroundColor Red }
    $r = Read-Host "Digite REMOVER para confirmar"
    if ($r -cne 'REMOVER') { Write-Host 'Cancelado.'; exit 1 }
  }

  if (Get-Service -Name $SERVICO -ErrorAction SilentlyContinue) {
    Stop-Service -Name $SERVICO -Force -NoWait -ErrorAction SilentlyContinue
    for ($i = 0; $i -lt 90 -and (Get-Service -Name $SERVICO).Status -ne 'Stopped'; $i++) { Start-Sleep -Seconds 2 }
    [void](Invoke-Nativo sc.exe @('delete', $SERVICO) -PermitirFalha)
    Write-Host "servico $SERVICO removido"
  }
  Get-CimInstance Win32_Process -Filter "Name='java.exe'" | Where-Object { $_.CommandLine -and $_.CommandLine -like "*$WFD*" } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
  # parametros do Procrun no registro
  foreach ($ch in @("HKLM:\SOFTWARE\WOW6432Node\Apache Software Foundation\Procrun 2.0\$SERVICO", "HKLM:\SOFTWARE\Apache Software Foundation\Procrun 2.0\$SERVICO")) {
    if (Test-Path $ch) { Remove-Item $ch -Recurse -Force }
  }
  Get-NetFirewallRule -DisplayName "AGHUse ($SERVICO) HTTP" -ErrorAction SilentlyContinue | Remove-NetFirewallRule
  foreach ($d in @($WFD, (Join-Path $PREFIXO $JDK_NOME), (Join-Path $PREFIXO 'backup'))) {
    if (Test-Path -LiteralPath $d) { Remover-Pasta $d; Write-Host "removido $d" }
  }
  if (-not $ManterBanco) {
    if (Get-Service -Name $PG_SERVICO -ErrorAction SilentlyContinue) {
      Stop-Service -Name $PG_SERVICO -Force -ErrorAction SilentlyContinue
      [void](Invoke-Nativo sc.exe @('delete', $PG_SERVICO) -PermitirFalha)
      Write-Host "servico $PG_SERVICO removido"
    }
    Get-Process postgres -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "$PREFIXO\*" } | Stop-Process -Force -ErrorAction SilentlyContinue
    foreach ($d in @((Join-Path $PREFIXO 'pgdata'), (Join-Path $PREFIXO 'pgsql'))) {
      if (Test-Path -LiteralPath $d) { Remover-Pasta $d; Write-Host "removido $d" }
    }
    Remove-Item -LiteralPath (Arquivo-SenhaPostgres $SERVICO) -Force -ErrorAction SilentlyContinue
    # LDAP local (AD LDS): instancia e contas de acesso
    if (Get-Service -Name (LdapLocal-Servico $SERVICO) -ErrorAction SilentlyContinue) {
      $un = Join-Path $env:windir 'ADAM\adamuninstall.exe'
      if (Test-Path -LiteralPath $un) {
        # /q: sem a caixa "remocao bem-sucedida" (sem ela o processo espera um clique para sempre)
        $p = Start-Process -FilePath $un -ArgumentList "/i:$(LdapLocal-Instancia $SERVICO)", '/q', '/force' -PassThru -WindowStyle Hidden
        if (-not $p.WaitForExit(600000)) { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue }
        if (Get-Service -Name (LdapLocal-Servico $SERVICO) -ErrorAction SilentlyContinue) { Write-Host "AVISO: a instancia $SERVICO do AD LDS nao foi removida" -ForegroundColor Yellow }
        else { Write-Host "LDAP local (AD LDS, instancia $(LdapLocal-Instancia $SERVICO)) removido" }
      }
    }
    $adl = Join-Path $PREFIXO 'adlds'
    if (Test-Path -LiteralPath $adl) { Remover-Pasta $adl; Write-Host "removido $adl" }
    Remove-Item -LiteralPath (Join-Path $DADOS_AGHUSE "ldap-local-$SERVICO.senha") -Force -ErrorAction SilentlyContinue
  } else { Write-Host "PostgreSQL e LDAP local mantidos (servicos $PG_SERVICO e $(LdapLocal-Servico $SERVICO); dados em $PREFIXO\pgdata e $PREFIXO\adlds)" }
  Remove-Item -LiteralPath (Join-Path $DADOS_AGHUSE "aghuse-credenciais-$SERVICO.txt") -Force -ErrorAction SilentlyContinue
  if (-not $ManterBanco) {
    # remocao completa: tambem logs, registros de aceite e senhas guardadas (C:\ProgramData\AGHUse)
    if (Test-Path -LiteralPath $DADOS_AGHUSE) { Remover-Pasta $DADOS_AGHUSE; Write-Host "removido $DADOS_AGHUSE" }
  }
  Write-Host 'AGHUse removido.' -ForegroundColor Green
}
catch { Write-Host $_.Exception.Message -ForegroundColor Red; $codigo = 1 }
exit $codigo
