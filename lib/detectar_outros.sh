#!/usr/bin/env bash
###############################################################################
#  AGHUse - deteccao de outros sistemas na maquina (usado por instalar.sh e
#  instalar-assistente.sh). Preenche o vetor OUTROS com uma linha por item.
#  Requer: SERVICO, PORT_OFFSET, PG_VERSAO, DB_NOME, MODO_LOGIN; executar como root.
###############################################################################
porta_ocupada() { ss -Hltn "sport = :$1" 2>/dev/null | grep -q .; }

detectar_outros() {
  OUTROS=()
  local PH=$((8080 + ${PORT_OFFSET:-0})) PM=$((9990 + ${PORT_OFFSET:-0})) porta v c p BANCOS unidade par
  for porta in "$PH" "$PM"; do
    if porta_ocupada "$porta"; then
      systemctl is-active -q "$SERVICO" 2>/dev/null || OUTROS+=("porta $porta (usada pelo AGHUse) ja esta em uso por outro programa")
    fi
  done
  if command -v pg_lsclusters >/dev/null 2>&1; then
    while read -r v c p _; do
      # "|| true" dentro do subshell: cluster parado ou iniciando nao e erro aqui (nem dispara o trap ERR)
      BANCOS="$(cd /tmp && runuser -u postgres -- psql -X -p "$p" -Atc \
        "select string_agg(datname, ', ' order by datname) from pg_database where not datistemplate and datname not in ('postgres','$DB_NOME','aghuse_login')" 2>/dev/null || true)"
      if [ -n "$BANCOS" ]; then
        OUTROS+=("PostgreSQL $v (cluster $c, porta $p) com bancos de outros sistemas: $BANCOS")
      elif [ "$v" != "$PG_VERSAO" ]; then
        OUTROS+=("PostgreSQL $v (cluster $c, porta $p) ja instalado")
      fi
    done < <(pg_lsclusters -h 2>/dev/null)
  elif porta_ocupada 5432; then
    OUTROS+=("porta 5432 (PostgreSQL) ja esta em uso")
  fi
  while read -r unidade _; do
    case "${unidade,,}" in
      *e-sus*|*esus*)                OUTROS+=("sistema e-SUS (Ministerio da Saude): servico $unidade") ;;
      mysql*|mariadb*)               OUTROS+=("banco de dados MySQL/MariaDB: servico $unidade") ;;
      mongod*|redis*|mssql*|oracle*|firebird*) OUTROS+=("banco de dados: servico $unidade") ;;
      apache2*|httpd*|nginx*)        OUTROS+=("servidor web: servico $unidade") ;;
      tomcat*|wildfly*|jboss*|glassfish*|payara*) OUTROS+=("servidor de aplicacao Java: servico $unidade") ;;
      docker.service|containerd.service) OUTROS+=("conteineres (Docker): servico $unidade") ;;
      slapd.service) [ "$MODO_LOGIN" = "ldap-local" ] && [ ! -f /etc/aghuse/ldap-local.senha ] && OUTROS+=("diretorio OpenLDAP (slapd) de outro sistema: o modo ldap-local passaria a usa-lo") ;;
    esac
  done < <(systemctl list-units --type=service --state=running --no-legend --plain 2>/dev/null; systemctl list-unit-files --type=service --no-legend 2>/dev/null | grep -i 'e-sus\|esus' || true)  # || true: sem e-SUS o grep retorna 1 e, com set -E, dispararia o trap ERR
  for par in "3306:MySQL/MariaDB" "1433:SQL Server" "1521:Oracle" "80:servidor web" "443:servidor web HTTPS"; do
    porta_ocupada "${par%%:*}" && OUTROS+=("porta ${par%%:*} (${par#*:}) ja esta em uso")
  done
  mapfile -t OUTROS < <(printf '%s\n' "${OUTROS[@]}" | awk 'NF && !v[$0]++')
  return 0
}
