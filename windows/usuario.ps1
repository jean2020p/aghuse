###############################################################################
#  AGHUse - contas de acesso (login e senha) - Windows
#
#  O AGHUse nao armazena senhas: a senha de cada usuario fica no diretorio.
#  Este comando cria e mantem as contas desta instalacao:
#    - MODO_LOGIN=ldap-local (padrao): no LDAP local (AD LDS, servico ADAM_<SERVICO>ldap);
#    - MODO_LOGIN=banco: no PostgreSQL (banco vazio aghuse_login, sem acesso aos dados);
#    - MODO_LOGIN=ldap-externo: as contas sao administradas no Active Directory.
#  O cadastro do usuario, da pessoa, do vinculo e dos perfis e feito na aplicacao.
#
#  Uso (como Administrador):
#        usuario.bat criar   LOGIN ["NOME COMPLETO"] [email@instituicao.org.br]
#        usuario.bat senha   LOGIN          (redefine a senha)
#        usuario.bat remover LOGIN
#        usuario.bat listar
#  A senha e solicitada (minimo 8 caracteres); se ficar em branco, e gerada uma
#  senha aleatoria e exibida uma unica vez.
###############################################################################
param(
  [Parameter(Position = 0)][string]$Acao = '',
  [Parameter(Position = 1)][string]$Login = '',
  [Parameter(Position = 2)][string]$Nome = '',
  [Parameter(Position = 3)][string]$Email = '',
  [string]$Conf = '',
  [string]$Senha = ''      # uso nao interativo (testes/automacao)
)
. (Join-Path $PSScriptRoot 'lib\comum.ps1')
. (Join-Path $PSScriptRoot 'lib\ldaplocal.ps1')
if (-not $Conf) { $Conf = Join-Path $PSScriptRoot 'aghuse.conf' }
$TMPD = $null
$codigo = 0
try {
  Exigir-Admin 'usuario.bat'
  $C = Ler-Conf $Conf
  foreach ($k in $C.Keys) { Set-Variable -Name $k -Value $C[$k] }
  if ($MODO_LOGIN -eq 'ldap-externo') { erro 'MODO_LOGIN=ldap-externo: as contas e senhas sao administradas no LDAP/Active Directory da instituicao.' }
  if ($MODO_LOGIN -notin @('ldap-local', 'banco')) { erro "MODO_LOGIN invalido no ${Conf}: use 'ldap-local', 'banco' ou 'ldap-externo'." }
  $uso = 'Uso: usuario.bat criar LOGIN ["NOME"] [email]  |  senha LOGIN  |  remover LOGIN  |  listar'
  if ($Acao -notin @('criar', 'senha', 'remover', 'listar')) { erro $uso }
  if ($Acao -ne 'listar') {
    if (-not $Login) { erro $uso }
    if ($Login -notmatch '^[A-Za-z0-9_.-]{2,64}$') { erro 'login invalido: use letras, numeros, ponto, hifen ou sublinhado.' }
  }
  if ($Nome -match '["<>]' -or $Email -match '["<>\s]') { erro 'nome ou e-mail com caracteres invalidos.' }
  $PREFIXO = $PREFIXO.TrimEnd('\')
  $LMAI = $Login.ToUpper(); $LMIN = $Login.ToLower()

  $script:SENHA_GERADA = $false
  function Ler-Senha {
    if ($Senha) { $s1 = $Senha }
    elseif ([Environment]::UserInteractive -and -not [Console]::IsInputRedirected) {
      $a = Read-Host -AsSecureString "Nova senha para $LMAI (minimo 8 caracteres; Enter para gerar automaticamente)"
      $s1 = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($a))
      if ($s1) {
        $b = Read-Host -AsSecureString 'Repita a senha'
        $s2 = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($b))
        if ($s1 -cne $s2) { erro 'as senhas nao conferem.' }
      }
    } else { $s1 = '' }
    if (-not $s1) { $script:SENHA_GERADA = $true; return (Gerar-SenhaForte 12) }
    if ($s1.Length -lt 8) { erro 'a senha deve ter no minimo 8 caracteres.' }
    if ($s1.Contains('"')) { erro 'a senha nao pode conter aspas (").' }
    return $s1
  }
  function Mostrar-Senha([string]$s) {
    if ($script:SENHA_GERADA) {
      Write-Host "  Senha gerada: $s"
      Write-Host '  (anote e entregue ao usuario por meio seguro; ela nao sera exibida novamente)'
    }
  }
  function Proximos-Passos {
    Write-Host @"

  Proximo passo, na aplicacao (usuario com perfil de administrador):
    1. Pessoa  : Reg. Colaboradores > Administracao de Pessoal > Administrar Servidores > Pessoas
    2. Servidor: Reg. Colaboradores > Administracao de Pessoal > Administrar Servidores > Servidores
                 (pessoa, vinculo, matricula e inicio do vinculo)
    3. Usuario : Outros Modulos > Configuracao > Acesso > Usuario > Pesquisar pela matricula >
                 Criar Login "$LMAI" > e-mail > Gravar; depois Editar Perfil (ao menos um perfil)
  O login so e aceito apos as tres etapas.
  Passo a passo completo: $PREFIXO\ferramentas\CADASTRO_DE_USUARIOS.md (menu Iniciar > AGHUse)
"@
  }

  if ($MODO_LOGIN -eq 'ldap-local') {
    # ------------------------------------------------------------ LDAP local (AD LDS)
    $svc = LdapLocal-Servico $SERVICO
    $s = Get-Service -Name $svc -ErrorAction SilentlyContinue
    if (-not $s) { erro "o servico $svc (LDAP local) nao existe. A instalacao foi concluida?" }
    if ($s.Status -ne 'Running') { Start-Service -Name $svc; Start-Sleep -Seconds 3 }
    $pr = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\$svc\Parameters" -ErrorAction SilentlyContinue
    $LP = [int]$LDAP_LOCAL_PORTA
    if ($pr -and $pr.PSObject.Properties['Port LDAP']) { $LP = [int]$pr.'Port LDAP' }
    Write-Host "LDAP local (AD LDS, porta $LP): a senha fica no diretorio deste computador."
    $c = Ldap-Conectar $LP
    try {
      $dn = LdapLocal-DnUsuario $LMAI
      switch ($Acao) {
        'criar' {
          if (Ldap-Existe $c $dn) { erro "a conta $LMAI ja existe (use: usuario.bat senha $LMAI)." }
          $pw = Ler-Senha
          [void](Ldap-CriarUsuario $c $LMAI $pw $Nome $Email)
          Write-Host "Conta $LMAI criada ($dn)."; Mostrar-Senha $pw; Proximos-Passos
        }
        'senha' {
          if (-not (Ldap-Existe $c $dn)) { erro "a conta $LMAI nao existe." }
          $pw = Ler-Senha; Ldap-DefinirSenha $c $dn $pw; Ldap-AdicionarLeitor $c $dn
          Write-Host "Senha de $LMAI redefinida."; Mostrar-Senha $pw
        }
        'remover' {
          if (-not (Ldap-Existe $c $dn)) { erro "a conta $LMAI nao existe." }
          Ldap-Excluir $c $dn
          Write-Host "Conta $LMAI removida. Inative tambem o usuario na aplicacao."
        }
        'listar' {
          foreach ($e in (Ldap-Buscar $c $LDAP_LOCAL_PESSOAS '(objectClass=inetOrgPerson)' ([string[]]@('uid', 'displayName', 'mail')))) {
            $linha = '  {0,-20} {1,-35} {2}' -f (Ldap-Valor $e 'uid'), (Ldap-Valor $e 'displayName'), (Ldap-Valor $e 'mail')
            Write-Host $linha.TrimEnd()
          }
        }
      }
    } finally { $c.Dispose() }
  } else {
    # ------------------------------------------------------------ modo banco (PostgreSQL)
    $PG_BIN = Join-Path $PREFIXO 'pgsql\bin'
    $PG_PORTA = Porta-PgDados (Join-Path $PREFIXO 'pgdata')
    $arq = Arquivo-SenhaPostgres $SERVICO
    if (-not $PG_SENHA_POSTGRES) {
      if (-not (Test-Path -LiteralPath $arq)) { erro "senha do usuario postgres nao encontrada em $arq (a instalacao foi concluida?)." }
      $PG_SENHA_POSTGRES = ([IO.File]::ReadAllText($arq)).Trim()
    }
    $env:PGPASSWORD = $PG_SENHA_POSTGRES
    $env:PGOPTIONS = '-c client_min_messages=warning'
    $TMPD = Novo-DirTemp
    function Existe([string]$r) { return [bool]((Psql -Valor -Sql "select 1 from pg_roles where rolname='$r'") -join '') }
    function Definir([string]$s) {
      $q = $s.Replace("'", "''")
      foreach ($r in @($LMAI, $LMIN) | Select-Object -Unique) {
        [void](Psql -Sql @"
DO `$`$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='$r') THEN CREATE ROLE "$r" LOGIN; END IF; END `$`$;
SET password_encryption = 'scram-sha-256';
ALTER ROLE "$r" PASSWORD '$q';
REVOKE ALL ON DATABASE "$DB_NOME" FROM "$r";
GRANT CONNECT ON DATABASE "aghuse_login" TO "$r";
"@)
      }
    }
    Write-Host 'Modo de avaliacao (MODO_LOGIN=banco): a senha e conferida pelo PostgreSQL.'
    switch ($Acao) {
      'criar' {
        if (Existe $LMAI) { erro "a conta $Login ja existe (use: usuario.bat senha $Login)." }
        $s = Ler-Senha; Definir $s; Write-Host "Conta $LMAI criada."; Mostrar-Senha $s; Proximos-Passos
      }
      'senha' {
        if (-not (Existe $LMAI)) { erro "a conta $Login nao existe." }
        $s = Ler-Senha; Definir $s; Write-Host "Senha de $LMAI redefinida."; Mostrar-Senha $s
      }
      'remover' {
        if (-not (Existe $LMAI)) { erro "a conta $Login nao existe." }
        foreach ($r in @($LMAI, $LMIN) | Select-Object -Unique) {
          if (Existe $r) { [void](Psql -Sql "REVOKE ALL ON DATABASE `"$DB_NOME`" FROM `"$r`"; REVOKE ALL ON DATABASE `"aghuse_login`" FROM `"$r`"; DROP ROLE `"$r`";") }
        }
        Write-Host "Conta $LMAI removida. Inative tambem o usuario na aplicacao."
      }
      'listar' {
        $l = Psql -Valor -Sql "select r.rolname from pg_roles r where r.rolcanlogin and has_database_privilege(r.rolname,'aghuse_login','CONNECT') and r.rolname = upper(r.rolname) and r.rolname not in ('$DB_USUARIO','$DB_USUARIO_FIT','postgres') order by 1"
        foreach ($x in $l) { Write-Host "  $x" }
      }
    }
  }
}
catch { Write-Host $_.Exception.Message -ForegroundColor Red; $codigo = 1 }
finally {
  Remove-Item Env:\PGPASSWORD -ErrorAction SilentlyContinue
  if ($TMPD -and (Test-Path -LiteralPath $TMPD)) { Remove-Item -LiteralPath $TMPD -Recurse -Force -ErrorAction SilentlyContinue }
}
exit $codigo
