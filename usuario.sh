#!/usr/bin/env bash
###############################################################################
#  AGHUse - contas de acesso (login e senha)
#
#  O AGHUse nao armazena senhas: a senha de cada usuario fica no diretorio
#  (LDAP/AD). Este comando cria e mantem as contas no diretorio desta
#  instalacao. O cadastro do usuario, da pessoa, do vinculo e dos perfis e
#  feito na propria aplicacao (ver README.md, "Usuarios do sistema").
#
#  Uso:  sudo ./usuario.sh criar   LOGIN ["NOME COMPLETO"] [email@instituicao.org.br]
#        sudo ./usuario.sh senha   LOGIN          (redefine a senha)
#        sudo ./usuario.sh remover LOGIN
#        sudo ./usuario.sh listar
#  A senha e solicitada no terminal; se ficar em branco, e gerada uma senha
#  aleatoria e exibida uma unica vez.
#  Variavel opcional: AGHUSE_CONF=/caminho/aghuse.conf
###############################################################################
set -Eeuo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF="${AGHUSE_CONF:-$DIR/aghuse.conf}"
erro() { echo "ERRO: $*" >&2; exit 1; }
[ "$(id -u)" -eq 0 ] || erro "execute como root:  sudo ./usuario.sh ..."
[ -f "$CONF" ] || erro "arquivo de parametros nao encontrado: $CONF"
# shellcheck disable=SC1090
source "$CONF"

ACAO="${1:-}"; LOGIN="${2:-}"; NOME="${3:-}"; EMAIL="${4:-}"
[ "$MODO_LOGIN" != "ldap-externo" ] || erro "MODO_LOGIN=ldap-externo: as contas e senhas sao administradas no LDAP/Active Directory da instituicao."
uso() { sed -n '10,13p' "$0" | sed 's/^#//'; exit 1; }
[ -n "$ACAO" ] || uso
if [ "$ACAO" != "listar" ]; then
  [ -n "$LOGIN" ] || uso
  [[ "$LOGIN" =~ ^[A-Za-z0-9_.-]{2,64}$ ]] || erro "login invalido: use letras, numeros, ponto, hifen ou sublinhado."
fi

gerar_senha() {
  local s=""
  while [ "${#s}" -lt 16 ]; do s="$s$(head -c 48 /dev/urandom | base64 -w0 | tr -dc 'A-Za-z0-9')"; done
  printf '%s' "${s:0:16}"
}
ler_senha() {  # define SENHA
  local s1 s2
  if [ -t 0 ]; then
    read -r -s -p "Nova senha para $LOGIN (Enter para gerar automaticamente): " s1; echo
    if [ -n "$s1" ]; then
      read -r -s -p "Repita a senha: " s2; echo
      [ "$s1" = "$s2" ] || erro "as senhas nao conferem."
    fi
  else
    s1=""
  fi
  if [ -z "$s1" ]; then SENHA="$(gerar_senha)"; SENHA_GERADA=1
  else
    [ "${#s1}" -ge 10 ] || erro "a senha deve ter no minimo 10 caracteres."
    SENHA="$s1"; SENHA_GERADA=0
  fi
}
mostrar_senha() {
  if [ "$SENHA_GERADA" = 1 ]; then
    echo "  Senha gerada: $SENHA"
    echo "  (anote e entregue ao usuario por meio seguro; ela nao sera exibida novamente)"
  fi
}
proximos_passos() {
  cat <<EOF

  Proximo passo, na aplicacao (usuario com perfil de administrador):
    1. Usuario : Outros Modulos > Configuracao > Acesso > Usuario
                 Pesquisar > Importar Usuario > "$LOGIN" > Adicionar > Gravar;
                 depois, na lista, Editar Perfil (atribuir ao menos um perfil)
    2. Pessoa  : Reg. Colaboradores > Administracao de Pessoal > Administrar Servidores > Pessoas
    3. Servidor: Reg. Colaboradores > Administracao de Pessoal > Administrar Servidores > Servidores
                 (pessoa, login "$LOGIN", vinculo, matricula e inicio do vinculo)
  O login so e aceito apos as tres etapas.
EOF
}

