#!/usr/bin/env bash
###############################################################################
#  Instalador AGHUse 13.250-STABLE
#  Uso:  sudo ./instalar.sh [arquivo.conf]      (padrao: ./aghuse.conf)
#
#  Instala e configura: OpenJDK 17, WildFly 26.1.3, PostgreSQL, base inicial
#  do AGHUse, autenticacao (banco, LDAP local ou LDAP/AD externo) e o servico
#  systemd. Distribuido para fins de TESTE e ESTUDO, sem garantia e sem suporte.
###############################################################################
set -Eeuo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF="${1:-$DIR/aghuse.conf}"
VERSAO_AGHUSE="13.250-STABLE"
WILDFLY_NOME="wildfly-26.1.3.Final"
JDK_NOME="jdk-17.0.2"

# ----------------------------------------------------------------------------
# utilitarios
# ----------------------------------------------------------------------------
C_AZUL=$'\e[1;34m'; C_VERDE=$'\e[1;32m'; C_AMAR=$'\e[1;33m'; C_VERM=$'\e[1;31m'; C_FIM=$'\e[0m'
ETAPA_ATUAL="inicio"
etapa() { ETAPA_ATUAL="$1"; echo; echo "${C_AZUL}==> $1${C_FIM}"; }
info()  { echo "    $*"; }
aviso() { echo "${C_AMAR}    AVISO: $*${C_FIM}"; }
erro()  { echo "${C_VERM}ERRO: $*${C_FIM}" >&2; exit 1; }
trap 'echo "${C_VERM}Falha na etapa: ${ETAPA_ATUAL} (linha $LINENO). Consulte o log: ${LOG:-}${C_FIM}" >&2' ERR

gerar_senha() {  # 32 caracteres [A-Za-z0-9] a partir de /dev/urandom
  local s=""
  while [ "${#s}" -lt 32 ]; do s="$s$(head -c 96 /dev/urandom | base64 -w0 | tr -dc 'A-Za-z0-9')"; done
  printf '%s\n' "${s:0:32}"
}

declare -A GERADAS=()
senha_param() {  # senha_param NOME_VARIAVEL
  local nome="$1" valor="${!1}" minimo=16
  [ "$AMBIENTE" = "producao" ] && minimo=20
  if [ -z "$valor" ]; then
    printf -v "$nome" '%s' "$(gerar_senha)"
    GERADAS[$nome]=1
  else
    [[ "$valor" =~ ^[A-Za-z0-9]+$ ]] || erro "$nome deve conter apenas letras e numeros."
    [ "${#valor}" -ge "$minimo" ] || erro "$nome deve ter no minimo $minimo caracteres (ou deixe em branco para gerar automaticamente)."
  fi
}

nome_valido() {  # nome_valido ROTULO VALOR
  [[ "$2" =~ ^[a-z_][a-z0-9_]{0,62}$ ]] || erro "$1 invalido: '$2' (use letras minusculas, numeros e _)."
}

psql_pg() { (cd /tmp && runuser -u postgres -- env PGOPTIONS="-c client_min_messages=warning" psql -X -q -v ON_ERROR_STOP=1 -p "$PG_PORTA" "$@"); }

obter_arquivo() {  # obter_arquivo URL SHA256 -> imprime caminho local
  local url="$1" sha="$2" nome destino
  nome="$(basename "$url")"
  destino="$(find "$DIR/dependencias" -type f -name "$nome" 2>/dev/null | sed -n 1p)"
  if [ -n "$destino" ]; then
    info "usando $nome da pasta dependencias" >&2
  else
    destino="$TMPD/$nome"
    info "baixando $nome (nao encontrado em dependencias/) ..." >&2
    curl -fsSL --retry 3 --connect-timeout 30 -o "$destino" "$url" || erro "falha no download de $url"
  fi
  echo "$sha  $destino" | sha256sum -c --quiet - >&2 || erro "hash SHA-256 nao confere: $nome"
  echo "$destino"
}

# ----------------------------------------------------------------------------
# 0. parametros e verificacoes
# ----------------------------------------------------------------------------
[ "$(id -u)" -eq 0 ] || erro "execute como root:  sudo ./instalar.sh"
[ -f "$CONF" ] || erro "arquivo de parametros nao encontrado: $CONF"
# shellcheck disable=SC1090
source "$CONF"

LOG="/var/log/aghuse-instalador-${SERVICO}.log"
exec > >(tee -a "$LOG") 2>&1
TMPD="$(mktemp -d /tmp/aghuse-inst.XXXXXX)"
trap 'rm -rf "$TMPD"' EXIT

