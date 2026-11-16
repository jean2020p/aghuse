#!/usr/bin/env bash
###############################################################################
#  AGHUse 13.250-STABLE - Assistente de instalacao para Linux (telas whiptail)
#  Uso:  sudo ./instalar-assistente.sh
#
#  Mesmas telas e mesma logica do instalador grafico do Windows:
#  aviso e aceite -> requisitos -> outros sistemas (aceite de risco) ->
#  resumo da configuracao PRE-DEFINIDA -> instalacao (barra de progresso) ->
#  resultado com o caminho das credenciais. Nada a preencher: o ambiente de
#  teste vem pronto (LDAP local, administrador AGHU com senha gerada).
#  Para outra configuracao: edite o aghuse.conf e rode sudo ./instalar.sh.
#  Funciona por SSH, sem interface grafica.
###############################################################################
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF="$DIR/aghuse.conf"
TITULO="AGHUse 13.250-STABLE - Instalador (teste e estudo)"
VARIANTE_DESCRICAO=""
if [ -f "$DIR/VARIANTE" ]; then
  VARIANTE_DESCRICAO="$(grep '^DESCRICAO=' "$DIR/VARIANTE" | head -1 | cut -d'"' -f2)"
  TITULO="AGHUse 13.250-STABLE - ${VARIANTE_DESCRICAO:-Variante nao oficial}"
fi
export NEWT_COLORS='root=,blue window=,lightgray title=blue,lightgray button=white,blue actbutton=white,red checkbox=,lightgray actcheckbox=white,blue entry=black,white'

[ "$(id -u)" -eq 0 ] || { echo "Execute como root:  sudo ./instalar-assistente.sh"; exit 1; }
command -v whiptail >/dev/null || { echo "whiptail nao encontrado. Instale com 'sudo apt-get install -y whiptail' ou use: sudo ./instalar.sh"; exit 1; }
[ -f "$CONF" ] || { echo "arquivo nao encontrado: $CONF"; exit 1; }
# shellcheck disable=SC1090
source "$CONF"
# shellcheck source=lib/detectar_outros.sh
. "$DIR/lib/detectar_outros.sh"

L=$(tput lines 2>/dev/null || echo 24); C=$(tput cols 2>/dev/null || echo 80)
A=$(( L > 30 ? 26 : L - 4 )); W=$(( C > 90 ? 84 : C - 6 ))
TMPA="$(mktemp -d /tmp/aghuse-assistente.XXXXXX)"; trap 'rm -rf "$TMPA"' EXIT

caixa()    { whiptail --backtitle "$TITULO" --title "$1" --msgbox "$2" "$A" "$W"; }
pergunta() { whiptail --backtitle "$TITULO" --title "$1" --yes-button "${3:-Sim}" --no-button "${4:-Nao}" ${5:+--defaultno} --yesno "$2" "$A" "$W"; }
entrada()  { whiptail --backtitle "$TITULO" --title "$1" --ok-button "Avancar" --cancel-button "Cancelar" --inputbox "$2" 12 "$W" "$3" 3>&1 1>&2 2>&3; }
senha()    { whiptail --backtitle "$TITULO" --title "$1" --ok-button "Avancar" --cancel-button "Cancelar" --passwordbox "$2" 12 "$W" 3>&1 1>&2 2>&3; }
cancelar() { whiptail --backtitle "$TITULO" --title "Cancelar" --yes-button "Sim, cancelar" --no-button "Voltar" --yesno "Deseja cancelar a instalacao?" 8 50 && { clear; echo "Instalacao cancelada."; exit 1; }; }
alfanum()  { [[ "$1" =~ ^[A-Za-z0-9]+$ ]]; }

# ---------------------------------------------------------------- 1. aviso e aceite
cat > "$TMPA/aviso.txt" <<'EOF'
AVISO IMPORTANTE - LEIA ANTES DE CONTINUAR

Este pacote destina-se exclusivamente a TESTE, AVALIACAO e ESTUDO do AGHUse
(Aplicativo para Gestao Hospitalar).

