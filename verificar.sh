#!/usr/bin/env bash
# Verifica o estado de uma instalacao do AGHUse.  Uso: sudo ./verificar.sh [arquivo.conf]
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF="${1:-$DIR/aghuse.conf}"
[ "$(id -u)" -eq 0 ] || { echo "execute como root: sudo ./verificar.sh"; exit 1; }
# shellcheck disable=SC1090
source "$CONF"
OK=$'\e[1;32mOK\e[0m'; FALHA=$'\e[1;31mFALHA\e[0m'; ST=0
chk() { if eval "$2" >/dev/null 2>&1; then echo "  [$OK] $1"; else echo "  [$FALHA] $1"; ST=1; fi; }

WFD="$PREFIXO/wildfly"
PORTA_HTTP=$((8080 + PORT_OFFSET))
PGP="$(pg_lsclusters -h 2>/dev/null | awk -v v="$PG_VERSAO" '$1==v{print $3; exit}')"
echo "AGHUse - verificacao ($SERVICO, login: $MODO_LOGIN)"
chk "Java instalado ($PREFIXO/jdk)" "[ -x '$PREFIXO/jdk/bin/java' ]"
chk "PostgreSQL $PG_VERSAO ativo (porta ${PGP:-?})" "pg_lsclusters -h | awk -v v='$PG_VERSAO' '\$1==v && \$4==\"online\"{f=1} END{exit !f}'"
chk "Banco $DB_NOME existente" "(cd /tmp && runuser -u postgres -- psql -X -p '$PGP' -Atc \"select 1 from pg_database where datname='$DB_NOME'\" | grep -x 1)"
[ "$MODO_LOGIN" = "ldap-local" ] && chk "OpenLDAP local ativo" "systemctl is-active slapd"
chk "Servico $SERVICO ativo" "systemctl is-active '$SERVICO'"
chk "Aplicacao implantada (aghu.ear.deployed)" "[ -f '$WFD/standalone/deployments/aghu.ear.deployed' ]"
PAG="$(curl -fsS --max-time 60 "http://127.0.0.1:$PORTA_HTTP/aghu/pages/casca/casca.xhtml" 2>/dev/null || true)"
chk "Tela de login respondendo na porta $PORTA_HTTP" "grep -q formLogin <<< \"\$PAG\""
V="$(grep -o 'Vers[^<]*' <<< "$PAG" | sed -n '1{s/[[:space:]]\+/ /g;p}')"
[ -n "$V" ] && echo "  $V"
N=$(grep -c ' ERROR ' "$WFD/standalone/log/server.log" 2>/dev/null || echo 0)
echo "  Linhas de ERROR no server.log atual: $N"
exit $ST