echo "${C_VERDE}"
echo "  ==================================================================="
echo "   AGHUse $VERSAO_AGHUSE - instalador"
echo "   Distribuido para TESTE e ESTUDO do sistema. Sem garantia e sem suporte."
echo "  ==================================================================="
echo "${C_FIM}  $(date '+%d/%m/%Y %H:%M:%S')   log: $LOG"

etapa "Verificando parametros e requisitos"
case "$AMBIENTE" in teste|producao) ;; *) erro "AMBIENTE deve ser 'teste' ou 'producao'." ;; esac
case "$MODO_LOGIN" in banco|ldap-local|ldap-externo) ;; *) erro "MODO_LOGIN deve ser 'banco', 'ldap-local' ou 'ldap-externo'." ;; esac
case "$RECRIAR_BANCO" in sim|nao) ;; *) erro "RECRIAR_BANCO deve ser 'sim' ou 'nao'." ;; esac

if [ "$AMBIENTE" = "producao" ]; then
  [ "$CONFIRMO_PRODUCAO" = "sim" ] || erro "AMBIENTE=producao exige CONFIRMO_PRODUCAO=\"sim\" (leia a secao 'Uso em producao' do README.md)."
  [ "$MODO_LOGIN" != "ldap-local" ] || erro "MODO_LOGIN=ldap-local destina-se apenas a testes. Em producao use 'ldap-externo' ou 'banco'."
fi

[[ "$ADMIN_LOGIN" =~ ^[A-Za-z0-9_.-]+$ ]] || erro "ADMIN_LOGIN invalido."
[[ "$SERVICO" =~ ^[a-z0-9][a-z0-9_-]*$ ]] || erro "SERVICO invalido."
[[ "$USUARIO_SO" =~ ^[a-z_][a-z0-9_-]*$ ]] || erro "USUARIO_SO invalido."
[[ "$PORT_OFFSET" =~ ^[0-9]+$ ]] || erro "PORT_OFFSET deve ser numerico."
[[ "$PG_VERSAO" =~ ^[0-9]+$ ]] || erro "PG_VERSAO deve ser numerico (ex.: 15)."
[ -z "$PG_PORTA" ] || [[ "$PG_PORTA" =~ ^[0-9]+$ ]] || erro "PG_PORTA deve ser numerica."
nome_valido DB_NOME "$DB_NOME"; nome_valido DB_USUARIO "$DB_USUARIO"; nome_valido DB_USUARIO_FIT "$DB_USUARIO_FIT"
[[ "$PREFIXO" =~ ^/[A-Za-z0-9/_.-]+$ ]] || erro "PREFIXO deve ser um caminho absoluto."

if [ "$MODO_LOGIN" = "ldap-externo" ]; then
  [ -n "$LDAP_HOST" ] || erro "informe LDAP_HOST para MODO_LOGIN=ldap-externo."
  [ -n "$LDAP_USER_DN" ] && [[ "$LDAP_USER_DN" == *%s* ]] || erro "LDAP_USER_DN deve conter %s (ex.: %s@instituicao.local)."
  [[ "$LDAP_PORTA" =~ ^[0-9]+$ ]] || erro "LDAP_PORTA deve ser numerica."
fi

. /etc/os-release
case "${ID:-}" in
  ubuntu|debian) info "sistema: $PRETTY_NAME" ;;
  *) erro "sistema nao suportado (${PRETTY_NAME:-desconhecido}). Use Ubuntu 22.04/24.04 ou Debian 12." ;;
esac
[ "$(uname -m)" = "x86_64" ] || erro "arquitetura nao suportada: $(uname -m) (requer x86_64)."

RAM_GB=$(awk '/MemTotal/{print int($2/1048576+0.5)}' /proc/meminfo)
[ "$RAM_GB" -ge 8 ] || erro "memoria insuficiente: ${RAM_GB} GB (minimo 8 GB; recomendado 16 GB)."
if [ -z "$MEMORIA_JVM" ]; then
  if [ "$RAM_GB" -ge 12 ]; then MEMORIA_JVM="5G"; else MEMORIA_JVM="4G"; fi
fi
[[ "$MEMORIA_JVM" =~ ^[0-9]+[GgMm]$ ]] || erro "MEMORIA_JVM invalida (ex.: 5G)."
MEM_MB=${MEMORIA_JVM%[GgMm]}; [[ "$MEMORIA_JVM" =~ [Gg]$ ]] && MEM_MB=$(( MEM_MB * 1024 ))
[ "$MEM_MB" -ge 4096 ] || erro "MEMORIA_JVM=$MEMORIA_JVM insuficiente: o AGHUse exige no minimo 4G (recomendado 5G)."
info "memoria: ${RAM_GB} GB na maquina, ${MEMORIA_JVM} para o WildFly"
[ "$MEM_MB" -ge 5120 ] || aviso "o AGHUse recomenda 5G para o WildFly; com ${MEMORIA_JVM} o desempenho pode ser limitado."