- E fornecido "no estado em que se encontra", sem garantia de qualquer
  natureza e sem suporte tecnico.
- E uma iniciativa independente. NAO e uma distribuicao oficial do AGHUse e
  nao tem vinculo com a Comunidade AGHUse, o HCPA ou a EBSERH.
- Comunidade AGHUse (projeto oficial, contato e participacao):
  https://sites.google.com/hcpa.edu.br/aghuse/sobre-o-aghuse
- Quem instala, configura e opera o sistema assume toda a responsabilidade por
  seu uso, pela seguranca das informacoes e pelo cumprimento da legislacao,
  inclusive a LGPD.
- USE UMA MAQUINA DEDICADA e recem-instalada. O instalador instala e
  reconfigura PostgreSQL, OpenLDAP, Java e servicos do systemd. Nao execute em
  servidores que ja estao em producao ou que hospedam outros sistemas.
- O uso com dados reais de pacientes exige a validacao descrita na secao
  "Uso em producao" do README.md.

SERA INSTALADO (tudo incluido no pacote): OpenJDK 17.0.2, WildFly 26.1.3,
PostgreSQL 15, OpenLDAP (modo ldap-local), aplicacao AGHUse 13.250-STABLE e
base inicial de demonstracao, sem dados de pacientes.

Licenca: AGHUse (c) Hospital de Clinicas de Porto Alegre, GPL v2 ou posterior.
Este instalador nao exige chave de ativacao.
EOF
if [ -n "$VARIANTE_DESCRICAO" ]; then
  { echo "ESTE PACOTE E UMA VARIANTE NAO OFICIAL DO AGHUSE"; echo; echo "$VARIANTE_DESCRICAO."
    echo "Contem modificacoes no codigo-fonte do AGHUse feitas por este instalador independente,"
    echo "sem vinculo com a Comunidade AGHUse. O que mudou e como voltar ao original esta em"
    echo "modificacoes/ (README.md). Para instalar o AGHUse SEM modificacoes, use o pacote original."
    echo; echo "------------------------------------------------------------------------"; echo; cat "$TMPA/aviso.txt"; } > "$TMPA/aviso2.txt"
  mv "$TMPA/aviso2.txt" "$TMPA/aviso.txt"
fi
whiptail --backtitle "$TITULO" --title "Aviso importante (setas rolam o texto; TAB e Enter continuam)" --scrolltext --textbox "$TMPA/aviso.txt" "$A" "$W"
pergunta "Aceite" "Voce leu o aviso e aceita as condicoes de uso?\n\nSem o aceite, a instalacao nao continua." "Aceito" "Nao aceito" 1 \
  || { clear; echo "Instalacao cancelada: os termos nao foram aceitos."; exit 1; }

# ---------------------------------------------------------------- 2. requisitos
. /etc/os-release
RAM_GB=$(awk '/MemTotal/{print int($2/1048576+0.5)}' /proc/meminfo)
NUC=$(nproc)
mkdir -p "$PREFIXO"
LIVRE_GB=$(df -Pk "$PREFIXO" | awk 'NR==2{print int($4/1048576)}')
REL=""; BLOQ=""
linha() { REL+="  [$1]  $2\n"; }
case "${ID:-}" in
  ubuntu|debian) linha OK "Sistema: $PRETTY_NAME" ;;
  *) linha FALHA "Sistema nao suportado: ${PRETTY_NAME:-?} (use Ubuntu 22.04/24.04 ou Debian 12)"; BLOQ=1 ;;
