###############################################################################
#  AGHUse - LDAP local no Windows (MODO_LOGIN="ldap-local")
#  Carregado depois de comum.ps1:  . "$PSScriptRoot\lib\ldaplocal.ps1"
#
#  Usa o AD LDS (Active Directory Lightweight Directory Services), componente
#  gratuito do proprio Windows, equivalente ao OpenLDAP do instalador Linux:
#    - instancia <SERVICO>ldap (servico do Windows ADAM_<SERVICO>ldap), porta 50389
#    - particao DC=aghuse,DC=local; contas em OU=people; conta de servico
#      (somente leitura) em OU=servicos
#    - login do AGHUse: bind simples com CN=<login>,OU=people,DC=aghuse,DC=local
#  O diretorio so atende este computador: as regras de entrada do firewall
#  criadas pelo AD LDS sao desativadas, porque as senhas trafegam sem TLS
#  (dSHeuristics permite troca de senha sem SSL, como no OpenLDAP local).
#  (arquivo somente ASCII: o Windows PowerShell 5.1 le .ps1 sem BOM como ANSI)
###############################################################################
Add-Type -AssemblyName System.DirectoryServices.Protocols
$LDP = 'System.DirectoryServices.Protocols'
$LDAP_LOCAL_PARTICAO = 'DC=aghuse,DC=local'
$LDAP_LOCAL_PESSOAS  = "OU=people,$LDAP_LOCAL_PARTICAO"
$LDAP_LOCAL_SERVICOS = "OU=servicos,$LDAP_LOCAL_PARTICAO"
$LDAP_LOCAL_LEITURA  = "CN=aghuse-leitura,$LDAP_LOCAL_SERVICOS"
$ADAM_DIR = Join-Path $env:windir 'ADAM'

# Instancia "<SERVICO>ldap": o AD LDS registra o servico ADAM_<instancia> com NOME DE EXIBICAO igual
# ao nome da instancia. Com a instancia "aghuse", Get-Service -Name aghuse devolvia o servico do LDAP
# em vez do WildFly, e o instalador esperava 15 minutos por um WildFly que nunca foi iniciado.
function LdapLocal-Instancia([string]$Servico) { return (($Servico -replace '[^A-Za-z0-9]', '') + 'ldap') }
function LdapLocal-Servico([string]$Servico) { return 'ADAM_' + (LdapLocal-Instancia $Servico) }
function LdapLocal-ArquivoSenha([string]$Servico) { return (Join-Path $DADOS_AGHUSE "ldap-local-$Servico.senha") }
function LdapLocal-DnUsuario([string]$Login) { return "CN=$Login,$LDAP_LOCAL_PESSOAS" }

# Senha que satisfaz a politica de complexidade do Windows (maiuscula, minuscula e numero)
function Gerar-SenhaForte([int]$Tamanho = 12) {
  do { $s = Gerar-Senha $Tamanho } while ($s -cnotmatch '[A-Z]' -or $s -cnotmatch '[a-z]' -or $s -notmatch '[0-9]')
  return $s
}

# ----------------------------------------------------------------------------
# componente do Windows e instancia
# ----------------------------------------------------------------------------
function LdapLocal-HabilitarRecurso {
  if (Test-Path -LiteralPath (Join-Path $ADAM_DIR 'adaminstall.exe')) { return }
  $so = Get-CimInstance Win32_OperatingSystem
  if ($so.ProductType -eq 1) {
    info 'habilitando o recurso do Windows "Active Directory Lightweight Directory Services" ...'
    $r = Enable-WindowsOptionalFeature -Online -FeatureName DirectoryServices-ADAM-Client -All -NoRestart
  } else {
    info 'instalando a funcao do Windows Server "AD LDS" ...'
    Import-Module ServerManager
    $r = Install-WindowsFeature ADLDS
  }
  if (-not (Test-Path -LiteralPath (Join-Path $ADAM_DIR 'adaminstall.exe'))) {
    erro 'nao foi possivel habilitar o AD LDS (recurso do Windows). Habilite em "Ativar ou desativar recursos do Windows" > "Active Directory Lightweight Directory Services" e execute novamente.'
  }
}