mkdir -p "$PREFIXO"
LIVRE_GB=$(df -Pk "$PREFIXO" | awk 'NR==2{print int($4/1048576)}')
[ "$LIVRE_GB" -ge 15 ] || erro "espaco livre insuficiente em $PREFIXO: ${LIVRE_GB} GB (minimo 15 GB; recomendado 100 GB)."
[ "$LIVRE_GB" -ge 40 ] || aviso "espaco livre de ${LIVRE_GB} GB; recomendado 100 GB para dados, logs e backups."

etapa "Conferindo integridade do pacote"
# arquivos grandes podem vir divididos em partes (<nome>.parte-001, -002 ...): reconstroi
while IFS= read -r p1; do
  alvo="${p1%.parte-001}"
  if [ ! -f "$alvo" ]; then
    info "reconstruindo $(basename "$alvo") a partir das partes"
    cat "$alvo".parte-[0-9][0-9][0-9] > "$alvo.tmp" && mv "$alvo.tmp" "$alvo"
  fi
done < <(find "$DIR/pacote" "$DIR/dependencias" -type f -name '*.parte-001' 2>/dev/null | sort)
for f in aghu.ear dbaghu.dmp wildfly-aghuse-overlay.tar.gz wildfly-aghuse-removidos.txt SHA256SUMS; do
  [ -f "$DIR/pacote/$f" ] || erro "arquivo ausente: pacote/$f"
done
(cd "$DIR/pacote" && sha256sum -c --quiet SHA256SUMS) || erro "pacote corrompido (SHA256SUMS nao confere)."
info "pacote integro"
if [ -f "$DIR/dependencias/SHA256SUMS" ]; then
  (cd "$DIR/dependencias" && sha256sum -c --quiet SHA256SUMS) || erro "pasta dependencias corrompida (SHA256SUMS nao confere)."
  info "dependencias integras"
fi

# senhas (geradas quando vazias)
senha_param DB_SENHA
senha_param DB_SENHA_FIT
if [ "$MODO_LOGIN" != "ldap-externo" ]; then
  ADMIN_SENHA_INFORMADA="${ADMIN_SENHA}"
  senha_param ADMIN_SENHA
fi

# ----------------------------------------------------------------------------
# 1. pacotes do sistema
# ----------------------------------------------------------------------------
etapa "Instalando pacotes do sistema"
export DEBIAN_FRONTEND=noninteractive
# Repositorio apt local (dependencias/apt/<sistema>-<versao>): instalacao sem internet.
APT_LOCAL="$DIR/dependencias/apt/${ID}-${VERSION_ID}"
APT_OPTS=()
if [ -f "$APT_LOCAL/Packages" ]; then
  mkdir -p "$TMPD/lists/partial"
  echo "deb [trusted=yes] file:$APT_LOCAL ./" > "$TMPD/local.list"
  APT_OPTS=(-o "Dir::Etc::sourcelist=$TMPD/local.list" -o "Dir::Etc::sourceparts=-"
            -o "Dir::State::Lists=$TMPD/lists" -o "APT::Get::List-Cleanup=0"
            -o "APT::Sandbox::User=root")
  apt-get "${APT_OPTS[@]}" update -qq
  info "usando o repositorio local de pacotes (dependencias/apt/${ID}-${VERSION_ID})"
else
  apt-get update -qq
  info "repositorio local nao disponivel para ${ID}-${VERSION_ID}: pacotes serao baixados da internet"
fi
apt_instalar() { apt-get "${APT_OPTS[@]}" install -y -qq --no-install-recommends "$@" >/dev/null; }
apt_instalar curl ca-certificates unzip python3

# ----------------------------------------------------------------------------
# 2. PostgreSQL
# ----------------------------------------------------------------------------
etapa "PostgreSQL $PG_VERSAO"
if ! dpkg -s "postgresql-$PG_VERSAO" >/dev/null 2>&1; then
  if [ "${#APT_OPTS[@]}" -eq 0 ] && ! apt-cache policy "postgresql-$PG_VERSAO" 2>/dev/null | grep 'Candidate: [0-9]' >/dev/null; then
    info "habilitando o repositorio oficial do PostgreSQL (apt.postgresql.org)"
    apt_instalar postgresql-common gnupg lsb-release
    /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh -y >/dev/null
  fi
  apt_instalar "postgresql-$PG_VERSAO" "postgresql-client-$PG_VERSAO"
  info "postgresql-$PG_VERSAO instalado"