esac
[ "$(uname -m)" = "x86_64" ] && linha OK "Arquitetura x86_64" || { linha FALHA "Arquitetura $(uname -m): requer x86_64"; BLOQ=1; }
if   [ "$RAM_GB" -lt 8 ];  then linha FALHA "Memoria RAM: $RAM_GB GB (minimo 8 GB; recomendado 16 GB)"; BLOQ=1
elif [ "$RAM_GB" -lt 16 ]; then linha AVISO "Memoria RAM: $RAM_GB GB (funciona; recomendado 16 GB)"
else linha OK "Memoria RAM: $RAM_GB GB"; fi
[ "$NUC" -ge 4 ] && linha OK "Processadores: $NUC" || linha AVISO "Processadores: $NUC (recomendado 4 ou mais)"
if   [ "$LIVRE_GB" -lt 15 ];  then linha FALHA "Espaco livre em $PREFIXO: $LIVRE_GB GB (minimo 15 GB)"; BLOQ=1
elif [ "$LIVRE_GB" -lt 100 ]; then linha AVISO "Espaco livre em $PREFIXO: $LIVRE_GB GB (recomendado 100 GB)"
else linha OK "Espaco livre em $PREFIXO: $LIVRE_GB GB"; fi
if [ "${ID:-}-${VERSION_ID:-}" = "ubuntu-22.04" ]; then linha OK "Ubuntu 22.04: instalacao completa sem internet"
else linha AVISO "PostgreSQL e OpenLDAP serao baixados da internet (pacotes offline so para Ubuntu 22.04)"; fi
if [ -n "$BLOQ" ]; then
  caixa "Verificacao dos requisitos" "$REL\nA INSTALACAO NAO PODE CONTINUAR: este computador nao atende aos requisitos minimos."
  clear; exit 1
fi
caixa "Verificacao dos requisitos" "$REL\nComponentes incluidos no pacote: OpenJDK 17, WildFly 26.1.3, PostgreSQL 15, AGHUse 13.250 e base inicial."

# ---------------------------------------------------------------- 3. outros sistemas
ACEITO_RISCO="nao"
detectar_outros
if [ "${#OUTROS[@]}" -gt 0 ]; then
  LISTA="$(printf -- '- %s\n' "${OUTROS[@]}")"
  TXT="Foram encontrados outros sistemas ou servicos neste computador:\n\n$LISTA\n\nO AGHUse foi feito para uma maquina DEDICADA. Se voce continuar:\n- o instalador usa o PostgreSQL $PG_VERSAO existente (cria usuarios e o banco $DB_NOME nele);\n- o WildFly reserva cerca de 6 GB de memoria: os outros sistemas podem ficar lentos;\n- portas, atualizacoes, backups e reinicializacoes passam a afetar os dois sistemas;\n- nao ha suporte para esta combinacao. Em servidor de producao (por exemplo, com o e-SUS), NAO instale.\n\nMarque a confirmacao (barra de espaco) para continuar."
  while true; do
    ESC=$(whiptail --backtitle "$TITULO" --title "Outros sistemas neste computador" --ok-button "Avancar" --cancel-button "Cancelar" --checklist "$TXT" "$A" "$W" 1 \
          "ACEITO" "Li, estou ciente e assumo o risco" OFF 3>&1 1>&2 2>&3) || { cancelar; continue; }
    [[ "$ESC" == *ACEITO* ]] && break
    caixa "Confirmacao necessaria" "Para continuar e preciso marcar a confirmacao (barra de espaco sobre a opcao).\nPara sair, use Cancelar."
  done
  ACEITO_RISCO="sim"
fi

# ---------------------------------------------------------------- 4. configuracao pre-definida
# Ambiente de TESTE: tudo vem pre-configurado (nada a preencher). Para producao ou outra
# configuracao, edite o aghuse.conf e rode sudo ./instalar.sh (veja o README.md).
MODO="${MODO_LOGIN:-ldap-local}"; ADM="${ADMIN_LOGIN:-AGHU}"
# Autenticacao: LDAP local (recomendado, ja marcado) ou banco de dados. O LDAP/AD da instituicao
# (ldap-externo) exige parametros: configure no aghuse.conf e use o instalar.sh.
if [ "$MODO" != "ldap-externo" ]; then
  [ "$MODO" = "banco" ] || MODO="ldap-local"
  MODO=$(whiptail --backtitle "$TITULO" --title "Autenticacao (login)" --ok-button "Avancar" --cancel-button "Cancelar" --default-item "$MODO" --menu \
    "Como os usuarios vao entrar no AGHUse?\n\nO AGHUse nao guarda senhas: elas sao conferidas em um diretorio LDAP (como no uso real do sistema) ou, no modo de avaliacao, pelo banco de dados. Nos dois casos nao ha nada a preencher." 17 "$W" 2 \
    "ldap-local" "LDAP local neste servidor (RECOMENDADO)" \
    "banco"      "Banco de dados, sem diretorio (avaliacao rapida)" 3>&1 1>&2 2>&3) || { clear; echo "Instalacao cancelada."; exit 1; }
