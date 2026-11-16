###############################################################################
#  AGHUse 13.250-STABLE - funcoes comuns aos scripts do Windows
#  Carregado pelos scripts com:  . "$PSScriptRoot\lib\comum.ps1"
#  (arquivo somente ASCII: o Windows PowerShell 5.1 le .ps1 sem BOM como ANSI)
###############################################################################
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
# Saida capturada pelo instalador grafico (ExecAndLogOutput le UTF-8): sem isto, mensagens do
# Windows com acento ("servico" com cedilha) chegam na pagina de codigo 850 e aparecem como "servi?o".
# So a escrita vai em UTF-8; [Console]::OutputEncoding continua na pagina do console (850),
# que e a usada para LER a saida dos programas do Windows (sc, icacls, psql).
try {
  if ([Console]::IsOutputRedirected) {
    $w = New-Object System.IO.StreamWriter([Console]::OpenStandardOutput(), (New-Object System.Text.UTF8Encoding($false)))
    $w.AutoFlush = $true
    [Console]::SetOut($w)
  }
} catch { }
# Avisos "Aguardando que o servico ... seja iniciado" do Start/Stop-Service: so ruido no progresso
$PSDefaultParameterValues['Start-Service:WarningAction'] = 'SilentlyContinue'
$PSDefaultParameterValues['Stop-Service:WarningAction'] = 'SilentlyContinue'
$PSDefaultParameterValues['Restart-Service:WarningAction'] = 'SilentlyContinue'

$VERSAO_AGHUSE = '13.250-STABLE'
$WILDFLY_NOME  = 'wildfly-26.1.3.Final'
$JDK_NOME      = 'jdk-17.0.2'
$DADOS_AGHUSE  = Join-Path $env:ProgramData 'AGHUse'     # equivalente a /etc/aghuse e /root
$UTF8_SEM_BOM  = New-Object System.Text.UTF8Encoding($false)
$ETAPA_ATUAL   = 'inicio'
# tar do proprio Windows (bsdtar): o tar do Git (GNU), se estiver antes no PATH, nao entende C:\...
$TAR = Join-Path $env:SystemRoot 'System32\tar.exe'
if (-not (Test-Path -LiteralPath $TAR)) { $TAR = 'tar.exe' }

# Contas de servico aceitas (CONTA_SERVICO) -> nome e SID (SIDs independem do idioma do Windows)
$CONTAS_SERVICO = @{
  'LocalService'   = @{ Nome = 'NT AUTHORITY\LocalService';   Sid = 'S-1-5-19' }
  'NetworkService' = @{ Nome = 'NT AUTHORITY\NetworkService'; Sid = 'S-1-5-20' }
  'LocalSystem'    = @{ Nome = 'LocalSystem';                 Sid = 'S-1-5-18' }
}
$SID_SYSTEM = 'S-1-5-18'; $SID_ADMINS = 'S-1-5-32-544'; $SID_USERS = 'S-1-5-32-545'; $SID_NETWORKSERVICE = 'S-1-5-20'

# Valores padrao de aghuse.conf (o arquivo sobrescreve)
$PADROES = [ordered]@{
  AMBIENTE = 'teste'; CONFIRMO_PRODUCAO = 'nao'; NOME_AMBIENTE = 'AGHUSE-TESTE'
  MODO_LOGIN = 'ldap-local'; ADMIN_LOGIN = 'AGHU'; ADMIN_SENHA = ''; LDAP_LOCAL_PORTA = '50389'
  LDAP_HOST = ''; LDAP_PORTA = '389'; LDAP_USER_DN = ''; LDAP_BASE_USUARIOS = ''
  LDAP_ATRIBUTO_LOGIN = ''; LDAP_FILTRO = ''; LDAP_BIND_DN = ''; LDAP_BIND_SENHA = ''
  PG_PORTA = ''; PG_SENHA_POSTGRES = ''
  DB_NOME = 'dbaghu'; DB_USUARIO = 'ugen_aghu'; DB_SENHA = ''; DB_USUARIO_FIT = 'ugen_aghu_fit'; DB_SENHA_FIT = ''
  RECRIAR_BANCO = 'nao'
  PREFIXO = 'C:\AGHUse'; SERVICO = 'aghuse'; CONTA_SERVICO = 'LocalService'
  HTTP_BIND = '0.0.0.0'; PROXY_REVERSO = 'nao'; PORT_OFFSET = '0'; MEMORIA_JVM = ''
  FUSO_HORARIO = 'America/Sao_Paulo'; SMTP_HOST = '127.0.0.1'; LIBERAR_FIREWALL = 'sim'
  JDK_URL = 'https://download.java.net/java/GA/jdk17.0.2/dfd4a8d0985749f896bed50d7138ee7f/8/GPL/openjdk-17.0.2_windows-x64_bin.zip'
  JDK_SHA256 = 'b2208206bda47f2e0c971a39e057a5ec32c40b503d71e486790cb728d926b615'
  WILDFLY_URL = 'https://github.com/wildfly/wildfly/releases/download/26.1.3.Final/wildfly-26.1.3.Final.zip'
  WILDFLY_SHA256 = 'dd615f2d0d9864683fd45827dd78a3e7fed2b0ee84e1a758ad571fc6edb37ebc'
  PG_URL = 'https://get.enterprisedb.com/postgresql/postgresql-15.20-1-windows-x64-binaries.zip'
  PG_SHA256 = '6fbe06a1c3d63494baa7a76ad6426968fa5b6cfdd37fbfd5c2febd3be748eb09'
}