else
  info "postgresql-$PG_VERSAO ja instalado"
fi

CLUSTER="$(pg_lsclusters -h | awk -v v="$PG_VERSAO" '$1==v{print $2; exit}')"
if [ -z "$CLUSTER" ]; then
  CLUSTER="main"
  if [ -n "$PG_PORTA" ]; then pg_createcluster "$PG_VERSAO" main --port "$PG_PORTA" >/dev/null
  else pg_createcluster "$PG_VERSAO" main >/dev/null; fi
fi
PORTA_ATUAL="$(pg_lsclusters -h | awk -v v="$PG_VERSAO" -v c="$CLUSTER" '$1==v && $2==c{print $3}')"
if [ -n "$PG_PORTA" ] && [ "$PG_PORTA" != "$PORTA_ATUAL" ]; then
  pg_conftool "$PG_VERSAO" "$CLUSTER" set port "$PG_PORTA"
  pg_ctlcluster "$PG_VERSAO" "$CLUSTER" restart || true
fi
PG_PORTA="$(pg_lsclusters -h | awk -v v="$PG_VERSAO" -v c="$CLUSTER" '$1==v && $2==c{print $3}')"
pg_ctlcluster "$PG_VERSAO" "$CLUSTER" start 2>/dev/null || true
systemctl enable -q postgresql
pg_lsclusters -h | awk -v v="$PG_VERSAO" -v c="$CLUSTER" '$1==v && $2==c && $4!="online"{exit 1}' \
  || erro "o cluster PostgreSQL $PG_VERSAO/$CLUSTER nao iniciou."
info "cluster $PG_VERSAO/$CLUSTER ativo na porta $PG_PORTA (somente conexoes locais)"

# ----------------------------------------------------------------------------
# 3. banco do AGHUse
# ----------------------------------------------------------------------------
etapa "Banco de dados $DB_NOME"
psql_pg <<SQL
DO \$\$ DECLARE r text; BEGIN
FOREACH r IN ARRAY ARRAY['acesso_completo','acesso_leitura','escrita_integra','ugen_bi','ugen_pesquisa','ugen_surex','agh'] LOOP
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname=r) THEN EXECUTE format('CREATE ROLE %I', r); END IF;
END LOOP; END \$\$;
DO \$\$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='$DB_USUARIO') THEN CREATE ROLE "$DB_USUARIO" LOGIN; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='$DB_USUARIO_FIT') THEN CREATE ROLE "$DB_USUARIO_FIT" LOGIN; END IF;
END \$\$;
SET password_encryption = 'scram-sha-256';
ALTER ROLE "$DB_USUARIO" PASSWORD '$DB_SENHA';
ALTER ROLE "$DB_USUARIO_FIT" PASSWORD '$DB_SENHA_FIT';
GRANT acesso_completo TO "$DB_USUARIO", "$DB_USUARIO_FIT";
SQL

EXISTE_DB="$(psql_pg -Atc "select 1 from pg_database where datname='$DB_NOME'")"
if [ -n "$EXISTE_DB" ] && [ "$RECRIAR_BANCO" = "sim" ]; then
  systemctl stop "$SERVICO" 2>/dev/null || true
  info "apagando o banco $DB_NOME (RECRIAR_BANCO=sim)"
  psql_pg -c "DROP DATABASE \"$DB_NOME\" WITH (FORCE)"
  EXISTE_DB=""
fi
if [ -z "$EXISTE_DB" ]; then
  psql_pg -c "CREATE DATABASE \"$DB_NOME\" WITH TEMPLATE template0 ENCODING 'UTF8' OWNER postgres"
  DUMP="/var/lib/postgresql/aghuse-base-$$.dmp"
  install -o postgres -m 600 "$DIR/pacote/dbaghu.dmp" "$DUMP"
  JOBS=$(nproc); [ "$JOBS" -gt 8 ] && JOBS=8
  info "restaurando a base inicial ($JOBS processos paralelos; pode levar de 10 a 45 minutos) ..."
  INICIO=$(date +%s)
  if ! (cd /tmp && runuser -u postgres -- pg_restore -p "$PG_PORTA" -d "$DB_NOME" -j "$JOBS" --no-tablespaces "$DUMP"); then
    rm -f "$DUMP"; erro "falha ao restaurar a base inicial."
  fi
  rm -f "$DUMP"
  info "base restaurada em $(( ($(date +%s) - INICIO) / 60 )) min"