fi
PORTA="$((8080 + ${PORT_OFFSET:-0}))"; MEM="${MEMORIA_JVM:-}"
case "$MODO" in banco) M="banco de dados (avaliacao)" ;; ldap-local) M="LDAP local neste servidor (OpenLDAP, $LDAP_LOCAL_DOMINIO)" ;; *) M="LDAP/AD em ${LDAP_HOST:-?}" ;; esac
RECRIAR="nao"
if [ -d "$PREFIXO" ] && [ -n "$(ls -A "$PREFIXO" 2>/dev/null | grep -v '^backup$')" ]; then
  if pergunta "Reinstalacao" "Ja existe uma instalacao do AGHUse em $PREFIXO.\n\nDeseja APAGAR o banco $DB_NOME e restaurar a base inicial?\nTodos os dados cadastrados serao PERDIDOS.\n\n(Manter = so reinstala o servidor de aplicacao, os dados ficam)" "Apagar o banco" "Manter os dados" 1; then
    pergunta "Confirmacao" "Confirma APAGAR o banco $DB_NOME?" "Apagar" "Cancelar" 1 && RECRIAR="sim"
  fi
fi

# ---------------------------------------------------------------- 5. resumo
RES="Configuracao PRE-DEFINIDA para teste (nada a preencher):\n\n"
RES+="Pasta .............: $PREFIXO\n"
RES+="Login .............: $M\n"
RES+="Administrador .....: $ADM (senha gerada; mostrada ao final)\n"
RES+="Endereco ..........: http://<ip-deste-servidor>:$PORTA/aghu\n"
RES+="Memoria WildFly ...: ${MEM:-5G (padrao)}\n"
[ "$RECRIAR" = "sim" ] && RES+="Banco .............: sera APAGADO e recriado\n"
[ "$ACEITO_RISCO" = "sim" ] && RES+="Outros sistemas ...: encontrados - risco ACEITO\n"
RES+="\nPara producao, baixe o projeto e ajuste o aghuse.conf (recomendado).\n"
RES+="Servico: $SERVICO (systemd). A instalacao leva de 20 a 60 minutos.\n\nInstalar agora?"
pergunta "Pronto para instalar" "$RES" "Instalar" "Cancelar" || { clear; echo "Instalacao cancelada."; exit 1; }
# ---------------------------------------------------------------- 6. grava o aghuse.conf e instala
cp -p "$CONF" "$CONF.anterior-$(date +%Y%m%d-%H%M%S)"
definir() {  # definir NOME VALOR: substitui a linha NOME=... preservando o comentario
  NOME="$1" VALOR="$2" awk '
    BEGIN { n = ENVIRON["NOME"]; v = ENVIRON["VALOR"]; feito = 0 }
    $0 ~ "^" n "=" { c = ""; if (match($0, /"[^"]*"[ \t]*#.*$/)) { c = substr($0, RSTART); sub(/^"[^"]*"/, "", c) }
                     print n "=\"" v "\"" c; feito = 1; next }
    { print }
    END { if (!feito) print n "=\"" v "\"" }' "$CONF" > "$CONF.tmp" && cat "$CONF.tmp" > "$CONF" && rm -f "$CONF.tmp"
}
definir MODO_LOGIN "$MODO"; definir RECRIAR_BANCO "$RECRIAR"; definir ACEITO_RISCO "$ACEITO_RISCO"
chmod 600 "$CONF" "$CONF".anterior-* 2>/dev/null || true