# ----------------------------------------------------------------------------
# mensagens
# ----------------------------------------------------------------------------
function etapa([string]$t) { $script:ETAPA_ATUAL = $t; Write-Host ''; Write-Host "==> $t" -ForegroundColor Cyan }
function info([string]$t)  { Write-Host "    $t" }
function aviso([string]$t) { Write-Host "    AVISO: $t" -ForegroundColor Yellow }
function erro([string]$t)  { throw (New-Object System.Exception("ERRO: $t")) }

function Exigir-Admin([string]$Comando) {
  $p = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
  if (-not $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    erro "execute como Administrador (clique com o botao direito em $Comando > Executar como administrador)."
  }
}

# ----------------------------------------------------------------------------
# aghuse.conf: mesmo formato do instalador Linux (NOME="valor"  # comentario)
# ----------------------------------------------------------------------------
function Ler-Conf([string]$Arquivo) {
  if (-not (Test-Path -LiteralPath $Arquivo -PathType Leaf)) { erro "arquivo de parametros nao encontrado: $Arquivo" }
  $c = [ordered]@{}
  foreach ($k in $PADROES.Keys) { $c[$k] = $PADROES[$k] }
  $n = 0
  foreach ($linha in [IO.File]::ReadAllLines($Arquivo)) {
    $n++
    $l = $linha.Trim()
    if ($l -eq '' -or $l.StartsWith('#')) { continue }
    if ($l -notmatch '^([A-Za-z_][A-Za-z0-9_]*)=(.*)$') { erro "linha $n invalida em ${Arquivo}: $linha" }
    $nome = $Matches[1]; $resto = $Matches[2]
    if ($resto -match '^"([^"]*)"') { $valor = $Matches[1] }
    elseif ($resto -match "^'([^']*)'") { $valor = $Matches[1] }
    else { $valor = ($resto -split '\s', 2)[0] }
    $c[$nome] = $valor
  }
  return $c
}

# ----------------------------------------------------------------------------
# senhas
# ----------------------------------------------------------------------------
function Gerar-Senha([int]$Tamanho = 32) {  # [A-Za-z0-9] com gerador criptografico
  $alfabeto = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'
  $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
  $b = New-Object byte[] 1
  $s = New-Object System.Text.StringBuilder
  while ($s.Length -lt $Tamanho) {
    $rng.GetBytes($b)
    if ($b[0] -lt 248) { [void]$s.Append($alfabeto[$b[0] % 62]) }   # 248 = 4*62: sem vies
  }
  return $s.ToString()
}

# ----------------------------------------------------------------------------
# execucao de programas externos (codigo de saida conferido; stderr nao vira excecao)
# ----------------------------------------------------------------------------
function Invoke-Nativo {
  param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string[]]$Argumentos = @(),
    [switch]$Mostrar,          # exibe a saida (e grava no log)
    [switch]$PermitirFalha,    # nao interrompe com codigo de saida diferente de 0
    [string]$MensagemErro = ''
  )
  $eap = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    $saida = @(& $Exe @Argumentos 2>&1 | ForEach-Object { "$_" })
    $codigo = $LASTEXITCODE
  } finally { $ErrorActionPreference = $eap }
  if ($null -eq $codigo) { $codigo = 0 }
  $script:ULTIMO_CODIGO = $codigo
  if ($Mostrar) { foreach ($l in $saida) { info $l } }
  if ($codigo -ne 0 -and -not $PermitirFalha) {
    if (-not $Mostrar) { foreach ($l in ($saida | Select-Object -Last 20)) { Write-Host "    $l" } }
    if (-not $MensagemErro) { $MensagemErro = "comando falhou (codigo $codigo): $(Split-Path $Exe -Leaf) $($Argumentos -join ' ')" }
    erro $MensagemErro
  }
  return , $saida
}

function Novo-DirTemp {
  $d = Join-Path ([IO.Path]::GetTempPath()) ('aghuse-' + [guid]::NewGuid().ToString('N').Substring(0, 10))
  New-Item -ItemType Directory -Path $d -Force | Out-Null
  return $d
}

function Gravar-Texto([string]$Arquivo, [string]$Texto) { [IO.File]::WriteAllText($Arquivo, $Texto, $UTF8_SEM_BOM) }