else
  info "banco $DB_NOME ja existe - dados preservados (RECRIAR_BANCO=nao)"
fi
psql_pg -d "$DB_NOME" -Atc "select count(*) from casca.csc_usuario where login=upper('$ADMIN_LOGIN')" | grep '^1$' >/dev/null \
  || aviso "o usuario $ADMIN_LOGIN nao foi encontrado em casca.csc_usuario."

# ----------------------------------------------------------------------------
# 4. autenticacao
# ----------------------------------------------------------------------------
etapa "Autenticacao: $MODO_LOGIN"
NOTA_ADMIN=""
case "$MODO_LOGIN" in
  banco)
    ADMIN_MIN="$(echo "$ADMIN_LOGIN" | tr '[:upper:]' '[:lower:]')"
    for r in "$ADMIN_LOGIN" "$ADMIN_MIN"; do
      psql_pg <<SQL
DO \$\$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='$r') THEN CREATE ROLE "$r" LOGIN; END IF; END \$\$;
SET password_encryption = 'scram-sha-256';
ALTER ROLE "$r" PASSWORD '$ADMIN_SENHA';
GRANT CONNECT ON DATABASE "$DB_NOME" TO "$r";
SQL
    done
    info "senha do $ADMIN_LOGIN definida no PostgreSQL (logins '$ADMIN_LOGIN' e '$ADMIN_MIN')"
    LDAP_HOST=""; LDAP_PORTA="389"; LDAP_USER_DN=""; LDAP_BASE_USUARIOS=""; LDAP_ATRIBUTO_LOGIN=""
    LDAP_FILTRO=""; LDAP_BIND_DN=""; LDAP_BIND_SENHA=""
    ;;
  ldap-local)
    BASE="dc=$(echo "$LDAP_LOCAL_DOMINIO" | sed 's/\./,dc=/g')"
    apt_instalar ldap-utils
    if ! dpkg -s slapd >/dev/null 2>&1; then
      senha_param LDAP_LOCAL_ADMIN_SENHA
      debconf-set-selections <<EOF
slapd slapd/no_configuration boolean false
slapd slapd/domain string $LDAP_LOCAL_DOMINIO
slapd shared/organization string AGHUse
slapd slapd/password1 password $LDAP_LOCAL_ADMIN_SENHA
slapd slapd/password2 password $LDAP_LOCAL_ADMIN_SENHA
slapd slapd/purge_database boolean true
slapd slapd/move_old_database boolean true
EOF
      apt_instalar slapd
      sed -i 's#^SLAPD_SERVICES=.*#SLAPD_SERVICES="ldap://127.0.0.1:389/ ldapi:///"#' /etc/default/slapd
      systemctl restart slapd
      info "OpenLDAP instalado (base $BASE, somente 127.0.0.1)"
    else
      [ -n "$LDAP_LOCAL_ADMIN_SENHA" ] || erro "o OpenLDAP ja esta instalado: informe LDAP_LOCAL_ADMIN_SENHA (senha de cn=admin,$BASE)."
      info "OpenLDAP ja instalado - usando a base $BASE"
    fi
    systemctl enable -q slapd 2>/dev/null || true
    ldapwhoami -x -H ldap://127.0.0.1 -D "cn=admin,$BASE" -w "$LDAP_LOCAL_ADMIN_SENHA" >/dev/null \
      || erro "nao foi possivel autenticar cn=admin,$BASE no OpenLDAP local (base ou senha incorretas)."
    if ! ldapsearch -x -LLL -H ldap://127.0.0.1 -b "ou=people,$BASE" -s base dn >/dev/null 2>&1; then
      printf 'dn: ou=people,%s\nobjectClass: organizationalUnit\nou: people\n' "$BASE" \
        | ldapadd -x -H ldap://127.0.0.1 -D "cn=admin,$BASE" -w "$LDAP_LOCAL_ADMIN_SENHA" >/dev/null
    fi
    UDN="uid=$ADMIN_LOGIN,ou=people,$BASE"
    if ldapsearch -x -LLL -H ldap://127.0.0.1 -b "$UDN" -s base dn >/dev/null 2>&1; then
      if [ -n "$ADMIN_SENHA_INFORMADA" ] || [ -n "${GERADAS[ADMIN_SENHA]:-}" ]; then
        ldappasswd -x -H ldap://127.0.0.1 -D "cn=admin,$BASE" -w "$LDAP_LOCAL_ADMIN_SENHA" -s "$ADMIN_SENHA" "$UDN" >/dev/null
        info "senha do usuario $UDN redefinida"
      fi
    else
      HASH="$(slappasswd -s "$ADMIN_SENHA")"
      printf 'dn: %s\nobjectClass: inetOrgPerson\nuid: %s\ncn: Administrador AGHUse\nsn: %s\nuserPassword: %s\n' \
        "$UDN" "$ADMIN_LOGIN" "$ADMIN_LOGIN" "$HASH" \
        | ldapadd -x -H ldap://127.0.0.1 -D "cn=admin,$BASE" -w "$LDAP_LOCAL_ADMIN_SENHA" >/dev/null
      info "usuario $UDN criado"
    fi
    ldapwhoami -x -H ldap://127.0.0.1 -D "$UDN" -w "$ADMIN_SENHA" >/dev/null || erro "falha no teste de login LDAP do $ADMIN_LOGIN."
    LDAP_HOST="127.0.0.1"; LDAP_PORTA="389"
    LDAP_USER_DN="uid=%s,ou=people,$BASE"; LDAP_BASE_USUARIOS="ou=people,$BASE"
    LDAP_ATRIBUTO_LOGIN="uid"; LDAP_FILTRO="(&(objectClass=inetOrgPerson)(uid=%s))"
    LDAP_BIND_DN="cn=admin,$BASE"; LDAP_BIND_SENHA="$LDAP_LOCAL_ADMIN_SENHA"
    ;;
  ldap-externo)
    apt_instalar ldap-utils
    H1="${LDAP_HOST%%,*}"; H1="${H1// /}"
    if timeout 5 bash -c "</dev/tcp/$H1/$LDAP_PORTA" 2>/dev/null; then
      info "servidor LDAP $H1:$LDAP_PORTA acessivel"
    else
      aviso "nao foi possivel conectar em $H1:$LDAP_PORTA. Verifique rede/firewall; o login so funcionara com o servidor acessivel."
    fi
    NOTA_ADMIN="a senha e a do LDAP/AD; o login '$ADMIN_LOGIN' precisa existir no diretorio"
    ;;