SAIDA="$TMPA/saida.log"
pct_etapa() {
  case "$1" in
    Verificando*) echo 3 ;; Conferindo*) echo 8 ;; "Instalando pacotes"*) echo 15 ;; PostgreSQL*) echo 22 ;;
    "Banco de dados"*) echo 30 ;; Autenticacao*) echo 70 ;; OpenJDK*) echo 75 ;; WildFly*) echo 80 ;; Iniciando*) echo 88 ;; *) echo "" ;;
  esac
}
PCT=1
{ bash "$DIR/instalar.sh" "$CONF" < /dev/null 2>&1; echo "__CODIGO__=$?"; } | while IFS= read -r l; do
  l="$(printf '%s' "$l" | sed 's/\x1b\[[0-9;]*m//g')"
  printf '%s\n' "$l" >> "$SAIDA"
  case "$l" in
    "==> "*) E="${l#==> }"; P="$(pct_etapa "$E")"; [ -n "$P" ] && PCT="$P"; MSG="$E" ;;
    "    "*) MSG="${E:-Instalando}\n\n${l#    }" ;;
    *) continue ;;
  esac
  printf 'XXX\n%s\n%b\nXXX\n' "$PCT" "$MSG"
done | whiptail --backtitle "$TITULO" --title "Instalando o AGHUse (nao desligue o computador)" --gauge "Preparando..." 12 "$W" 0

COD="$(sed -n 's/^__CODIGO__=//p' "$SAIDA" | tail -1)"
LOG="/var/log/aghuse-instalador-${SERVICO}.log"
CRED="/root/aghuse-credenciais-${SERVICO}.txt"
if [ "${COD:-1}" = "0" ]; then
  URL="$(sed -n 's/^ *Acesso \.*: *//p' "$SAIDA" | tail -1)"
  ADM_SENHA_FINAL="$(sed -n 's/^Senha do administrador[ .]*: *//p' "$CRED" 2>/dev/null | head -1)"
  caixa "AGHUse instalado com sucesso" "O AGHUse foi instalado e esta funcionando.\n\nEndereco ...........: ${URL}\nNeste servidor .....: http://localhost:$PORTA/aghu\nUsuario ............: $ADM\nSenha ..............: ${ADM_SENHA_FINAL:-veja o arquivo de credenciais}\n\nA senha do administrador e as demais credenciais ficaram gravadas em:\n  $CRED\n(somente o root pode ler; para ver depois: sudo cat $CRED)\n\nServico: sudo systemctl status $SERVICO\nVerificacao: sudo ./verificar.sh\nCadastrar usuarios: sudo ./usuario.sh criar LOGIN \"NOME\" email (passo a passo: docs/CADASTRO_DE_USUARIOS.md)\n\nAmbiente de TESTE: antes de usar com dados reais, leia 'Uso em producao' no README.md."
  pergunta "Credenciais" "Deseja ver agora o arquivo de credenciais?\n\n$CRED" "Ver credenciais" "Fechar" && \
    whiptail --backtitle "$TITULO" --title "Credenciais (TAB e Enter para fechar)" --scrolltext --textbox "$CRED" "$A" "$W"
  clear; echo "AGHUse instalado: $URL   (credenciais: sudo cat $CRED)"; exit 0
else
  ERR="$(grep -E '^ERRO:|Falha na etapa' "$SAIDA" | awk '!v[$0]++' | tail -2)"
  caixa "A instalacao falhou" "A instalacao nao foi concluida.\n\n${ERR:-Erro nao identificado}\n\nLog completo: $LOG\n\nCorrija o problema e execute o assistente novamente: os dados ja criados sao preservados."
  tail -n 40 "$SAIDA" > "$TMPA/ultimas.txt"
  whiptail --backtitle "$TITULO" --title "Ultimas linhas da instalacao (TAB e Enter para fechar)" --scrolltext --textbox "$TMPA/ultimas.txt" "$A" "$W"
  clear; echo "Falha na instalacao. Log: $LOG"; exit 1
fi