# Remove uma pasta mesmo com caminhos acima de 260 caracteres (a aplicacao descompactada
# em standalone\tmp passa desse limite e o Remove-Item do PowerShell 5.1 falha)
function Remover-Pasta([string]$Pasta) {
  if (-not (Test-Path -LiteralPath $Pasta)) { return }
  $vazia = Join-Path ([IO.Path]::GetTempPath()) ('aghuse-vazia-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
  New-Item -ItemType Directory -Path $vazia -Force | Out-Null
  try {
    [void](Invoke-Nativo robocopy.exe @($vazia, $Pasta, '/MIR', '/R:2', '/W:2', '/NFL', '/NDL', '/NJH', '/NJS', '/NP') -PermitirFalha)
    if ($ULTIMO_CODIGO -ge 8) { erro "falha ao apagar $Pasta (robocopy codigo $ULTIMO_CODIGO). Verifique se algum programa esta usando os arquivos." }
    Remove-Item -LiteralPath $Pasta -Recurse -Force
  } finally { Remove-Item -LiteralPath $vazia -Force -ErrorAction SilentlyContinue }
}

# Pasta de dados protegida (somente SYSTEM e Administradores): credenciais e senhas
function Preparar-PastaProtegida([string]$Pasta) {
  if (-not (Test-Path -LiteralPath $Pasta)) { New-Item -ItemType Directory -Path $Pasta -Force | Out-Null }
  [void](Invoke-Nativo icacls.exe @($Pasta, '/inheritance:r', '/grant:r', "*${SID_SYSTEM}:(OI)(CI)F", "*${SID_ADMINS}:(OI)(CI)F") -MensagemErro "falha ao proteger a pasta $Pasta")
}

# ----------------------------------------------------------------------------
# rede
# ----------------------------------------------------------------------------
function Porta-EmUso([int]$Porta) {
  $l = [Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties().GetActiveTcpListeners()
  return [bool]($l | Where-Object { $_.Port -eq $Porta } | Select-Object -First 1)
}

function Testar-Tcp([string]$Servidor, [int]$Porta, [int]$Ms = 5000) {
  $c = New-Object Net.Sockets.TcpClient
  try {
    $r = $c.BeginConnect($Servidor, $Porta, $null, $null)
    if (-not $r.AsyncWaitHandle.WaitOne($Ms)) { return $false }
    $c.EndConnect($r); return $true
  } catch { return $false } finally { $c.Close() }
}

function Obter-Pagina([string]$Url) {  # sem proxy do sistema (acesso local)
  $wc = New-Object Net.WebClient
  $wc.Proxy = $null
  $wc.Encoding = [Text.Encoding]::UTF8
  try { return $wc.DownloadString($Url) } catch { return '' } finally { $wc.Dispose() }
}

function Ip-Principal {
  try {
    $ip = Get-NetIPConfiguration -ErrorAction Stop | Where-Object { $_.IPv4DefaultGateway } |
          ForEach-Object { $_.IPv4Address.IPAddress } | Select-Object -First 1
    if ($ip) { return $ip }
  } catch { }
  $ip = [Net.Dns]::GetHostAddresses([Net.Dns]::GetHostName()) |
        Where-Object { $_.AddressFamily -eq 'InterNetwork' -and -not $_.ToString().StartsWith('127.') -and -not $_.ToString().StartsWith('169.254.') } |
        Select-Object -First 1
  if ($ip) { return $ip.ToString() }
  return '127.0.0.1'
}

# ----------------------------------------------------------------------------
# PostgreSQL privativo do AGHUse (<PREFIXO>\pgsql + <PREFIXO>\pgdata, servico <SERVICO>-postgresql)
# ----------------------------------------------------------------------------
function Porta-PgDados([string]$PgData) {  # ultima linha "port = N" ativa do postgresql.conf
  $porta = ''
  foreach ($arq in @((Join-Path $PgData 'postgresql.conf'), (Join-Path $PgData 'postgresql.auto.conf'))) {
    if (Test-Path -LiteralPath $arq) {
      foreach ($l in [IO.File]::ReadAllLines($arq)) {
        if ($l -match '^\s*port\s*=\s*''?(\d+)') { $porta = $Matches[1] }
      }
    }
  }
  if (-not $porta) { $porta = '5432' }
  return $porta
}

function Arquivo-SenhaPostgres([string]$Servico) { return (Join-Path $DADOS_AGHUSE "pg-postgres-$Servico.senha") }

# psql como superusuario postgres. -Valor: retorna as linhas sem formatacao (-At)
function Psql {
  param([Parameter(Mandatory = $true)][string]$Sql, [string]$Banco = 'postgres', [switch]$Valor)
  $f = Join-Path $TMPD ('sql-' + [guid]::NewGuid().ToString('N') + '.sql')
  Gravar-Texto $f $Sql
  try {
    $a = @('-X', '-q', '-v', 'ON_ERROR_STOP=1', '-h', '127.0.0.1', '-p', "$PG_PORTA", '-U', 'postgres', '-d', $Banco, '-f', $f)
    if ($Valor) { $a = @('-A', '-t') + $a }
    $r = Invoke-Nativo (Join-Path $PG_BIN 'psql.exe') $a -MensagemErro 'falha ao executar comando SQL no PostgreSQL.'
    return , @($r | Where-Object { $_ -ne '' })
  } finally { Remove-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue }
}