esac

# ----------------------------------------------------------------------------
# 5. Java
# ----------------------------------------------------------------------------
etapa "OpenJDK 17.0.2"
if [ ! -x "$PREFIXO/$JDK_NOME/bin/java" ]; then
  ARQ="$(obter_arquivo "$JDK_URL" "$JDK_SHA256")"
  tar xzf "$ARQ" -C "$PREFIXO"
fi
ln -sfn "$PREFIXO/$JDK_NOME" "$PREFIXO/jdk"
"$PREFIXO/jdk/bin/java" -version 2>&1 | sed -n '1s/^/    /p'

# ----------------------------------------------------------------------------
# 6. WildFly + AGHUse
# ----------------------------------------------------------------------------
etapa "WildFly 26.1.3 e aplicacao AGHUse"
id "$USUARIO_SO" >/dev/null 2>&1 || useradd -r -s /usr/sbin/nologin -d "$PREFIXO" "$USUARIO_SO"
if systemctl list-unit-files "$SERVICO.service" >/dev/null 2>&1; then systemctl stop "$SERVICO" 2>/dev/null || true; fi

WFD="$PREFIXO/$WILDFLY_NOME"
if [ -d "$WFD" ]; then
  mkdir -p "$PREFIXO/backup"
  BK="$PREFIXO/backup/wildfly-config-$(date +%Y%m%d-%H%M%S).tar.gz"
  tar czf "$BK" -C "$WFD" standalone/configuration bin/standalone.conf modules/br/gov/mec/aghu/configuration 2>/dev/null || true
  info "instalacao anterior encontrada - configuracao salva em $BK"
  rm -rf "$WFD"
fi
ARQ="$(obter_arquivo "$WILDFLY_URL" "$WILDFLY_SHA256")"
unzip -q "$ARQ" -d "$PREFIXO"
ln -sfn "$WFD" "$PREFIXO/wildfly"
tar xzf "$DIR/pacote/wildfly-aghuse-overlay.tar.gz" -C "$WFD"
while IFS= read -r f; do [ -n "$f" ] && rm -f "$WFD/$f"; done < "$DIR/pacote/wildfly-aghuse-removidos.txt"