function LdapLocal-CriarInstancia([string]$Instancia, [int]$Porta, [int]$PortaSsl, [string]$Pasta, [string]$Temp) {
  if (Porta-EmUso $Porta) { erro "a porta $Porta (LDAP_LOCAL_PORTA) ja esta em uso." }
  if (Porta-EmUso $PortaSsl) { erro "a porta $PortaSsl (LDAP local com SSL) ja esta em uso." }
  $dados = Join-Path $Pasta 'data'; $logs = Join-Path $Pasta 'logs'
  if (Test-Path -LiteralPath $Pasta) { Remover-Pasta $Pasta }
  New-Item -ItemType Directory -Path $dados, $logs -Force | Out-Null
  [void](Invoke-Nativo icacls.exe @($Pasta, '/inheritance:r', '/grant:r', "*${SID_SYSTEM}:(OI)(CI)F", "*${SID_ADMINS}:(OI)(CI)F", "*${SID_NETWORKSERVICE}:(OI)(CI)F"))
  # Sem "Administrator=": o administrador da instancia e quem instala (o grupo
  # Administradores e adicionado depois, por SID). Com um grupo aqui o adaminstall
  # recusa a importacao dos LDF (codigo 20085).
  $resp = Join-Path $Temp 'adlds-resposta.txt'
  $txt = @(
    '[ADAMInstall]', 'InstallType=Unique', "InstanceName=$Instancia",
    "LocalLDAPPortToListenOn=$Porta", "LocalSSLPortToListenOn=$PortaSsl",
    "NewApplicationPartitionToCreate=$LDAP_LOCAL_PARTICAO",
    "DataFilesPath=$dados", "LogFilesPath=$logs",
    'ImportLDIFFiles="MS-InetOrgPerson.LDF" "MS-User.LDF" "MS-UserProxy.LDF"'
  ) -join "`r`n"
  [IO.File]::WriteAllText($resp, $txt + "`r`n", [Text.Encoding]::ASCII)
  info "criando a instancia $Instancia do AD LDS (porta $Porta; leva de 2 a 5 minutos) ..."
  $p = Start-Process -FilePath (Join-Path $ADAM_DIR 'adaminstall.exe') -ArgumentList "/answer:`"$resp`"" -PassThru -WindowStyle Hidden
  # limite de 20 min: uma caixa de mensagem do instalador do AD LDS deixaria o processo esperando um clique
  if (-not $p.WaitForExit(1200000)) {
    Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
    erro "a criacao da instancia do AD LDS nao terminou em 20 minutos. Veja $env:windir\Debug\adamsetup.log"
  }
  Remove-Item -LiteralPath $resp -Force -ErrorAction SilentlyContinue
  if ($p.ExitCode -ne 0) {
    $msg = ''
    try { $msg = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\ADAM_Installer_Results' -ErrorAction Stop).ADAMInstallErrorMessage } catch { }
    erro "falha ao criar a instancia do AD LDS (codigo $($p.ExitCode)). $msg Veja $env:windir\Debug\adamsetup.log"
  }
}

# Somente este computador: desativa as regras de ENTRADA que o AD LDS cria no firewall
function LdapLocal-BloquearRede([string]$Instancia) {
  Get-NetFirewallRule -Direction Inbound -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -like "*($Instancia)*" -and $_.Enabled -eq 'True' } |
    ForEach-Object { Disable-NetFirewallRule -Name $_.Name -ErrorAction SilentlyContinue }
}

# ----------------------------------------------------------------------------
# operacoes LDAP (System.DirectoryServices.Protocols)
# ----------------------------------------------------------------------------
# Sem Dn: autentica como o usuario do Windows (administrador da instancia)
function Ldap-Conectar([int]$Porta, [string]$Dn = '', [string]$Senha = '') {
  $c = New-Object "$LDP.LdapConnection" (New-Object "$LDP.LdapDirectoryIdentifier" ('127.0.0.1', $Porta))
  $c.SessionOptions.ProtocolVersion = 3
  $c.Timeout = [TimeSpan]::FromSeconds(30)
  if ($Dn) { $c.AuthType = 'Basic'; $c.Credential = New-Object System.Net.NetworkCredential($Dn, $Senha) }
  else { $c.AuthType = 'Negotiate' }
  $c.Bind()
  return $c
}

function Ldap-Testar([int]$Porta, [string]$Dn, [string]$Senha) {
  try { $c = Ldap-Conectar $Porta $Dn $Senha; $c.Dispose(); return $true } catch { return $false }
}

function Ldap-Erro($Excecao) {   # texto do servidor LDAP, quando houver
  $e = $Excecao
  while ($e -and -not ($e -is [System.DirectoryServices.Protocols.DirectoryOperationException]) -and $e.InnerException) { $e = $e.InnerException }
  if ($e -is [System.DirectoryServices.Protocols.DirectoryOperationException]) { return "$($e.Message) $($e.Response.ErrorMessage)".Trim() }
  return $Excecao.Message
}

function Ldap-SenhaUnicode([string]$Senha) { return , ([Text.Encoding]::Unicode.GetBytes('"' + $Senha + '"')) }

function Ldap-Enviar($Conexao, $Requisicao, [string]$Descricao) {
  try { return $Conexao.SendRequest($Requisicao) }
  catch { erro "$Descricao`: $(Ldap-Erro $_.Exception)" }
}

function Ldap-Existe($Conexao, [string]$Dn) {
  try {
    $r = New-Object "$LDP.SearchRequest" ($Dn, '(objectClass=*)', [System.DirectoryServices.Protocols.SearchScope]::Base, [string[]]@('cn'))
    [void]$Conexao.SendRequest($r); return $true
  } catch { return $false }
}