case "$MODO_LOGIN" in
  ldap-externo)
    erro "MODO_LOGIN=ldap-externo: as contas e senhas sao administradas no LDAP/Active Directory da instituicao." ;;

  ldap-local)
    command -v ldapadd >/dev/null || erro "ldap-utils nao instalado (a instalacao foi concluida?)."
    BASE="dc=$(echo "$LDAP_LOCAL_DOMINIO" | sed 's/\./,dc=/g')"
    OU="ou=people,$BASE"
    CRED="/root/aghuse-credenciais-$SERVICO.txt"
    ADM_PW="${LDAP_LOCAL_ADMIN_SENHA:-}"
    if [ -z "$ADM_PW" ] && [ -f /etc/aghuse/ldap-local.senha ]; then ADM_PW="$(cat /etc/aghuse/ldap-local.senha)"; fi
    if [ -z "$ADM_PW" ] && [ -f "$CRED" ]; then
      ADM_PW="$(sed -n 's#^Administrador LDAP[ .]*: cn=admin,[^ ]* / ##p' "$CRED")"
    fi
    [ -n "$ADM_PW" ] || erro "senha do administrador LDAP nao encontrada (informe LDAP_LOCAL_ADMIN_SENHA no aghuse.conf)."
    L=(-x -H ldap://127.0.0.1 -D "cn=admin,$BASE" -w "$ADM_PW")
    UDN="uid=$LOGIN,$OU"
    existe() { ldapsearch -x -LLL -H ldap://127.0.0.1 -b "$UDN" -s base dn >/dev/null 2>&1; }
    case "$ACAO" in
      criar)
        existe && erro "a conta $LOGIN ja existe (use: ./usuario.sh senha $LOGIN)."
        ler_senha
        [ -n "$NOME" ] || NOME="$LOGIN"
        if [ -n "$EMAIL" ]; then
          [[ "$EMAIL" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]] || erro "e-mail invalido: $EMAIL"
        fi
        HASH="$(slappasswd -s "$SENHA")"
        {
          printf 'dn: %s\nobjectClass: inetOrgPerson\nuid: %s\ncn: %s\nsn: %s\ndisplayName: %s\n' \
            "$UDN" "$LOGIN" "$NOME" "${NOME##* }" "$NOME"
          [ -z "$EMAIL" ] || printf 'mail: %s\n' "$EMAIL"
          printf 'userPassword: %s\n' "$HASH"
        } | ldapadd "${L[@]}" >/dev/null
        ldapwhoami -x -H ldap://127.0.0.1 -D "$UDN" -w "$SENHA" >/dev/null || erro "conta criada, mas o teste de login falhou."
        echo "Conta $LOGIN criada no diretorio ($UDN)."; mostrar_senha; proximos_passos ;;
      senha)
        existe || erro "a conta $LOGIN nao existe (use: ./usuario.sh criar $LOGIN)."
        ler_senha
        ldappasswd "${L[@]}" -s "$SENHA" "$UDN" >/dev/null
        echo "Senha de $LOGIN redefinida."; mostrar_senha ;;
      remover)
        existe || erro "a conta $LOGIN nao existe."
        ldapdelete "${L[@]}" "$UDN"
        echo "Conta $LOGIN removida do diretorio. Inative tambem o usuario na aplicacao." ;;
      listar)
        ldapsearch -x -LLL -H ldap://127.0.0.1 -b "$OU" "(objectClass=inetOrgPerson)" uid cn \
          | awk '/^uid:/{u=$2} /^cn:/{sub(/^cn: /,""); c=$0} /^$/{if(u)printf "  %-20s %s\n",u,c; u=""}' ;;
      *) uso ;;
    esac ;;

  banco)
    PGP="$(pg_lsclusters -h | awk -v v="$PG_VERSAO" '$1==v{print $3; exit}')"
    [ -n "$PGP" ] || erro "cluster PostgreSQL $PG_VERSAO nao encontrado."
    psql_pg() { (cd /tmp && runuser -u postgres -- env PGOPTIONS="-c client_min_messages=warning" psql -X -q -v ON_ERROR_STOP=1 -p "$PGP" "$@"); }
    LMIN="$(echo "$LOGIN" | tr '[:upper:]' '[:lower:]')"; LMAI="$(echo "$LOGIN" | tr '[:lower:]' '[:upper:]')"
    existe() { [ -n "$(psql_pg -Atc "select 1 from pg_roles where rolname='$LMAI'")" ]; }
    definir() {
      local q="${SENHA//\'/\'\'}"
      for r in "$LMAI" "$LMIN"; do
        psql_pg <<SQL
DO \$\$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='$r') THEN CREATE ROLE "$r" LOGIN; END IF; END \$\$;
SET password_encryption = 'scram-sha-256';
ALTER ROLE "$r" PASSWORD '$q';
REVOKE ALL ON DATABASE "$DB_NOME" FROM "$r";
GRANT CONNECT ON DATABASE "aghuse_login" TO "$r";
SQL
      done
    }
    echo "Modo de avaliacao (MODO_LOGIN=banco): a senha e conferida pelo PostgreSQL."
    case "$ACAO" in
      criar) existe && erro "a conta $LOGIN ja existe (use: ./usuario.sh senha $LOGIN)."
             ler_senha; definir; echo "Conta $LOGIN criada."; mostrar_senha; proximos_passos ;;
      senha) existe || erro "a conta $LOGIN nao existe."
             ler_senha; definir; echo "Senha de $LOGIN redefinida."; mostrar_senha ;;
      remover) existe || erro "a conta $LOGIN nao existe."
             for r in "$LMAI" "$LMIN"; do
               if [ -n "$(psql_pg -Atc "select 1 from pg_roles where rolname='$r'")" ]; then
                 psql_pg -c "REVOKE ALL ON DATABASE \"$DB_NOME\" FROM \"$r\"" \
                         -c "REVOKE ALL ON DATABASE \"aghuse_login\" FROM \"$r\"" -c "DROP ROLE \"$r\""
               fi
             done
             echo "Conta $LOGIN removida. Inative tambem o usuario na aplicacao." ;;
      listar) psql_pg -Atc "select r.rolname from pg_roles r where r.rolcanlogin and has_database_privilege(r.rolname,'aghuse_login','CONNECT') and r.rolname = upper(r.rolname) and r.rolname not in ('$DB_USUARIO','$DB_USUARIO_FIT','postgres') order by 1" | sed 's/^/  /' ;;
      *) uso ;;
    esac ;;
  *) erro "MODO_LOGIN invalido no $CONF." ;;
esac