export AGHUSE_MODO_LOGIN="$MODO_LOGIN" AGHUSE_NOME_AMBIENTE="$NOME_AMBIENTE" AGHUSE_PG_PORTA="$PG_PORTA" \
  AGHUSE_DB_NOME="$DB_NOME" AGHUSE_DB_USUARIO="$DB_USUARIO" AGHUSE_DB_SENHA="$DB_SENHA" \
  AGHUSE_DB_USUARIO_FIT="$DB_USUARIO_FIT" AGHUSE_DB_SENHA_FIT="$DB_SENHA_FIT" \
  AGHUSE_LDAP_HOST="$LDAP_HOST" AGHUSE_LDAP_PORTA="$LDAP_PORTA" AGHUSE_LDAP_USER_DN="$LDAP_USER_DN" \
  AGHUSE_LDAP_BIND_DN="$LDAP_BIND_DN" AGHUSE_LDAP_BIND_SENHA="$LDAP_BIND_SENHA" \
  AGHUSE_LDAP_BASE_USUARIOS="$LDAP_BASE_USUARIOS" AGHUSE_LDAP_ATRIBUTO_LOGIN="$LDAP_ATRIBUTO_LOGIN" \
  AGHUSE_LDAP_FILTRO="$LDAP_FILTRO" AGHUSE_SMTP_HOST="$SMTP_HOST" AGHUSE_PORT_OFFSET="$PORT_OFFSET"
python3 "$DIR/lib/configurar_wildfly.py" "$WFD" | sed 's/^/    /'

cat > "$WFD/bin/standalone.conf" <<EOF
## AGHUse - standalone.conf (gerado pelo instalador)
if [ "x\$JBOSS_MODULES_SYSTEM_PKGS" = "x" ]; then
   JBOSS_MODULES_SYSTEM_PKGS="org.jboss.byteman"
fi
JAVA_HOME=$PREFIXO/jdk
if [ "x\$JAVA_OPTS" = "x" ]; then
   JAVA_OPTS="-Xms$MEMORIA_JVM -Xmx$MEMORIA_JVM -XX:MaxMetaspaceSize=2G -Djava.net.preferIPv4Stack=true -Dorg.jboss.resolver.warning=true -Dsun.rmi.dgc.client.gcInterval=3600000 -Dsun.rmi.dgc.server.gcInterval=3600000 -Dorg.apache.el.parser.COERCE_TO_ZERO=false -Djboss.as.management.blocking.timeout=1800"
   JAVA_OPTS="\$JAVA_OPTS -Djboss.modules.system.pkgs=\$JBOSS_MODULES_SYSTEM_PKGS -Djava.awt.headless=true"
   JAVA_OPTS="\$JAVA_OPTS -Djboss.server.default.config=standalone-full.xml -Dorg.jboss.as.logging.per-deployment=false"
   JAVA_OPTS="\$JAVA_OPTS -Doracle.jdbc.DateZeroTime=true -Dactivemq.artemis.client.global.thread.pool.max.size=30"
   JAVA_OPTS="\$JAVA_OPTS -Djavamelody.datasources=java:/aghuDatasource -XX:+UseG1GC -XX:ReservedCodeCacheSize=512m"
   JAVA_OPTS="\$JAVA_OPTS -Dcom.sun.xml.bind.v2.bytecode.ClassTailor.noOptimize=true -Djdk.httpclient.keepalive.timeout=10"
   JAVA_OPTS="\$JAVA_OPTS -Duser.timezone=$FUSO_HORARIO -Duser.language=pt -Duser.country=BR -Dfile.encoding=UTF-8"
else
   echo "JAVA_OPTS already set in environment; overriding default settings with values: \$JAVA_OPTS"
fi
EOF

mkdir -p "$WFD/lucene/indexes"
cp "$DIR/pacote/aghu.ear" "$WFD/standalone/deployments/aghu.ear"
chown -R "$USUARIO_SO:$USUARIO_SO" "$WFD"
chmod 750 "$WFD"
chmod 640 "$WFD/standalone/configuration/standalone-full.xml" \
  "$WFD/modules/br/gov/mec/aghu/configuration/main/properties/app-parameters.properties"

cat > "/etc/systemd/system/$SERVICO.service" <<EOF
[Unit]
Description=AGHUse $VERSAO_AGHUSE (WildFly 26.1.3)
After=network.target postgresql.service

[Service]
Type=simple
User=$USUARIO_SO
Group=$USUARIO_SO
WorkingDirectory=$WFD/bin
Environment=JAVA_HOME=$PREFIXO/jdk
ExecStart=$WFD/bin/standalone.sh -c standalone-full.xml -b $HTTP_BIND -bmanagement 127.0.0.1 -Djboss.socket.binding.port-offset=$PORT_OFFSET
LimitNOFILE=102642
TimeoutStartSec=900
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable -q "$SERVICO"