# Atributos: hashtable nome -> string, string[] ou byte[]
function Ldap-Adicionar($Conexao, [string]$Dn, [hashtable]$Atributos) {
  $r = New-Object "$LDP.AddRequest"; $r.DistinguishedName = $Dn
  foreach ($k in $Atributos.Keys) {
    $a = New-Object "$LDP.DirectoryAttribute"; $a.Name = $k; $v = $Atributos[$k]
    if ($v -is [byte[]]) { [void]$a.Add([byte[]]$v) } else { foreach ($x in @($v)) { [void]$a.Add([string]$x) } }
    [void]$r.Attributes.Add($a)
  }
  [void](Ldap-Enviar $Conexao $r "falha ao criar $Dn")
}

function Ldap-Alterar($Conexao, [string]$Dn, [string]$Operacao, [string]$Atributo, $Valor, [switch]$IgnorarExistente) {
  $m = New-Object "$LDP.DirectoryAttributeModification"; $m.Name = $Atributo; $m.Operation = $Operacao
  if ($Valor -is [byte[]]) { [void]$m.Add([byte[]]$Valor) } else { [void]$m.Add([string]$Valor) }
  $r = New-Object "$LDP.ModifyRequest"; $r.DistinguishedName = $Dn; [void]$r.Modifications.Add($m)
  try { [void]$Conexao.SendRequest($r) }
  catch {
    $t = Ldap-Erro $_.Exception
    if ($IgnorarExistente -and ($t -match 'ATT_OR_VALUE_EXISTS|00002083|atributo existe|attribute.*exists')) { return }
    erro "falha ao alterar $Atributo de ${Dn}: $t"
  }
}

function Ldap-Excluir($Conexao, [string]$Dn) {
  $r = New-Object "$LDP.DeleteRequest" ($Dn)
  [void](Ldap-Enviar $Conexao $r "falha ao remover $Dn")
}

function Ldap-Buscar($Conexao, [string]$Base, [string]$Filtro, [string[]]$Atributos) {
  $r = New-Object "$LDP.SearchRequest" ($Base, $Filtro, [System.DirectoryServices.Protocols.SearchScope]::Subtree, $Atributos)
  return , @((Ldap-Enviar $Conexao $r "falha na busca em $Base").Entries)
}

function Ldap-Valor($Entrada, [string]$Atributo) {
  $a = $Entrada.Attributes[$Atributo.ToLower()]
  if ($null -eq $a -or $a.Count -eq 0) { return '' }
  return [string]$a[0]
}

function Ldap-DefinirSenha($Conexao, [string]$Dn, [string]$Senha) {
  Ldap-Alterar $Conexao $Dn 'Replace' 'unicodePwd' (Ldap-SenhaUnicode $Senha)
}

# Papel Readers da particao: permite buscar contas (Importar Usuario e troca de senha)
function Ldap-AdicionarLeitor($Conexao, [string]$Dn) {
  Ldap-Alterar $Conexao "CN=Readers,CN=Roles,$LDAP_LOCAL_PARTICAO" 'Add' 'member' $Dn -IgnorarExistente
}

# Cria a conta de acesso de uma pessoa (inetOrgPerson), habilitada e com leitura do diretorio
function Ldap-CriarUsuario($Conexao, [string]$Login, [string]$Senha, [string]$Nome = '', [string]$Email = '') {
  $dn = LdapLocal-DnUsuario $Login
  if (-not $Nome) { $Nome = $Login }
  $at = @{
    objectClass = 'inetOrgPerson'; uid = $Login; displayName = $Nome; sn = $Login
    userPrincipalName = "$Login@aghuse.local"
    unicodePwd = (Ldap-SenhaUnicode $Senha); 'msDS-UserAccountDisabled' = 'FALSE'
  }
  if ($Email) { $at['mail'] = $Email }
  Ldap-Adicionar $Conexao $dn $at
  Ldap-AdicionarLeitor $Conexao $dn
  return $dn
}

# Configuracao inicial da particao (idempotente)
function LdapLocal-PrepararDiretorio($Conexao) {
  $r = New-Object "$LDP.SearchRequest" ('', '(objectClass=*)', [System.DirectoryServices.Protocols.SearchScope]::Base, [string[]]@('configurationNamingContext'))
  $cfg = Ldap-Valor ((Ldap-Enviar $Conexao $r 'falha ao ler o RootDSE').Entries[0]) 'configurationNamingContext'
  # troca de senha sem SSL (o diretorio so atende este computador)
  Ldap-Alterar $Conexao "CN=Directory Service,CN=Windows NT,CN=Services,$cfg" 'Replace' 'dSHeuristics' '0000000001001'
  # qualquer Administrador do Windows administra a instancia (nao so quem instalou)
  Ldap-Alterar $Conexao "CN=Administrators,CN=Roles,$cfg" 'Add' 'member' "<SID=$SID_ADMINS>" -IgnorarExistente
  foreach ($ou in @($LDAP_LOCAL_PESSOAS, $LDAP_LOCAL_SERVICOS)) {
    if (-not (Ldap-Existe $Conexao $ou)) { Ldap-Adicionar $Conexao $ou @{ objectClass = 'organizationalUnit' } }
  }
}
