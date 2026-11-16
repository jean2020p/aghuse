###############################################################################
#  Instalador AGHUse 13.250-STABLE para Windows (motor do instalador grafico)
#  Uso (PowerShell como Administrador):
#     .\instalar.ps1 [-Conf aghuse.conf] [-Pacote <pasta com pacote\ e dependencias\>] [-NaoInterativo]
#
#  Mesma logica do instalar.sh (Linux): OpenJDK 17, WildFly 26.1.3, PostgreSQL 15,
#  base inicial do AGHUse, autenticacao (LDAP local com AD LDS, LDAP/AD externo ou banco) e servicos do
#  Windows. Distribuido para fins de TESTE e ESTUDO, sem garantia e sem suporte.
###############################################################################
param(
  [string]$Conf = '',
  [string]$Pacote = '',
  [switch]$NaoInterativo
)
. (Join-Path $PSScriptRoot 'lib\comum.ps1')
. (Join-Path $PSScriptRoot 'lib\ldaplocal.ps1')

if (-not $Conf)   { $Conf = Join-Path $PSScriptRoot 'aghuse.conf' }
if (-not $Pacote) { $Pacote = Split-Path -Parent $PSScriptRoot }
$DIR = (Resolve-Path -LiteralPath $Pacote).Path
$TMPD = $null
$LOG = $null
$CODIGO_SAIDA = 0