# ----------------------------------------------------------------------------
# 7. inicializacao e verificacao
# ----------------------------------------------------------------------------
etapa "Iniciando o AGHUse (a primeira inicializacao leva de 3 a 10 minutos)"
systemctl start "$SERVICO"
DEP="$WFD/standalone/deployments"
for _ in $(seq 1 180); do
  [ -f "$DEP/aghu.ear.deployed" ] || [ -f "$DEP/aghu.ear.failed" ] && break
  systemctl is-active -q "$SERVICO" || break
  sleep 5
done
[ -f "$DEP/aghu.ear.deployed" ] || erro "a aplicacao nao foi implantada. Veja $WFD/standalone/log/server.log"
PORTA_HTTP=$((8080 + PORT_OFFSET))
URL_LOCAL="http://127.0.0.1:$PORTA_HTTP/aghu/pages/casca/casca.xhtml"
PAGINA="$(curl -fsS --max-time 180 "$URL_LOCAL" || true)"
grep -q "formLogin" <<< "$PAGINA" || erro "a tela de login nao respondeu em $URL_LOCAL"
VERSAO_TELA="$(grep -o 'Vers[^<]*' <<< "$PAGINA" | sed -n '1{s/[[:space:]]\+/ /g;p}' || true)"
info "aplicacao implantada e respondendo"
info "$VERSAO_TELA"

# ----------------------------------------------------------------------------
# 8. credenciais e resumo
# ----------------------------------------------------------------------------
IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
[ "$HTTP_BIND" = "0.0.0.0" ] && HOST_URL="${IP:-127.0.0.1}" || HOST_URL="$HTTP_BIND"
URL="http://$HOST_URL:$PORTA_HTTP/aghu"
CRED="/root/aghuse-credenciais-$SERVICO.txt"
umask 077
{
  echo "AGHUse $VERSAO_AGHUSE - credenciais da instalacao ($(date '+%d/%m/%Y %H:%M'))"
  echo "Ambiente: $AMBIENTE   Login: $MODO_LOGIN"
  echo
  echo "URL ......................: $URL"
  if [ "$MODO_LOGIN" = "ldap-externo" ]; then
    echo "Usuario administrador ....: $ADMIN_LOGIN ($NOTA_ADMIN)"
  else
    echo "Usuario administrador ....: $ADMIN_LOGIN"
    echo "Senha do administrador ...: $ADMIN_SENHA"
  fi
  echo
  echo "PostgreSQL $PG_VERSAO .........: 127.0.0.1:$PG_PORTA  banco $DB_NOME"
  echo "Usuario da aplicacao .....: $DB_USUARIO / $DB_SENHA"
  echo "Usuario FIT ..............: $DB_USUARIO_FIT / $DB_SENHA_FIT"
  if [ "$MODO_LOGIN" = "ldap-local" ]; then
    echo
    echo "OpenLDAP local ...........: ldap://127.0.0.1:389  base $BASE"
    echo "Administrador LDAP .......: cn=admin,$BASE / $LDAP_LOCAL_ADMIN_SENHA"
  fi
  echo
  echo "Arquivos de configuracao com senhas:"
  echo "  $WFD/standalone/configuration/standalone-full.xml"
  echo "  $WFD/modules/br/gov/mec/aghu/configuration/main/properties/app-parameters.properties"
} > "$CRED"
chmod 600 "$CRED"

echo
echo "${C_VERDE}  ==================================================================="
echo "   AGHUse instalado com sucesso"
echo "  ===================================================================${C_FIM}"
echo "   Acesso .............: $URL"
echo "   Usuario ............: $ADMIN_LOGIN"
if [ "$MODO_LOGIN" = "ldap-externo" ]; then
  echo "   Senha ..............: $NOTA_ADMIN"
else
  echo "   Senha ..............: gravada em $CRED"
fi
echo "   Credenciais ........: $CRED (somente root)"
echo "   Servico ............: systemctl status $SERVICO"
echo "   Log da aplicacao ...: $WFD/standalone/log/server.log"
echo "   Log da instalacao ..: $LOG"
if [ "$AMBIENTE" = "teste" ]; then
  echo
  echo "${C_AMAR}   Ambiente de TESTE. Antes de qualquer uso com dados reais, leia a secao"
  echo "   'Uso em producao' do README.md.${C_FIM}"
else
  echo
  echo "${C_AMAR}   Producao: publique o sistema apenas atras de um proxy reverso com HTTPS"
  echo "   e conclua a lista de verificacao da secao 'Uso em producao' do README.md.${C_FIM}"
fi
if command -v ufw >/dev/null && ufw status 2>/dev/null | grep "Status: active" >/dev/null; then
  echo "${C_AMAR}   Firewall ativo: libere a porta $PORTA_HTTP se necessario (ufw allow $PORTA_HTTP/tcp).${C_FIM}"
fi