try {
  Exigir-Admin 'o instalador'
  $C = Ler-Conf $Conf
  foreach ($k in $C.Keys) { Set-Variable -Name $k -Value $C[$k] }

  if ($SERVICO -notmatch '^[a-z0-9][a-z0-9_-]*$') { erro 'SERVICO invalido (use letras minusculas, numeros, - e _).' }
  Preparar-PastaProtegida $DADOS_AGHUSE
  $PASTA_LOG = Join-Path $DADOS_AGHUSE 'logs'
  if (-not (Test-Path $PASTA_LOG)) { New-Item -ItemType Directory -Path $PASTA_LOG | Out-Null }
  $LOG = Join-Path $PASTA_LOG "aghuse-instalador-$SERVICO.log"
  try { Start-Transcript -Path $LOG -Append | Out-Null } catch { }
  $TMPD = Novo-DirTemp

  Write-Host ''
  Write-Host '  ===================================================================' -ForegroundColor Green
  Write-Host "   AGHUse $VERSAO_AGHUSE - instalador para Windows" -ForegroundColor Green
  Write-Host '   Distribuido para TESTE e ESTUDO do sistema. Sem garantia e sem suporte.' -ForegroundColor Green
  Write-Host '  ===================================================================' -ForegroundColor Green
  # Pacote "variante" (modificacao nao oficial do AGHUse): identificado pelo arquivo VARIANTE
  $VARIANTE_DESCRICAO = ''
  $arqVariante = Join-Path $DIR 'VARIANTE'
  if (Test-Path -LiteralPath $arqVariante) {
    $VARIANTE_DESCRICAO = (Ler-Conf $arqVariante)['DESCRICAO']
    if (-not $VARIANTE_DESCRICAO) { $VARIANTE_DESCRICAO = 'Variante nao oficial' }
    Write-Host "   $VARIANTE_DESCRICAO" -ForegroundColor Yellow
  }
  Write-Host "  $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')   log: $LOG"

  # ----------------------------------------------------------------------------
  # 0. parametros e verificacoes
  # ----------------------------------------------------------------------------
  etapa 'Verificando parametros e requisitos'
  if ($AMBIENTE -notin @('teste', 'producao')) { erro "AMBIENTE deve ser 'teste' ou 'producao'." }
  if ($MODO_LOGIN -notin @('ldap-local', 'banco', 'ldap-externo')) { erro "MODO_LOGIN deve ser 'ldap-local', 'banco' ou 'ldap-externo'." }
  if ($MODO_LOGIN -eq 'ldap-local' -and $LDAP_LOCAL_PORTA -notmatch '^[0-9]+$') { erro 'LDAP_LOCAL_PORTA deve ser numerica.' }
  if ($RECRIAR_BANCO -notin @('sim', 'nao')) { erro "RECRIAR_BANCO deve ser 'sim' ou 'nao'." }
  if ($PROXY_REVERSO -notin @('sim', 'nao')) { erro "PROXY_REVERSO deve ser 'sim' ou 'nao'." }
  if ($LIBERAR_FIREWALL -notin @('sim', 'nao')) { erro "LIBERAR_FIREWALL deve ser 'sim' ou 'nao'." }
  if (-not $CONTAS_SERVICO.ContainsKey($CONTA_SERVICO)) { erro "CONTA_SERVICO deve ser LocalService, NetworkService ou LocalSystem." }

  if ($AMBIENTE -eq 'producao') {
    if ($CONFIRMO_PRODUCAO -ne 'sim') { erro "AMBIENTE=producao exige CONFIRMO_PRODUCAO=`"sim`" (leia a secao 'Uso em producao' do README.md)." }
    if ($PROXY_REVERSO -ne 'sim') { erro "em producao o sistema deve ser publicado atras de um proxy reverso com HTTPS: use PROXY_REVERSO=`"sim`"." }
    if ($HTTP_BIND -eq '0.0.0.0') { aviso 'HTTP_BIND=0.0.0.0: o WildFly tambem aceita conexoes diretas, sem passar pelo proxy. Prefira 127.0.0.1 ou restrinja a porta no firewall.' }
    if ($MODO_LOGIN -ne 'ldap-externo') { erro "em producao use MODO_LOGIN=ldap-externo (LDAP/Active Directory da instituicao). Os modos 'ldap-local' e 'banco' destinam-se apenas a testes." }
  }

  if ($ADMIN_LOGIN -notmatch '^[A-Za-z0-9_.-]+$') { erro 'ADMIN_LOGIN invalido.' }
  if ($PORT_OFFSET -notmatch '^[0-9]+$') { erro 'PORT_OFFSET deve ser numerico.' }
  if ($PG_PORTA -and $PG_PORTA -notmatch '^[0-9]+$') { erro 'PG_PORTA deve ser numerica.' }
  foreach ($par in @(@('DB_NOME', $DB_NOME), @('DB_USUARIO', $DB_USUARIO), @('DB_USUARIO_FIT', $DB_USUARIO_FIT))) {
    if ($par[1] -cnotmatch '^[a-z_][a-z0-9_]{0,62}$') { erro "$($par[0]) invalido: '$($par[1])' (use letras minusculas, numeros e _)." }
  }
  if ($PREFIXO -notmatch '^[A-Za-z]:\\[A-Za-z0-9_.\\-]+$') { erro "PREFIXO deve ser uma pasta absoluta sem espacos, fora da raiz do disco (ex.: C:\AGHUse)." }
  $PREFIXO = $PREFIXO.TrimEnd('\')
  if ($HTTP_BIND -notmatch '^\d{1,3}(\.\d{1,3}){3}$') { erro 'HTTP_BIND deve ser um endereco IPv4 (0.0.0.0, 127.0.0.1 ou o IP da maquina).' }
  if ($MODO_LOGIN -eq 'ldap-externo') {
    if (-not $LDAP_HOST) { erro 'informe LDAP_HOST para MODO_LOGIN=ldap-externo.' }
    if (-not $LDAP_USER_DN -or $LDAP_USER_DN -notlike '*%s*') { erro 'LDAP_USER_DN deve conter %s (ex.: %s@instituicao.local).' }
    if ($LDAP_PORTA -notmatch '^[0-9]+$') { erro 'LDAP_PORTA deve ser numerica.' }
  }

  $so = Get-CimInstance Win32_OperatingSystem
  info "sistema: $($so.Caption) (build $($so.BuildNumber))"
  if (-not [Environment]::Is64BitOperatingSystem) { erro 'o AGHUse requer Windows de 64 bits (x64).' }
  if ([int]$so.BuildNumber -lt 17763) { erro 'sistema nao suportado: use Windows 10/11 (1809 ou superior) ou Windows Server 2019/2022/2025.' }
  if (-not (Test-Path -LiteralPath $TAR) -and -not (Get-Command tar.exe -ErrorAction SilentlyContinue)) { erro 'tar.exe nao encontrado (componente do Windows 10 1809+).' }

  $cs = Get-CimInstance Win32_ComputerSystem
  $RAM_GB = [int][math]::Round($cs.TotalPhysicalMemory / 1GB)
  $NUCLEOS = [int]$cs.NumberOfLogicalProcessors
  # Windows: o sistema usa ~2,5 GB (contra ~0,5 GB de um Linux sem interface) e o WildFly ~6,5 GB
  # com 5G de heap (medido em 15/11/2026). Por isso o minimo aqui e 12 GB, e nao 8 GB como no Linux.
  if ($RAM_GB -lt 12) { erro "memoria insuficiente: $RAM_GB GB (no Windows o minimo e 12 GB; recomendado 16 GB)." }
  if (-not $MEMORIA_JVM) { $MEMORIA_JVM = '5G' }
  if ($MEMORIA_JVM -notmatch '^([0-9]+)([GgMm])$') { erro 'MEMORIA_JVM invalida (ex.: 5G).' }
  $MEM_MB = [int]$Matches[1]; if ($Matches[2] -match '[Gg]') { $MEM_MB *= 1024 }
  if ($MEM_MB -lt 5120) { erro "MEMORIA_JVM=$MEMORIA_JVM insuficiente: o AGHUse exige no minimo 5G (com 4G a aplicacao nao inicializa)." }
  info "memoria: $RAM_GB GB na maquina, $MEMORIA_JVM para o WildFly; processadores: $NUCLEOS"
  if ($NUCLEOS -lt 4) { aviso "a maquina tem $NUCLEOS processador(es); o minimo recomendado e 4." }

  if (-not (Test-Path -LiteralPath $PREFIXO)) { New-Item -ItemType Directory -Path $PREFIXO -Force | Out-Null }
  $disco = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$($PREFIXO.Substring(0,2))'"
  $LIVRE_GB = [int][math]::Floor($disco.FreeSpace / 1GB)
  if ($LIVRE_GB -lt 15) { erro "espaco livre insuficiente em ${PREFIXO}: $LIVRE_GB GB (minimo 15 GB; recomendado 100 GB)." }
  if ($LIVRE_GB -lt 40) { aviso "espaco livre de $LIVRE_GB GB; recomendado 100 GB para dados, logs e backups." }

  $PH = 8080 + [int]$PORT_OFFSET; $PM = 9990 + [int]$PORT_OFFSET
  $WFD = Join-Path $PREFIXO $WILDFLY_NOME
  $JDK = Join-Path $PREFIXO $JDK_NOME
  $PG_HOME = Join-Path $PREFIXO 'pgsql'
  $PG_BIN = Join-Path $PG_HOME 'bin'
  $PG_DADOS = Join-Path $PREFIXO 'pgdata'
  $PG_SERVICO = "$SERVICO-postgresql"

  # Sinais de que a maquina nao e dedicada (apenas aviso)
  $OUTROS = @()
  $nosso = Get-Service -Name $SERVICO -ErrorAction SilentlyContinue
  foreach ($p in @($PH, $PM)) {
    if ((Porta-EmUso $p) -and -not ($nosso -and $nosso.Status -eq 'Running')) { $OUTROS += "porta $p ja esta em uso por outro programa" }
  }
  foreach ($s in Get-Service -ErrorAction SilentlyContinue) {
    if ($s.Status -ne 'Running' -or $s.Name -eq $PG_SERVICO -or $s.Name -eq $SERVICO) { continue }
    if ($s.Name -match '(?i)postgres|mysql|mariadb|mssql|apache|tomcat|wildfly|jboss|^w3svc$|docker|nginx') { $OUTROS += "servico '$($s.Name)' em execucao" }
  }
  if ($OUTROS.Count -gt 0) {
    aviso 'esta maquina parece hospedar outros sistemas:'
    foreach ($o in $OUTROS) { Write-Host "      - $o" -ForegroundColor Yellow }
    aviso 'o instalador foi feito para uma maquina DEDICADA. Em maquinas com outros sistemas'
    aviso "a execucao e por sua conta e risco (veja 'Aviso importante' no README.md)."
    if (-not $NaoInterativo) { aviso 'Para cancelar, pressione Ctrl+C nos proximos 15 segundos.'; Start-Sleep -Seconds 15 }
  }

  etapa 'Conferindo integridade do pacote'
  # arquivos grandes podem vir divididos em partes (<nome>.parte-001, -002 ...): reconstroi
  foreach ($base in @('pacote', 'dependencias')) {
    $pasta = Join-Path $DIR $base
    if (-not (Test-Path $pasta)) { continue }
    foreach ($p1 in Get-ChildItem -LiteralPath $pasta -Recurse -File -Filter '*.parte-001' | Sort-Object FullName) {
      $alvo = $p1.FullName.Substring(0, $p1.FullName.Length - '.parte-001'.Length)
      if (Test-Path -LiteralPath $alvo) { continue }
      info "reconstruindo $(Split-Path $alvo -Leaf) a partir das partes"
      $partes = Get-ChildItem -LiteralPath $p1.DirectoryName -File -Filter ((Split-Path $alvo -Leaf) + '.parte-*') | Sort-Object Name
      $saida = [IO.File]::Create("$alvo.tmp")
      try { foreach ($pt in $partes) { $e = [IO.File]::OpenRead($pt.FullName); try { $e.CopyTo($saida) } finally { $e.Close() } } }
      finally { $saida.Close() }
      Move-Item -LiteralPath "$alvo.tmp" -Destination $alvo -Force
    }
  }
  $PAC = Join-Path $DIR 'pacote'
  foreach ($f in @('aghu.ear', 'dbaghu.dmp', 'wildfly-aghuse-overlay.tar.gz', 'wildfly-aghuse-removidos.txt', 'SHA256SUMS')) {
    if (-not (Test-Path -LiteralPath (Join-Path $PAC $f))) { erro "arquivo ausente: pacote\$f" }
  }
  function Conferir-Somas([string]$Pasta, [switch]$SomenteExistentes) {
    foreach ($l in [IO.File]::ReadAllLines((Join-Path $Pasta 'SHA256SUMS'))) {
      if ($l -notmatch '^([0-9a-fA-F]{64})\s+\*?(.+)$') { continue }
      $hash = $Matches[1]; $rel = $Matches[2].Trim()
      if ($rel.StartsWith('apt/')) { continue }          # pacotes .deb: somente Linux
      $arq = Join-Path $Pasta ($rel -replace '/', '\')
      if (-not (Test-Path -LiteralPath $arq)) { if ($SomenteExistentes) { continue }; erro "arquivo ausente: $arq" }
      if ((Get-FileHash -LiteralPath $arq -Algorithm SHA256).Hash -ne $hash.ToUpper()) { erro "hash SHA-256 nao confere: $rel" }
    }
  }
  Conferir-Somas $PAC
  info 'pacote integro'
  $DEP = Join-Path $DIR 'dependencias'
  if (Test-Path -LiteralPath (Join-Path $DEP 'SHA256SUMS')) { Conferir-Somas $DEP -SomenteExistentes; info 'dependencias integras' }

  function Obter-Arquivo([string]$Url, [string]$Sha) {   # usa dependencias\ ou baixa; confere SHA-256
    $nome = Split-Path $Url -Leaf
    $local = $null
    if (Test-Path -LiteralPath $DEP) { $local = Get-ChildItem -LiteralPath $DEP -Recurse -File -Filter $nome -ErrorAction SilentlyContinue | Select-Object -First 1 }
    if ($local) { $destino = $local.FullName; info "usando $nome da pasta dependencias" }
    else {
      $destino = Join-Path $TMPD $nome
      info "baixando $nome (nao encontrado em dependencias\) ..."
      [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
      [void](Invoke-Nativo curl.exe @('-fsSL', '--retry', '3', '--connect-timeout', '30', '-o', $destino, $Url) -MensagemErro "falha no download de $Url")
    }
    if ((Get-FileHash -LiteralPath $destino -Algorithm SHA256).Hash -ne $Sha.ToUpper()) { erro "hash SHA-256 nao confere: $nome" }
    return $destino
  }

  # senhas (geradas quando vazias)
  $GERADAS = @{}
  function Senha-Param([string]$Nome, [int]$Minimo = 0, [int]$TamanhoGerada = 32) {
    $valor = Get-Variable -Name $Nome -ValueOnly
    $minimo = $Minimo
    if (-not $minimo) { $minimo = 16; if ($AMBIENTE -eq 'producao') { $minimo = 20 } }
    if (-not $valor) { Set-Variable -Name $Nome -Value (Gerar-SenhaForte $TamanhoGerada) -Scope 1; $GERADAS[$Nome] = $true }
    else {
      if ($valor -cnotmatch '^[A-Za-z0-9]+$') { erro "$Nome deve conter apenas letras e numeros." }
      if ($valor.Length -lt $minimo) { erro "$Nome deve ter no minimo $minimo caracteres (ou deixe em branco para gerar automaticamente)." }
    }
  }
  Senha-Param 'DB_SENHA'
  Senha-Param 'DB_SENHA_FIT'
  # senha de quem entra no sistema: minimo 8 (digitavel); gerada com 12 caracteres
  if ($MODO_LOGIN -ne 'ldap-externo') { Senha-Param 'ADMIN_SENHA' 8 12 }

  # Pastas: somente SYSTEM e Administradores; leitura para Usuarios nos binarios (Java, PostgreSQL)
  [void](Invoke-Nativo icacls.exe @($PREFIXO, '/inheritance:r', '/grant:r', "*${SID_SYSTEM}:(OI)(CI)F", "*${SID_ADMINS}:(OI)(CI)F", "*${SID_USERS}:(OI)(CI)RX") -MensagemErro "falha ao ajustar as permissoes de $PREFIXO")

  # ----------------------------------------------------------------------------
  # 1-2. PostgreSQL 15 (privativo do AGHUse)
  # ----------------------------------------------------------------------------
  etapa 'PostgreSQL 15'
  if (-not (Test-Path -LiteralPath (Join-Path $PG_BIN 'postgres.exe'))) {
    $ARQ = Obter-Arquivo $PG_URL $PG_SHA256
    info 'extraindo o PostgreSQL ...'
    [void](Invoke-Nativo $TAR @('-xf', $ARQ, '-C', $PREFIXO, '--exclude', 'pgsql/pgAdmin*', '--exclude', 'pgsql/StackBuilder*', '--exclude', 'pgsql/doc', '--exclude', 'pgsql/include') -MensagemErro 'falha ao extrair o PostgreSQL.')
    info 'PostgreSQL 15 instalado'
  } else { info "PostgreSQL ja presente em $PG_HOME" }
  [void](Invoke-Nativo icacls.exe @($PG_HOME, '/grant', "*${SID_NETWORKSERVICE}:(OI)(CI)RX"))

  $ARQ_PGSENHA = Arquivo-SenhaPostgres $SERVICO
  $NOVO_CLUSTER = -not (Test-Path -LiteralPath (Join-Path $PG_DADOS 'PG_VERSION'))
  if (-not $PG_SENHA_POSTGRES -and (Test-Path -LiteralPath $ARQ_PGSENHA)) { $PG_SENHA_POSTGRES = ([IO.File]::ReadAllText($ARQ_PGSENHA)).Trim() }
  if ($NOVO_CLUSTER) {
    if (-not $PG_SENHA_POSTGRES) { $PG_SENHA_POSTGRES = Gerar-Senha }
    if ($PG_PORTA) {
      if (Porta-EmUso ([int]$PG_PORTA)) { erro "a porta $PG_PORTA (PG_PORTA) ja esta em uso." }
    } else {
      $PG_PORTA = 5432; while (Porta-EmUso $PG_PORTA) { $PG_PORTA++; if ($PG_PORTA -gt 5532) { erro 'nenhuma porta livre para o PostgreSQL entre 5432 e 5532.' } }
    }
    info "criando o cluster em $PG_DADOS (porta $PG_PORTA)"
    if (Test-Path -LiteralPath $PG_DADOS) { Remover-Pasta $PG_DADOS }
    New-Item -ItemType Directory -Path $PG_DADOS | Out-Null
    # o initdb roda com token restrito (sem o grupo Administradores): precisa de acesso pelo SID do usuario
    $SID_EU = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    [void](Invoke-Nativo icacls.exe @($PG_DADOS, '/inheritance:r', '/grant:r', "*${SID_SYSTEM}:(OI)(CI)F", "*${SID_ADMINS}:(OI)(CI)F", "*${SID_NETWORKSERVICE}:(OI)(CI)F", "*${SID_EU}:(OI)(CI)F"))
    $pw = Join-Path $TMPD 'pw.txt'; Gravar-Texto $pw $PG_SENHA_POSTGRES
    try {
      [void](Invoke-Nativo (Join-Path $PG_BIN 'initdb.exe') @('-D', $PG_DADOS, '-U', 'postgres', '-E', 'UTF8', '--locale-provider=icu', '--icu-locale=pt-BR', '--locale=C', '-A', 'scram-sha-256', "--pwfile=$pw") -MensagemErro 'falha ao criar o cluster PostgreSQL (initdb).')
    } finally { Remove-Item -LiteralPath $pw -Force -ErrorAction SilentlyContinue }
    if ($SID_EU -ne $SID_SYSTEM) { [void](Invoke-Nativo icacls.exe @($PG_DADOS, '/remove:g', "*$SID_EU", '/T', '/C', '/Q') -PermitirFalha) }
    $pgConf = "`r`n# --- AGHUse (gerado pelo instalador) ---`r`nport = $PG_PORTA`r`nlisten_addresses = 'localhost'`r`npassword_encryption = 'scram-sha-256'`r`nlogging_collector = on`r`nlog_directory = 'log'`r`nlog_timezone = '$FUSO_HORARIO'`r`ntimezone = '$FUSO_HORARIO'`r`n"
    [IO.File]::AppendAllText((Join-Path $PG_DADOS 'postgresql.conf'), $pgConf, $UTF8_SEM_BOM)
    Gravar-Texto $ARQ_PGSENHA $PG_SENHA_POSTGRES
  } else {
    if (-not $PG_SENHA_POSTGRES) { erro "o cluster $PG_DADOS ja existe e a senha do usuario postgres nao foi encontrada em ${ARQ_PGSENHA}: informe PG_SENHA_POSTGRES no aghuse.conf." }
    $PORTA_ATUAL = Porta-PgDados $PG_DADOS
    if ($PG_PORTA -and $PG_PORTA -ne $PORTA_ATUAL) {
      [IO.File]::AppendAllText((Join-Path $PG_DADOS 'postgresql.conf'), "`r`nport = $PG_PORTA`r`n", $UTF8_SEM_BOM)
      $svc = Get-Service -Name $PG_SERVICO -ErrorAction SilentlyContinue
      if ($svc -and $svc.Status -eq 'Running') { Restart-Service -Name $PG_SERVICO -Force }
    }
    $PG_PORTA = Porta-PgDados $PG_DADOS
    info "cluster existente em $PG_DADOS (porta $PG_PORTA)"
  }
  if (-not (Get-Service -Name $PG_SERVICO -ErrorAction SilentlyContinue)) {
    [void](Invoke-Nativo (Join-Path $PG_BIN 'pg_ctl.exe') @('register', '-N', $PG_SERVICO, '-D', $PG_DADOS, '-S', 'auto', '-w') -MensagemErro 'falha ao registrar o servico do PostgreSQL.')
    info "servico $PG_SERVICO registrado"
  }
  $svc = Get-Service -Name $PG_SERVICO
  if ($svc.Status -ne 'Running') { Start-Service -Name $PG_SERVICO }
  $env:PGPASSWORD = $PG_SENHA_POSTGRES
  $env:PGOPTIONS = '-c client_min_messages=warning'
  $pronto = $false
  for ($i = 0; $i -lt 60; $i++) {
    [void](Invoke-Nativo (Join-Path $PG_BIN 'pg_isready.exe') @('-h', '127.0.0.1', '-p', "$PG_PORTA", '-q') -PermitirFalha)
    if ($ULTIMO_CODIGO -eq 0) { $pronto = $true; break }
    Start-Sleep -Seconds 2
  }
  if (-not $pronto) { erro "o PostgreSQL nao iniciou (servico $PG_SERVICO). Veja $PG_DADOS\log" }
  [void](Psql -Sql 'select 1')
  info "PostgreSQL ativo na porta $PG_PORTA (somente conexoes locais)"

  # ----------------------------------------------------------------------------
  # 3. banco do AGHUse
  # ----------------------------------------------------------------------------
  etapa "Banco de dados $DB_NOME"
  [void](Psql -Sql @"
DO `$`$ DECLARE r text; BEGIN
FOREACH r IN ARRAY ARRAY['acesso_completo','acesso_leitura','escrita_integra','ugen_bi','ugen_pesquisa','ugen_surex','agh'] LOOP
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname=r) THEN EXECUTE format('CREATE ROLE %I', r); END IF;
END LOOP; END `$`$;
DO `$`$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='$DB_USUARIO') THEN CREATE ROLE "$DB_USUARIO" LOGIN; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='$DB_USUARIO_FIT') THEN CREATE ROLE "$DB_USUARIO_FIT" LOGIN; END IF;
END `$`$;
SET password_encryption = 'scram-sha-256';
ALTER ROLE "$DB_USUARIO" PASSWORD '$DB_SENHA';
ALTER ROLE "$DB_USUARIO_FIT" PASSWORD '$DB_SENHA_FIT';
GRANT acesso_completo TO "$DB_USUARIO", "$DB_USUARIO_FIT";
"@)

  $EXISTE_DB = (Psql -Valor -Sql "select 1 from pg_database where datname='$DB_NOME'") -join ''
  if ($EXISTE_DB -and $RECRIAR_BANCO -eq 'sim') {
    if (Get-Service -Name $SERVICO -ErrorAction SilentlyContinue) { Stop-Service -Name $SERVICO -Force -ErrorAction SilentlyContinue }
    info "apagando o banco $DB_NOME (RECRIAR_BANCO=sim)"
    [void](Psql -Sql "DROP DATABASE `"$DB_NOME`" WITH (FORCE)")
    $EXISTE_DB = ''
  }
  if (-not $EXISTE_DB) {
    [void](Psql -Sql "CREATE DATABASE `"$DB_NOME`" WITH TEMPLATE template0 ENCODING 'UTF8' OWNER postgres")
    $JOBS = [math]::Min($NUCLEOS, 8)
    info "restaurando a base inicial ($JOBS processos paralelos; pode levar de 2 a 45 minutos) ..."
    $inicio = Get-Date
    [void](Invoke-Nativo (Join-Path $PG_BIN 'pg_restore.exe') @('-h', '127.0.0.1', '-p', "$PG_PORTA", '-U', 'postgres', '-d', $DB_NOME, '-j', "$JOBS", '--no-tablespaces', (Join-Path $PAC 'dbaghu.dmp')) -MensagemErro 'falha ao restaurar a base inicial.')
    info "base restaurada em $([int]((Get-Date) - $inicio).TotalMinutes) min"
  } else {
    info "banco $DB_NOME ja existe - dados preservados (RECRIAR_BANCO=nao)"
  }
  # Acesso ao banco: somente os usuarios da aplicacao conectam no DB_NOME. No modo
  # "banco", as credenciais de login sao conferidas em um banco vazio (DB_LOGIN).
  $DB_LOGIN = 'aghuse_login'
  if (-not ((Psql -Valor -Sql "select 1 from pg_database where datname='$DB_LOGIN'") -join '')) {
    [void](Psql -Sql "CREATE DATABASE `"$DB_LOGIN`" WITH TEMPLATE template0 ENCODING 'UTF8' OWNER postgres")
  }
  [void](Psql -Sql @"
REVOKE ALL ON DATABASE "$DB_LOGIN" FROM PUBLIC;
REVOKE CONNECT, TEMPORARY ON DATABASE "$DB_NOME" FROM PUBLIC;
GRANT CONNECT, TEMPORARY ON DATABASE "$DB_NOME" TO "$DB_USUARIO", "$DB_USUARIO_FIT";
"@)
  info "acesso ao banco $DB_NOME restrito aos usuarios da aplicacao"
  # Tela inicial em branco ("A ID de componente panel_NNN ja foi encontrada"): no primeiro login o
  # AGHUse grava os icones do usuario em casca.csc_dashboard; dois logins simultaneos gravam tudo em
  # dobro, e a restricao unica da tabela nao impede porque modal/id_favorito ficam NULL. Remove
  # duplicatas e cria um indice unico que trata NULL (defeito do AGHUse; nao altera dados validos).
  [void](Psql -Banco $DB_NOME -Sql @"
DELETE FROM casca.csc_dashboard d USING casca.csc_dashboard o
 WHERE d.id_usuario = o.id_usuario AND d.id_favorito IS NOT DISTINCT FROM o.id_favorito
   AND d.modal IS NOT DISTINCT FROM o.modal AND d.id > o.id;
CREATE UNIQUE INDEX IF NOT EXISTS csc_dsh_uk_instalador
  ON casca.csc_dashboard (id_usuario, coalesce(modal, ''), coalesce(id_favorito, -1));
"@)
  # Vinculo do administrador: na base inicial o AGHU e o servidor 9999999/955. "Criar Login" nesse
  # servidor (tela Usuario) passa o vinculo para o login novo e o AGHU fica sem servidor: novos logins
  # e a troca de senha falham ("Nenhum Servidor do HU encontrado associado ao usuario AGHU").
  # Reparo (devolve o vinculo) e protecao (o banco recusa passar esse servidor para outro login).
  [void](Psql -Banco $DB_NOME -Sql @'
UPDATE agh.rap_servidores SET usuario = 'AGHU'
 WHERE matricula = 9999999 AND vin_codigo = 955 AND upper(coalesce(usuario, '')) <> 'AGHU'
   AND NOT EXISTS (SELECT 1 FROM agh.rap_servidores s WHERE upper(s.usuario) = 'AGHU');
CREATE OR REPLACE FUNCTION agh.instalador_protege_servidor_admin() RETURNS trigger LANGUAGE plpgsql AS $f$
BEGIN
  IF upper(coalesce(OLD.usuario, '')) = 'AGHU' AND upper(coalesce(NEW.usuario, '')) <> 'AGHU' THEN
    RAISE EXCEPTION 'O servidor % (vinculo %) pertence ao administrador AGHU e nao pode receber outro login. Cadastre uma pessoa e um servidor novos para este usuario.', OLD.matricula, OLD.vin_codigo;
  END IF;
  RETURN NEW;
END $f$;
DROP TRIGGER IF EXISTS trg_instalador_protege_admin ON agh.rap_servidores;
CREATE TRIGGER trg_instalador_protege_admin BEFORE UPDATE OF usuario ON agh.rap_servidores
  FOR EACH ROW EXECUTE FUNCTION agh.instalador_protege_servidor_admin();
'@)
  if (((Psql -Valor -Banco $DB_NOME -Sql "select count(*) from agh.rap_servidores where upper(usuario)='AGHU'") -join '') -ne '1') {
    aviso 'o administrador AGHU esta sem vinculo de servidor (agh.rap_servidores): o login dele pode ser recusado.'
  }
  if (((Psql -Valor -Banco $DB_NOME -Sql "select count(*) from casca.csc_usuario where login=upper('$ADMIN_LOGIN')") -join '') -ne '1') {
    aviso "o usuario $ADMIN_LOGIN nao foi encontrado em casca.csc_usuario."
  }

  # ----------------------------------------------------------------------------
  # 4. autenticacao
  # ----------------------------------------------------------------------------
  etapa "Autenticacao: $MODO_LOGIN"
  $NOTA_ADMIN = ''
  if ($MODO_LOGIN -eq 'banco') {
    foreach ($r in @($ADMIN_LOGIN.ToUpper(), $ADMIN_LOGIN.ToLower()) | Select-Object -Unique) {
      [void](Psql -Sql @"
DO `$`$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='$r') THEN CREATE ROLE "$r" LOGIN; END IF; END `$`$;
SET password_encryption = 'scram-sha-256';
ALTER ROLE "$r" PASSWORD '$ADMIN_SENHA';
REVOKE ALL ON DATABASE "$DB_NOME" FROM "$r";
GRANT CONNECT ON DATABASE "$DB_LOGIN" TO "$r";
"@)
    }
    info "modo de avaliacao: senha do $ADMIN_LOGIN conferida pelo PostgreSQL"
    info 'outras contas de acesso: usuario.bat criar LOGIN'
    $LDAP_HOST = ''; $LDAP_PORTA = '389'; $LDAP_USER_DN = ''; $LDAP_BASE_USUARIOS = ''; $LDAP_ATRIBUTO_LOGIN = ''
    $LDAP_FILTRO = ''; $LDAP_BIND_DN = ''; $LDAP_BIND_SENHA = ''
  } elseif ($MODO_LOGIN -eq 'ldap-local') {
    # AD LDS: o "OpenLDAP" do Windows (componente gratuito do proprio sistema)
    $INST = LdapLocal-Instancia $SERVICO
    $ADAM_SERVICO = LdapLocal-Servico $SERVICO
    LdapLocal-HabilitarRecurso
    if (-not (Get-Service -Name $ADAM_SERVICO -ErrorAction SilentlyContinue)) {
      LdapLocal-CriarInstancia $INST ([int]$LDAP_LOCAL_PORTA) ([int]$LDAP_LOCAL_PORTA + 247) (Join-Path $PREFIXO 'adlds') $TMPD
      info "AD LDS instalado: instancia $INST, base $LDAP_LOCAL_PARTICAO, porta $LDAP_LOCAL_PORTA"
    } else {
      $pr = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\$ADAM_SERVICO\Parameters" -ErrorAction SilentlyContinue
      if ($pr -and $pr.PSObject.Properties['Port LDAP']) { $LDAP_LOCAL_PORTA = [string]$pr.'Port LDAP' }
      info "AD LDS ja instalado (instancia $INST, porta $LDAP_LOCAL_PORTA) - contas preservadas"
    }
    Set-Service -Name $ADAM_SERVICO -StartupType Automatic
    if ((Get-Service -Name $ADAM_SERVICO).Status -ne 'Running') { Start-Service -Name $ADAM_SERVICO }
    $LP = [int]$LDAP_LOCAL_PORTA
    for ($i = 0; $i -lt 30 -and -not (Testar-Tcp '127.0.0.1' $LP 2000); $i++) { Start-Sleep -Seconds 2 }
    LdapLocal-BloquearRede $INST
    $cl = Ldap-Conectar $LP
    try {
      LdapLocal-PrepararDiretorio $cl
      # conta de servico somente leitura (tela "Importar Usuario")
      $ARQ_LSENHA = LdapLocal-ArquivoSenha $SERVICO
      $LSENHA = ''; if (Test-Path -LiteralPath $ARQ_LSENHA) { $LSENHA = ([IO.File]::ReadAllText($ARQ_LSENHA)).Trim() }
      if (-not (Ldap-Existe $cl $LDAP_LOCAL_LEITURA)) {
        if (-not $LSENHA) { $LSENHA = Gerar-SenhaForte 32 }
        Ldap-Adicionar $cl $LDAP_LOCAL_LEITURA @{ objectClass = 'user'; unicodePwd = (Ldap-SenhaUnicode $LSENHA); 'msDS-UserAccountDisabled' = 'FALSE' }
      } elseif (-not $LSENHA -or -not (Ldap-Testar $LP $LDAP_LOCAL_LEITURA $LSENHA)) {
        $LSENHA = Gerar-SenhaForte 32; Ldap-DefinirSenha $cl $LDAP_LOCAL_LEITURA $LSENHA
      }
      Ldap-AdicionarLeitor $cl $LDAP_LOCAL_LEITURA
      Gravar-Texto $ARQ_LSENHA $LSENHA
      # administrador do AGHUse
      $UDN = LdapLocal-DnUsuario $ADMIN_LOGIN
      if (Ldap-Existe $cl $UDN) {
        Ldap-DefinirSenha $cl $UDN $ADMIN_SENHA; Ldap-AdicionarLeitor $cl $UDN
        info "senha da conta $UDN redefinida"
      } else {
        [void](Ldap-CriarUsuario $cl $ADMIN_LOGIN $ADMIN_SENHA 'Administrador AGHUse')
        info "conta $UDN criada (outras contas: usuario.bat criar LOGIN)"
      }
    } finally { $cl.Dispose() }
    if (-not (Ldap-Testar $LP $UDN $ADMIN_SENHA)) { erro "falha no teste de login LDAP do $ADMIN_LOGIN." }
    info "login LDAP do $ADMIN_LOGIN conferido (diretorio so neste computador)"
    $LDAP_HOST = '127.0.0.1'; $LDAP_PORTA = "$LP"
    $LDAP_USER_DN = "CN=%s,$LDAP_LOCAL_PESSOAS"; $LDAP_BASE_USUARIOS = $LDAP_LOCAL_PESSOAS
    $LDAP_ATRIBUTO_LOGIN = 'uid'; $LDAP_FILTRO = '(&(objectClass=inetOrgPerson)(uid=%s))'
    $LDAP_BIND_DN = $LDAP_LOCAL_LEITURA; $LDAP_BIND_SENHA = $LSENHA
  } else {
    $H1 = ($LDAP_HOST -split ',')[0].Trim()
    if (Testar-Tcp $H1 ([int]$LDAP_PORTA)) { info "servidor LDAP ${H1}:$LDAP_PORTA acessivel" }
    else { aviso "nao foi possivel conectar em ${H1}:$LDAP_PORTA. Verifique rede/firewall; o login so funcionara com o servidor acessivel." }
    $NOTA_ADMIN = "a senha e a do LDAP/AD; o login '$ADMIN_LOGIN' precisa existir no diretorio"
  }

  # ----------------------------------------------------------------------------
  # 5. Java
  # ----------------------------------------------------------------------------
  etapa 'OpenJDK 17.0.2'
  if (-not (Test-Path -LiteralPath (Join-Path $JDK 'bin\java.exe'))) {
    $ARQ = Obter-Arquivo $JDK_URL $JDK_SHA256
    [void](Invoke-Nativo $TAR @('-xf', $ARQ, '-C', $PREFIXO) -MensagemErro 'falha ao extrair o OpenJDK.')
  }
  $v = Invoke-Nativo (Join-Path $JDK 'bin\java.exe') @('-version')
  info $v[0]

  # ----------------------------------------------------------------------------
  # 6. WildFly + AGHUse
  # ----------------------------------------------------------------------------
  etapa 'WildFly 26.1.3 e aplicacao AGHUse'
  $CONTA = $CONTAS_SERVICO[$CONTA_SERVICO]
  if (Get-Service -Name $SERVICO -ErrorAction SilentlyContinue) {
    info "parando o servico $SERVICO"
    Stop-Service -Name $SERVICO -Force -NoWait -ErrorAction SilentlyContinue
    for ($i = 0; $i -lt 90 -and (Get-Service -Name $SERVICO).Status -ne 'Stopped'; $i++) { Start-Sleep -Seconds 2 }
  }
  # processos java remanescentes desta instalacao
  Get-CimInstance Win32_Process -Filter "Name='java.exe'" | Where-Object { $_.CommandLine -and $_.CommandLine -like "*$WFD*" } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }

  if (Test-Path -LiteralPath $WFD) {
    $BKD = Join-Path $PREFIXO 'backup'
    if (-not (Test-Path $BKD)) { New-Item -ItemType Directory -Path $BKD | Out-Null }
    [void](Invoke-Nativo icacls.exe @($BKD, '/inheritance:r', '/grant:r', "*${SID_SYSTEM}:(OI)(CI)F", "*${SID_ADMINS}:(OI)(CI)F"))
    $BK = Join-Path $BKD ("wildfly-config-{0}.tar.gz" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
    [void](Invoke-Nativo $TAR @('-czf', $BK, '-C', $WFD, 'standalone/configuration', 'bin/standalone.conf.bat', 'modules/br/gov/mec/aghu/configuration') -PermitirFalha)
    info "instalacao anterior encontrada - configuracao salva em $BK"
    Remover-Pasta $WFD
  }
  $ARQ = Obter-Arquivo $WILDFLY_URL $WILDFLY_SHA256
  [void](Invoke-Nativo $TAR @('-xf', $ARQ, '-C', $PREFIXO) -MensagemErro 'falha ao extrair o WildFly.')
  [void](Invoke-Nativo $TAR @('-xzf', (Join-Path $PAC 'wildfly-aghuse-overlay.tar.gz'), '-C', $WFD) -MensagemErro 'falha ao extrair o overlay do AGHUse.')
  foreach ($f in [IO.File]::ReadAllLines((Join-Path $PAC 'wildfly-aghuse-removidos.txt'))) {
    if ($f.Trim()) { Remove-Item -LiteralPath (Join-Path $WFD ($f.Trim() -replace '/', '\')) -Force -ErrorAction SilentlyContinue }
  }

  # --- configuracao (equivalente a lib/configurar_wildfly.py) ---
  $XML = Join-Path $WFD 'standalone\configuration\standalone-full.xml'
  $PROPS = Join-Path $WFD 'modules\br\gov\mec\aghu\configuration\main\properties\app-parameters.properties'
  $REALM_LDAP = 'br.gov.mec.aghu.casca.autenticacao.AghuseLdapSecurityRealm'
  $REALM_BANCO = 'br.gov.mec.aghu.casca.autenticacao.AghuseDbConnectionSecurityRealm'
  $valores = [ordered]@{
    NOME_AMBIENTE = $NOME_AMBIENTE; DB_HOST = '127.0.0.1'; DB_PORTA = "$PG_PORTA"; DB_NOME = $DB_NOME
    DB_USUARIO = $DB_USUARIO; DB_SENHA = $DB_SENHA; DB_USUARIO_FIT = $DB_USUARIO_FIT; DB_SENHA_FIT = $DB_SENHA_FIT
    REALM_CLASSE = $(if ($MODO_LOGIN -eq 'banco') { $REALM_BANCO } else { $REALM_LDAP })
    LDAP_HOST = $LDAP_HOST; LDAP_PORTA = $(if ($LDAP_PORTA) { $LDAP_PORTA } else { '389' }); LDAP_USER_DN = $LDAP_USER_DN
    LDAP_BIND_DN = $LDAP_BIND_DN; LDAP_BIND_SENHA = $LDAP_BIND_SENHA; LDAP_BASE_USUARIOS = $LDAP_BASE_USUARIOS
    LDAP_ATRIBUTO_LOGIN = $LDAP_ATRIBUTO_LOGIN; LDAP_FILTRO = $LDAP_FILTRO; SMTP_HOST = $SMTP_HOST
  }
  function Preencher([string]$Texto, [scriptblock]$Esc) {
    foreach ($k in $valores.Keys) { $Texto = $Texto.Replace("__AGHUSE_${k}__", (& $Esc ([string]$valores[$k]))) }
    $resto = [regex]::Matches($Texto, '__AGHUSE_[A-Z_]+__') | ForEach-Object { $_.Value } | Sort-Object -Unique
    if ($resto) { erro "marcadores sem valor: $($resto -join ', ')" }
    return $Texto
  }
  $x = [IO.File]::ReadAllText($XML, [Text.Encoding]::UTF8)
  $x = Preencher $x { param($v) [Security.SecurityElement]::Escape($v) }
  if ($MODO_LOGIN -eq 'banco') {
    $re = [regex]('(class-name="' + [regex]::Escape($REALM_BANCO) + '">\r?\n\s*<configuration>\r?\n)')
    if (-not $re.IsMatch($x)) { erro 'bloco do realm nao encontrado no standalone-full.xml' }
    $x = $re.Replace($x, '$1                        <property name="loginDatasource" value="java:/aghuLoginDatasource"/>' + "`n", 1)
    # jta="false": a conferencia de senha (tela Senha) roda dentro de uma transacao; um datasource
    # transacional seria recusado ("multiple last resources") e a senha atual nunca conferiria
    $ds = @"
                <datasource jndi-name="java:/aghuLoginDatasource" pool-name="aghulogin" enabled="true" use-java-context="true" jta="false">
                    <connection-url>jdbc:postgresql://127.0.0.1:$PG_PORTA/$DB_LOGIN</connection-url>
                    <driver>PostgresqlDriver</driver>
                    <pool>
                        <min-pool-size>0</min-pool-size>
                        <max-pool-size>5</max-pool-size>
                        <prefill>false</prefill>
                        <allow-multiple-users/>
                    </pool>
                    <validation>
                        <check-valid-connection-sql>select now()</check-valid-connection-sql>
                        <validate-on-match>true</validate-on-match>
                    </validation>
                </datasource>

"@ -replace "`r`n", "`n"
    $i = $x.IndexOf('                <drivers>')
    if ($i -lt 0) { erro 'secao <drivers> nao encontrada no standalone-full.xml' }
    $x = $x.Insert($i, $ds)
  }
  # proxy reverso com HTTPS: o WildFly passa a usar X-Forwarded-Proto/Host/For
  if ($PROXY_REVERSO -eq 'sim') {
    $re = [regex]'<http-listener name="default"(?![^>]*proxy-address-forwarding)'
    if (-not $re.IsMatch($x)) { erro "http-listener 'default' nao encontrado no standalone-full.xml" }
    $x = $re.Replace($x, '<http-listener name="default" proxy-address-forwarding="true"', 1)
  }
  Gravar-Texto $XML $x

  $p = [IO.File]::ReadAllText($PROPS, [Text.Encoding]::UTF8)
  $p = Preencher $p { param($v) $v.Replace('\', '\\') }
  $p = $p.Replace('@bloq.metodo.logout@', 'websocket')
  $p = [regex]::Replace($p, '@[a-z][a-zA-Z._-]*@', '')
  $p = [regex]::Replace($p, '(?m)^remote_ejb_server=.*$', "remote_ejb_server=localhost:$PH")
  $cfgMod = ($WFD -replace '\\', '/') + '/modules/br/gov/mec/aghu/configuration/main'
  $p = [regex]::Replace($p, '(?m)^caminho-certificados=.*$', "caminho-certificados=$cfgMod/certificados/certificado.jks")
  $p = [regex]::Replace($p, '(?m)^caminho-clr=.*$', "caminho-clr=$cfgMod/certificados_revogados")
  Gravar-Texto $PROPS $p
  info "configuracao do WildFly gerada (login: $MODO_LOGIN)"

  $OPTS = @(
    "-Xms$MEMORIA_JVM -Xmx$MEMORIA_JVM -XX:MaxMetaspaceSize=2G -Djava.net.preferIPv4Stack=true -Dorg.jboss.resolver.warning=true -Dsun.rmi.dgc.client.gcInterval=3600000 -Dsun.rmi.dgc.server.gcInterval=3600000 -Dorg.apache.el.parser.COERCE_TO_ZERO=false -Djboss.as.management.blocking.timeout=1800",
    '-Djboss.modules.system.pkgs=%JBOSS_MODULES_SYSTEM_PKGS% -Djava.awt.headless=true',
    '-Djboss.server.default.config=standalone-full.xml -Dorg.jboss.as.logging.per-deployment=false',
    '-Doracle.jdbc.DateZeroTime=true -Dactivemq.artemis.client.global.thread.pool.max.size=30',
    '-Djavamelody.datasources=java:/aghuDatasource -XX:+UseG1GC -XX:ReservedCodeCacheSize=512m',
    '-Dcom.sun.xml.bind.v2.bytecode.ClassTailor.noOptimize=true -Djdk.httpclient.keepalive.timeout=10',
    "-Duser.timezone=$FUSO_HORARIO -Duser.language=pt -Duser.country=BR -Dfile.encoding=UTF-8",
    "-Djboss.bind.address=$HTTP_BIND -Djboss.bind.address.management=127.0.0.1 -Djboss.socket.binding.port-offset=$PORT_OFFSET"
  )
  $linhasBat = @('@echo off', 'rem AGHUse - standalone.conf.bat (gerado pelo instalador)',
    'if "x%JBOSS_MODULES_SYSTEM_PKGS%" == "x" set "JBOSS_MODULES_SYSTEM_PKGS=org.jboss.byteman"',
    "set `"JAVA_HOME=$JDK`"",
    'if not "x%JAVA_OPTS%" == "x" goto JAVA_OPTS_SET',
    "set `"JAVA_OPTS=$($OPTS[0])`"")
  foreach ($o in $OPTS[1..($OPTS.Count - 1)]) { $linhasBat += "set `"JAVA_OPTS=%JAVA_OPTS% $o`"" }
  $linhasBat += ':JAVA_OPTS_SET'
  [IO.File]::WriteAllText((Join-Path $WFD 'bin\standalone.conf.bat'), (($linhasBat -join "`r`n") + "`r`n"), [Text.Encoding]::ASCII)

  New-Item -ItemType Directory -Path (Join-Path $WFD 'lucene\indexes') -Force | Out-Null
  Copy-Item -LiteralPath (Join-Path $PAC 'aghu.ear') -Destination (Join-Path $WFD 'standalone\deployments\aghu.ear') -Force
  $PRUNSRV_DIR = Join-Path $WFD 'bin\service'
  New-Item -ItemType Directory -Path $PRUNSRV_DIR -Force | Out-Null
  $PRUNSRV = Join-Path $PRUNSRV_DIR 'aghuse-service.exe'
  Copy-Item -LiteralPath (Join-Path $WFD 'docs\contrib\scripts\service\amd64\wildfly-service.exe') -Destination $PRUNSRV -Force

  # Permissoes (equivalente ao chmod 750/640 do Linux): WildFly so para SYSTEM, Administradores e a conta do servico
  [void](Invoke-Nativo icacls.exe @($WFD, '/inheritance:r', '/grant:r', "*${SID_SYSTEM}:(OI)(CI)F", "*${SID_ADMINS}:(OI)(CI)F", "*$($CONTA.Sid):(OI)(CI)M") -MensagemErro "falha ao ajustar as permissoes de $WFD")

  # Servico do Windows (Apache Procrun, distribuido com o WildFly)
  $acao = 'IS'; if (Get-Service -Name $SERVICO -ErrorAction SilentlyContinue) { $acao = 'US' }
  $ap = @("//$acao//$SERVICO",
    "--DisplayName=AGHUse $VERSAO_AGHUSE ($SERVICO)",
    '--Description=AGHUse - Aplicativo para Gestao Hospitalar (WildFly 26.1.3)',
    '--Startup=auto', '--StartMode=exe', '--StartImage=cmd.exe', "--StartPath=$WFD\bin",
    # caminho completo: com NoDefaultCurrentDirectoryInExePath o cmd nao procura na pasta atual
    "--StartParams=/c#$WFD\bin\standalone.bat#-c#standalone-full.xml",
    '--StopMode=exe', '--StopImage=cmd.exe', "--StopPath=$WFD\bin",
    "--StopParams=/c#$WFD\bin\jboss-cli.bat#--controller=127.0.0.1:$PM#--connect#--command=:shutdown",
    '--StopTimeout=120', "--Environment=JAVA_HOME=$JDK#NOPAUSE=Y",
    "--LogPath=$WFD\standalone\log", '--LogPrefix=service', '--LogLevel=Info', '--StdOutput=auto', '--StdError=auto',
    "--DependsOn=$PG_SERVICO$(if ($MODO_LOGIN -eq 'ldap-local') { '#' + (LdapLocal-Servico $SERVICO) })")
  [void](Invoke-Nativo $PRUNSRV $ap -MensagemErro "falha ao registrar o servico $SERVICO.")
  if ($CONTA_SERVICO -ne 'LocalSystem') {
    $w = Get-CimInstance Win32_Service -Filter "Name='$SERVICO'"
    $r = Invoke-CimMethod -InputObject $w -MethodName Change -Arguments @{ StartName = $CONTA.Nome; StartPassword = '' }
    if ($r.ReturnValue -ne 0) { erro "falha ao definir a conta do servico ($($CONTA.Nome)): codigo $($r.ReturnValue)" }
  }
  [void](Invoke-Nativo sc.exe @('failure', $SERVICO, 'reset=', '86400', 'actions=', 'restart/60000/restart/60000/restart/60000') -PermitirFalha)
  info "servico $SERVICO registrado (conta $($CONTA.Nome))"

  # ----------------------------------------------------------------------------
  # 7. inicializacao e verificacao
  # ----------------------------------------------------------------------------
  etapa 'Iniciando o AGHUse (a primeira inicializacao leva de 3 a 10 minutos)'
  $DEPL = Join-Path $WFD 'standalone\deployments'
  Start-Service -Name $SERVICO
  for ($i = 0; $i -lt 180; $i++) {
    if ((Test-Path (Join-Path $DEPL 'aghu.ear.deployed')) -or (Test-Path (Join-Path $DEPL 'aghu.ear.failed'))) { break }
    if ((Get-Service -Name $SERVICO).Status -eq 'Stopped') { break }
    if ($i % 12 -eq 11) { info "aguardando a implantacao ... ($([int](($i + 1) * 5 / 60)) min)" }
    Start-Sleep -Seconds 5
  }
  if (-not (Test-Path (Join-Path $DEPL 'aghu.ear.deployed'))) { erro "a aplicacao nao foi implantada. Veja $WFD\standalone\log\server.log" }
  $HOST_TESTE = $HTTP_BIND; if ($HTTP_BIND -eq '0.0.0.0') { $HOST_TESTE = '127.0.0.1' }
  $URL_LOCAL = "http://${HOST_TESTE}:$PH/aghu/pages/casca/casca.xhtml"
  $PAGINA = ''
  for ($i = 0; $i -lt 12 -and $PAGINA -notmatch 'formLogin'; $i++) { $PAGINA = Obter-Pagina $URL_LOCAL; if ($PAGINA -notmatch 'formLogin') { Start-Sleep -Seconds 15 } }
  if ($PAGINA -notmatch 'formLogin') { erro "a tela de login nao respondeu em $URL_LOCAL" }
  $VERSAO_TELA = ''
  if ($PAGINA -cmatch 'Vers[^<]*') { $VERSAO_TELA = ($Matches[0] -replace '\s+', ' ') }
  info 'aplicacao implantada e respondendo'
  if ($VERSAO_TELA) { info $VERSAO_TELA }

  # Firewall do Windows (somente redes de dominio e privadas)
  $REGRA = "AGHUse ($SERVICO) HTTP"
  Get-NetFirewallRule -DisplayName $REGRA -ErrorAction SilentlyContinue | Remove-NetFirewallRule -ErrorAction SilentlyContinue
  if ($LIBERAR_FIREWALL -eq 'sim' -and $HTTP_BIND -ne '127.0.0.1') {
    New-NetFirewallRule -DisplayName $REGRA -Direction Inbound -Protocol TCP -LocalPort $PH -Action Allow -Profile Domain, Private | Out-Null
    info "firewall: porta $PH liberada (redes de dominio e privadas)"
  }

  # ----------------------------------------------------------------------------
  # 8. credenciais e resumo
  # ----------------------------------------------------------------------------
  if ($HTTP_BIND -eq '0.0.0.0') { $HOST_URL = Ip-Principal } else { $HOST_URL = $HTTP_BIND }
  $URL = "http://${HOST_URL}:$PH/aghu"
  # endereco para este proprio computador (atalho e navegador): independe do IP da maquina
  if ($HTTP_BIND -eq '0.0.0.0' -or $HTTP_BIND -eq '127.0.0.1') { $URL_LOCAL = "http://localhost:$PH/aghu" } else { $URL_LOCAL = $URL }
  $CRED = Join-Path $DADOS_AGHUSE "aghuse-credenciais-$SERVICO.txt"
  $t = @("AGHUse $VERSAO_AGHUSE - credenciais da instalacao ($(Get-Date -Format 'dd/MM/yyyy HH:mm'))",
         "Ambiente: $AMBIENTE   Login: $MODO_LOGIN",
         $(if ($VARIANTE_DESCRICAO) { "Aplicacao: $VARIANTE_DESCRICAO" } else { "Aplicacao: AGHUse $VERSAO_AGHUSE original (sem modificacoes)" }), '',
         "URL neste computador .....: $URL_LOCAL",
         "URL na rede ..............: $URL  (outros computadores)")
  if ($MODO_LOGIN -eq 'ldap-externo') { $t += "Usuario administrador ....: $ADMIN_LOGIN ($NOTA_ADMIN)" }
  else { $t += "Usuario administrador ....: $ADMIN_LOGIN"; $t += "Senha do administrador ...: $ADMIN_SENHA" }
  $t += ''
  $t += "PostgreSQL 15 ............: 127.0.0.1:$PG_PORTA  banco $DB_NOME  (servico $PG_SERVICO)"
  $t += "Superusuario postgres ....: postgres / $PG_SENHA_POSTGRES"
  $t += "Usuario da aplicacao .....: $DB_USUARIO / $DB_SENHA"
  $t += "Usuario FIT ..............: $DB_USUARIO_FIT / $DB_SENHA_FIT"
  if ($MODO_LOGIN -eq 'ldap-local') {
    $t += ''
    $t += "LDAP local (AD LDS) ......: 127.0.0.1:$LDAP_PORTA  base $LDAP_LOCAL_PARTICAO  (servico $(LdapLocal-Servico $SERVICO))"
    $t += "Contas de acesso .........: usuario.bat criar|senha|remover|listar (menu Iniciar > AGHUse)"
    $t += "Conta de servico LDAP ....: $LDAP_BIND_DN / $LDAP_BIND_SENHA"
    $t += 'Administracao do LDAP ....: qualquer Administrador do Windows (ldp.exe ou usuario.bat)'
  }
  $t += ''
  $t += 'Arquivos de configuracao com senhas:'
  $t += "  $XML"
  $t += "  $PROPS"
  [IO.File]::WriteAllText($CRED, (($t -join "`r`n") + "`r`n"), $UTF8_SEM_BOM)

  Write-Host ''
  Write-Host '  ===================================================================' -ForegroundColor Green
  Write-Host "   AGHUse instalado com sucesso$(if ($VARIANTE_DESCRICAO) { ' - ' + $VARIANTE_DESCRICAO })" -ForegroundColor Green
  Write-Host '  ===================================================================' -ForegroundColor Green
  Write-Host "   Acesso .............: $URL_LOCAL (neste computador)"
  Write-Host "   Na rede ............: $URL"
  Write-Host "   Usuario ............: $ADMIN_LOGIN"
  if ($MODO_LOGIN -eq 'ldap-externo') { Write-Host "   Senha ..............: $NOTA_ADMIN" }
  else { Write-Host "   Senha ..............: gravada em $CRED" }
  Write-Host "   Credenciais ........: $CRED (somente Administradores)"
  Write-Host "   Servicos ...........: $SERVICO e $PG_SERVICO (services.msc)"
  Write-Host "   Log da aplicacao ...: $WFD\standalone\log\server.log"
  Write-Host "   Log da instalacao ..: $LOG"
  Write-Host "RESULTADO_URL=$URL"
  Write-Host "RESULTADO_URL_LOCAL=$URL_LOCAL"
  Write-Host "RESULTADO_CRED=$CRED"
  if ($AMBIENTE -eq 'teste') {
    Write-Host ''
    Write-Host "   Ambiente de TESTE. Antes de qualquer uso com dados reais, leia a secao" -ForegroundColor Yellow
    Write-Host "   'Uso em producao' do README.md." -ForegroundColor Yellow
  } else {
    Write-Host ''
    Write-Host '   Producao: publique o sistema apenas atras de um proxy reverso com HTTPS' -ForegroundColor Yellow
    Write-Host "   e conclua a lista de verificacao da secao 'Uso em producao' do README.md." -ForegroundColor Yellow
  }
}
catch {
  Write-Host ''
  Write-Host "$($_.Exception.Message)" -ForegroundColor Red
  Write-Host "Falha na etapa: $ETAPA_ATUAL. Consulte o log: $LOG" -ForegroundColor Red
  if ($_.InvocationInfo -and $_.Exception.Message -notlike 'ERRO:*') { Write-Host $_.InvocationInfo.PositionMessage -ForegroundColor DarkGray }
  $CODIGO_SAIDA = 1
}
finally {
  Remove-Item Env:\PGPASSWORD -ErrorAction SilentlyContinue
  if ($TMPD -and (Test-Path -LiteralPath $TMPD)) { Remove-Item -LiteralPath $TMPD -Recurse -Force -ErrorAction SilentlyContinue }
  try { Stop-Transcript | Out-Null } catch { }
}
exit $CODIGO_SAIDA
