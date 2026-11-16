# Notas técnicas dos instaladores (Linux e Windows)

Este documento é para quem vai manter, corrigir ou adaptar os instaladores deste repositório. Ele explica a arquitetura, como gerar e testar cada instalador e as armadilhas encontradas durante o desenvolvimento. As instruções de uso estão no [README.md](../README.md).

> O AGHUse é desenvolvido pelo Hospital de Clínicas de Porto Alegre e mantido pela Comunidade AGHUse: <https://sites.google.com/hcpa.edu.br/aghuse/sobre-o-aghuse>. Estes instaladores são uma iniciativa independente, para teste e estudo.

---

## 1. Arquitetura: motor + interface

Nos dois sistemas, o instalador tem duas camadas:

| Camada | Linux | Windows |
|---|---|---|
| **Motor** (faz a instalação; pode ser usado sozinho) | `instalar.sh` | `windows/instalar.ps1` |
| **Interface** (telas; coleta as respostas e chama o motor) | `instalar-assistente.sh` (whiptail, no terminal) | `windows/setup/aghuse.iss` (Inno Setup, janelas) |
| **Parâmetros** (mesmo formato `NOME="valor"`) | `aghuse.conf` | `windows/aghuse.conf` |
| Detecção de outros sistemas | `lib/detectar_outros.sh` (usada pelo motor e pela interface) | código Pascal no `aghuse.iss` e verificação no motor |
| Contas de acesso, verificação, remoção | `usuario.sh`, `verificar.sh` | `windows/usuario.ps1`, `verificar.ps1`, `desinstalar.ps1` (+ `.bat`) |

A interface só grava o `aghuse.conf` e executa o motor. Toda regra de instalação fica no motor, para que a linha de comando, a automação e as telas tenham exatamente o mesmo comportamento.

### Sequência das telas (igual nos dois sistemas)

1. Aviso e aceite das condições de uso.
2. Verificação dos requisitos: bloqueia abaixo do mínimo e avisa abaixo do recomendado.
3. Outros sistemas na máquina, com aceite de risco. Só aparece se algo for encontrado.
4. Autenticação: `banco`, `ldap-local` (só Linux) ou `ldap-externo`.
5. Administrador. Senha em branco é gerada.
6. LDAP/AD, só no modo `ldap-externo`.
7. Servidor: porta, memória e proxy reverso; na reinstalação, se apaga ou mantém o banco.
8. Resumo.
9. Execução do motor com progresso. As linhas `==> etapa` do motor alimentam a barra.
10. Resultado: endereço de acesso e caminho do arquivo de credenciais (aberto ao final).

### Comunicação entre interface e motor

- O motor imprime `==> <etapa>` no início de cada etapa e `ERRO: <mensagem>` em caso de falha.
- O motor do Windows também imprime ao final `RESULTADO_URL=`, `RESULTADO_URL_LOCAL=` e `RESULTADO_CRED=`, que a interface usa para montar a tela final e o atalho.
- Código de saída `0` significa sucesso.

---

## 2. Requisitos e por que são diferentes

| | Linux | Windows |
|---|---|---|
| Memória mínima | 8 GB | **12 GB** |
| Memória recomendada | 16 GB | 16 GB |
| Disco mínimo | 15 GB | 20 GB |
| Sistema | Ubuntu 22.04 (offline), Ubuntu 24.04, Debian 12 | Windows 10/11 1809+ e Server 2019+, x64 |

Medição feita numa instalação de teste no Windows 10, com 15,7 GB de RAM:

| Item | Memória |
|---|---|
| WildFly (heap de 5 GB reservado de uma vez por `-Xms5G`, mais metaspace, código e threads) | ~6,5 GB |
| PostgreSQL | ~0,2 GB |
| Windows (serviços e interface) | ~2,4 GB |
| **Total** | **~9,6 GB** |

Um Ubuntu Server sem interface ocupa ~0,5 GB. Com 8 GB no Windows, o sistema passa a usar o arquivo de paginação e fica lento, por isso o mínimo lá é 12 GB.

---

## 3. Instalador do Windows

### Componentes e onde ficam

| Item | Local |
|---|---|
| Java, WildFly, PostgreSQL (binários e dados) | `C:\AGHUse\jdk-17.0.2`, `wildfly-26.1.3.Final`, `pgsql`, `pgdata` |
| Serviços | `aghuse` (WildFly, via Apache Procrun distribuído com o WildFly, conta *LocalService*) e `aghuse-postgresql` (`pg_ctl register`, conta *NetworkService*) |
| Credenciais e senha do `postgres` | `C:\ProgramData\AGHUse\` (somente SYSTEM e Administradores) |
| Log da instalação | `C:\ProgramData\AGHUse\logs\aghuse-instalador-<SERVICO>.log` |
| Ferramentas instaladas | `C:\AGHUse\ferramentas\` (`usuario.bat`, `verificar.bat`, `desinstalar.bat`, `aghuse.conf`) |

PostgreSQL 15 para Windows: zip de binários da EDB, sem o instalador gráfico. O `initdb` usa `--locale-provider=icu --icu-locale=pt-BR --locale=C`; a base inicial não tem colações explícitas e restaura sem erros.

### Gerar o `.exe`

Requisitos: Windows, [Inno Setup 6.3+](https://jrsoftware.org/isdl.php) e as partes do pacote neste repositório.

```powershell
powershell -ExecutionPolicy Bypass -File windows\setup\gerar-setup.ps1
```

O script:
1. remonta `aghu.ear`, `dbaghu.dmp` e o zip do WildFly a partir das partes e confere o SHA-256;
2. baixa o OpenJDK e o PostgreSQL para Windows (ou usa `windows\setup\cache\`) e confere o SHA-256;
3. compila. Saída em `windows\setup\saida\` (~960 MB). As pastas `build`, `cache` e `saida` não são versionadas.

Ao trocar a versão do PostgreSQL ou do JDK, atualize `PG_URL`/`PG_SHA256` e `JDK_URL`/`JDK_SHA256` em `windows\lib\comum.ps1`. A EDB não publica SHA-256: baixe o arquivo e calcule o hash.

### Modo silencioso (testes e automação)

```
start /wait aghuse_setup_13.250-STABLE_Windows.exe /VERYSILENT /SUPPRESSMSGBOXES /LOG="C:\setup.log" /ACEITO_RISCO=sim /PORTA=8080 /MODO=ldap-local /RECRIAR=nao /FIREWALL=sim /MEMORIA=5G
```

As telas não pedem nenhum valor: a configuração de teste é pré-definida (LDAP local, `AGHU` com senha gerada, porta 8080, `C:\AGHUse`). Os parâmetros acima existem só para testes e automação; o exemplo mostra todos com os valores padrão (a lista completa, com o efeito de cada um, está no README, em "Instalação silenciosa"). `/MODO=ldap-externo` também aceita `/LDAP_HOST`, `/LDAP_PORTA`, `/LDAP_USER_DN`, `/LDAP_BASE`, `/LDAP_ATRIBUTO`, `/LDAP_FILTRO`, `/LDAP_BIND_DN` e `/LDAP_BIND_SENHA`. O `start /wait` é necessário porque o Prompt de Comando não espera programas com janela.

As linhas do motor aparecem no log do setup com o prefixo `motor:`. Sem `/ACEITO_RISCO=sim`, a instalação é recusada se houver outros sistemas na máquina.

---

## 4. Instalador do Linux

- `sudo ./instalar-assistente.sh`: telas no terminal com `whiptail` (já presente no Ubuntu e no Debian). Funciona por SSH e não precisa de interface gráfica. Não pede valores: usa o `aghuse.conf` como está (configuração de teste pré-definida) e só grava nele `RECRIAR_BANCO` e `ACEITO_RISCO`, com cópia do anterior em `aghuse.conf.anterior-<data>` (permissão 600; ignorada pelo Git).
- `sudo ./instalar.sh`: o motor, para uso direto ou automação.
- O aceite de risco é pedido pelo motor quando ele encontra outros sistemas: digitar `ACEITO` no terminal ou `ACEITO_RISCO="sim"` no `aghuse.conf`. O aceite é registrado em `/etc/aghuse/aceite-risco-<SERVICO>.txt`.

---

## 5. Armadilhas encontradas (e como foram resolvidas)

### PowerShell (Windows PowerShell 5.1)

| Problema | Sintoma | Solução |
|---|---|---|
| Nomes de variáveis não diferenciam maiúsculas | Uma variável `$conf` no corpo do script era o **mesmo** parâmetro `[string]$Conf`; a lista de linhas do `standalone.conf.bat` virou uma única linha e o Java subiu **sem nenhuma opção** (sem `-Xmx5G` e sem timeout), falhando por "Timeout after [300] seconds" | Nunca reutilizar nomes de parâmetros; conferir a linha de comando real do `java.exe` (`Win32_Process.CommandLine`) |
| `-match` não diferencia maiúsculas | `'Vers[^<]*'` casou com `version="1.0"` do XML | Usar `-cmatch` |
| `.ps1` sem BOM é lido como ANSI | Acentos corrompidos | Manter os `.ps1` somente em ASCII |
| Programas que escrevem no stderr | Com `$ErrorActionPreference='Stop'`, `2>&1` vira exceção | Função `Invoke-Nativo`: `Continue` temporário e conferência do `$LASTEXITCODE` |
| `Remove-Item -Recurse` e caminhos longos | Na reinstalação, a pasta do WildFly não era apagada: a aplicação descompactada em `standalone\tmp` tem caminhos de até ~440 caracteres, e o Windows sem `LongPathsEnabled` falha | `Remover-Pasta` com `robocopy /MIR` a partir de uma pasta vazia |
| `pg_ctl start` em pipe | O comando "trava": o processo do servidor herda a saída | Usar o serviço do Windows (`pg_ctl register`) e esperar com `pg_isready` |
| Argumento vazio para programas | O PS 5.1 descarta `""` | Trocar a conta do serviço via `Win32_Service.Change` (CIM) em vez de `sc.exe ... password= ""` |

### Windows

| Problema | Sintoma | Solução |
|---|---|---|
| `NoDefaultCurrentDirectoryInExePath=1` (endurecimento presente em algumas máquinas) | `cmd /c standalone.bat` dá "não é reconhecido como comando" | O Procrun chama `standalone.bat` e `jboss-cli.bat` pelo **caminho completo** |
| `initdb` como administrador | O PostgreSQL roda com token restrito (sem o grupo Administradores) e não consegue gravar numa pasta liberada só para Administradores | Conceder acesso temporário ao SID do usuário na pasta de dados e retirar depois (exceto quando o usuário é SYSTEM) |
| Nomes de contas localizados (ex.: "AUTORIDADE NT\SERVIÇO LOCAL") | `icacls` com nomes falha em Windows em português | Usar SIDs: `*S-1-5-18` (SYSTEM), `*S-1-5-32-544` (Administradores), `*S-1-5-19` (LocalService), `*S-1-5-20` (NetworkService), `*S-1-5-32-545` (Usuários) |
| Herança de permissões de `C:\` | Usuários autenticados podem alterar subpastas criadas na raiz | `icacls /inheritance:r` na pasta de instalação; a pasta do WildFly (com senhas) só para SYSTEM, Administradores e a conta do serviço |
| `tar.exe` errado no PATH | Com o Git instalado, `tar.exe` pode ser o GNU tar do Git, que não entende `C:\...` ("Cannot connect to C: resolve failed") | Os scripts usam sempre `%SystemRoot%\System32\tar.exe` (bsdtar do Windows) |
| Endereço do atalho | O IP muda de máquina para máquina | Atalho e navegador usam `http://localhost:<porta>/aghu`; o IP aparece só como "acesso pela rede" |
| Acentos na barra de progresso | Mensagens do Windows ("Aguardando que o serviço...") aparecem como `servi?o`: o PowerShell escreve na página de código do console (850) e o `ExecAndLogOutput` lê UTF-8 | Com a saída redirecionada, `comum.ps1` troca o `Console.Out` por um escritor UTF-8 **sem** mudar `[Console]::OutputEncoding`, que continua sendo usada para ler a saída de `sc`, `icacls` e `psql`. Os avisos do `Start-Service` ficam ocultos (`$PSDefaultParameterValues`) |

### Inno Setup (Pascal Script)

- Não há `VarToStr`, `StringReplace` nem procedimentos aninhados. Use atribuição direta de `Variant` para `String`, `StringChangeEx` e rotinas de nível superior.
- Funções precisam ser declaradas antes do uso.
- `TNewCheckBox` não tem `WordWrap`.
- `ExecAndLogOutput` (6.3+) entrega cada linha do motor a um callback e mantém a janela responsiva.
- Desinstalação: a pergunta é afirmativa ("Deseja APAGAR também todos os dados e configurações?"). **Sim** chama `desinstalar.ps1` sem `-ManterBanco` e apaga PostgreSQL, AD LDS e `C:\ProgramData\AGHUse`; **Não**, o botão padrão (também em `/SILENT`), mantém os dados.
- O setup termina com código 0 se os arquivos foram copiados, mesmo que o motor (`instalar.ps1`) falhe depois. A função de evento `GetCustomSetupExitCode` devolve 1 nesse caso, para quem automatiza com `start /wait ... & echo %ERRORLEVEL%`.
- Ao gerar trechos do `.iss` com Python, `\a`, `\n`, `\f` e `\v` em caminhos Windows viram caracteres de controle. Use strings *raw* ou edite o arquivo diretamente.

### Linux / bash

| Problema | Sintoma | Solução |
|---|---|---|
| PostgreSQL "online" mas ainda iniciando | Logo após o boot, `psql` falha com *"the database system is starting up"* | O motor espera `pg_isready` (até 5 min) antes de usar o banco |
| `trap ERR` com `set -E` dentro de `$( ... )` | Mensagem falsa "Falha na etapa" sem interromper a instalação | `|| true` **dentro** do subshell da consulta; `return 0` no fim de `detectar_outros` |
| PostgreSQL da mesma versão era ignorado | O caso mais arriscado (o motor reaproveita o cluster e cria usuários nele) não gerava aviso | Listar os bancos que não são do AGHUse em todos os clusters |
| `whiptail --textbox` com `--scrolltext` | O Enter não aciona o Ok (o foco começa no texto) | Título orienta "TAB e Enter"; testes automatizados enviam TAB + Enter |
| `grep -c ... \|\| echo 0` | Imprimia `0` duas vezes (o `grep -c` já imprime 0) | `N=$(grep -c ...); N=${N:-0}` |
| Git Bash no Windows | Caminhos `/opt/...` passados a ferramentas viram `C:/Program Files/Git/opt/...` | `MSYS_NO_PATHCONV=1` |

---

## 6. Como testar

Use sempre máquinas virtuais descartáveis.

| Teste | Windows | Linux |
|---|---|---|
| Instalação nova | VM limpa com 12 GB ou mais, setup em modo silencioso e depois com telas | Ubuntu 22.04 limpo, `sudo ./instalar-assistente.sh` |
| Reinstalação | Rodar o setup de novo: o banco é preservado e a configuração anterior vai para `backup` | Rodar o assistente de novo e escolher "Manter os dados" |
| Outros sistemas | Máquina com PostgreSQL/SQL Server/e-SUS: a tela de aceite deve aparecer e bloquear sem a confirmação | Máquina com nginx ou outro PostgreSQL: o assistente pede o aceite e o motor recusa sem ele |
| Verificação | `verificar.bat` (6 itens OK) | `sudo ./verificar.sh` (7 itens OK) |
| Login | `AGHU` com a senha do arquivo de credenciais; senha errada recusada | idem |
| Contas (modo banco) | `usuario.bat criar LOGIN` → login recusado com "usuário não encontrado" até haver o cadastro na aplicação | `sudo ./usuario.sh criar LOGIN` |

Para testar telas de terminal sem interação humana, é possível conduzir o `whiptail` por um PTY via SSH (por exemplo, Python com `paramiko` e o emulador de terminal `pyte`), enviando as teclas e registrando cada tela.

---

## 7. Original e variantes

Cada versão sai em dois pacotes: **original** (a aplicação oficial, sem alterações) e **variante** (com modificações nossas no código-fonte do AGHUse, documentadas em [`modificacoes/`](../modificacoes/)). O código do instalador é o mesmo; muda só a aplicação (`aghu.ear`) e o arquivo `VARIANTE`, que fica na raiz do pacote e identifica a variante.

| | Original | Variante |
|---|---|---|
| `aghu.ear` | oficial (`pacote/aghu.ear.parte-*`) | o da variante, dividido em partes iguais às do original |
| `pacote/SHA256SUMS` | do repositório | linha do `aghu.ear` substituída pelo hash da variante |
| `VARIANTE` | ausente | `NOME`, `VERSAO`, `DESCRICAO`, `COMMIT_APLICACAO`, `SHA256_AGHU_EAR` |
| Instalador | — | mostra a `DESCRICAO` no início, no título do assistente e no final; grava "Aplicacao: ..." no arquivo de credenciais |

Para gerar:

```bash
# Linux (na raiz do repositório)
python3 distribuicao/gerar-pacote-linux.py aghuse-13.250-STABLE-linux.tar.gz
python3 distribuicao/gerar-pacote-linux.py aghuse-13.250-STABLE_variante-integracao-ldap-1-linux.tar.gz --variante <pasta com aghu.ear e VARIANTE>
```

```powershell
# Windows
powershell -ExecutionPolicy Bypass -File windows\setup\gerar-setup.ps1
powershell -ExecutionPolicy Bypass -File windows\setup\gerar-setup.ps1 -Variante <pasta com aghu.ear e VARIANTE>
```

**O que vai em cada pacote:** só o necessário para instalar naquele sistema. O pacote Linux é montado por uma lista explícita em `distribuicao/gerar-pacote-linux.py`: os scripts da raiz, `lib/`, `pacote/`, `dependencias/`, o README, a licença e o guia de cadastro. O instalador Windows leva só os arquivos de `windows/` e os componentes do Windows. Ficam **somente no repositório** `windows/` (no pacote Linux), `distribuicao/`, o código-fonte, o *patch* e os testes de `modificacoes/` e estas notas técnicas. A variante leva apenas o `VARIANTE` e o resumo `modificacoes/integracao-ldap/README.md`.

O `aghu.ear` da variante é compilado do código do AGHUse com o *patch* aplicado ([modificacoes/integracao-ldap/README.md](../modificacoes/integracao-ldap/README.md), seção 6). Ele não é versionado no repositório: vai só nos pacotes.

### Armadilhas ao modificar e compilar o AGHUse

| Problema | Sintoma | Solução |
|---|---|---|
| Os textos das telas são empacotados pelo módulo `aghu-messages-bundle`, não pelo `aghu-web` | Mensagem nova aparece como código (`CASCA_MENSAGEM_...`) | Recompilar também `aghu-messages-bundle` (`-pl aghu-messages-bundle,aghu-casca,aghu-web,aghu-ear`) |
| O repositório Maven do pacote oficial não traz o *provider* JUnit 5 do Surefire | `surefire-junit-platform ... absent` em modo offline | Rodar os testes uma vez com internet (sem `-o`) |
| Telas abertas fora do menu | Abrir `pages/.../tela.xhtml` direto na URL derruba a sessão na segunda visita | Nos testes de tela, abrir pelo menu ("Pesquisar no Menu"); a tela carrega num *iframe* |
| `showLabel` do componente `mec:field` recebendo texto | Rótulo do campo não aparece (só "?" e "*") | `showLabel="true"` (40 telas usam assim; 2 tinham o defeito, uma delas a de troca de senha) |
| Inno Setup: linha que começa com `#` (ex.: `#13#10 +`) | "Unknown preprocessor directive" | Começar a linha com `'' + #13#10` |
| Dois primeiros logins simultâneos do mesmo usuário (defeito do AGHUse, original e variante) | Depois do login, a página fica **em branco**; no `server.log`: `A ID de componente panel_22795 já foi encontrada na visualização`. No primeiro login, o AGHUse grava os ícones da tela inicial em `casca.csc_dashboard`; com dois logins ao mesmo tempo, tudo é gravado em dobro, e a restrição única da tabela não impede porque `modal`/`id_favorito` ficam `NULL` | O instalador remove as duplicatas e cria o índice `csc_dsh_uk_instalador` sobre `(id_usuario, coalesce(modal,''), coalesce(id_favorito,-1))`. Numa instalação antiga, rodar os mesmos dois comandos SQL (em `instalar.sh`, logo após "acesso ao banco restrito") |
| WildFly com 4 GB de memória (o instalador Linux usava 4G quando a máquina informava menos de 12 GB; uma VM de 12 GB aparece como 11 GB) | A primeira inicialização não termina (`aghu.ear.isdeploying` por mais de uma hora) e o `server.log` registra `java.lang.OutOfMemoryError: Java heap space` | 5G passou a ser o padrão e o mínimo nos dois instaladores; `MEMORIA_JVM` abaixo de 5G é recusado |
| **Criar Login** no servidor 9999999/955 (o do `AGHU` na base inicial) | O vínculo (`agh.rap_servidores.usuario`) passa para o login novo; o `AGHU` continua na sessão aberta, mas a troca de senha responde "senha atual não confere" (a conferência refaz a autenticação: `Nenhum Servidor do HU encontrado associado ao usuário AGHU`, `ELY01151`), e um novo login é recusado | O instalador devolve o vínculo ao `AGHU` e cria o *trigger* `trg_instalador_protege_admin` (função `agh.instalador_protege_servidor_admin`), que recusa trocar o `usuario` desse servidor. Testado numa transação desfeita: o reparo funciona, a troca é recusada e os demais servidores não são afetados |
| Modo `banco`: datasource de login transacional | Tela Senha responde "Senha atual não conferem" com a senha certa (`ARJUNA012140 ... multiple last resources`) | Instalador cria o `aghuLoginDatasource` com `jta="false"` |
| bash: `grep` sem resultado dentro de `< <( ... )` com `set -E` | Mensagem falsa "Falha na etapa" (o trap ERR roda no subshell) | `|| true` dentro da substituição |

### LDAP local no Windows (AD LDS)

O `ldap-local` do Windows usa o **AD LDS** (*Active Directory Lightweight Directory Services*), componente gratuito do Windows: recurso opcional `DirectoryServices-ADAM-Client` no Windows 10/11, função `ADLDS` no Windows Server. Código em `windows/lib/ldaplocal.ps1`.

| Item | Valor |
|---|---|
| Instância / serviço | `aghuseldap` / `ADAM_aghuseldap` (conta NetworkService), dados em `C:\AGHUse\adlds` |
| Portas | 50389 (LDAP) e 50636 (LDAPS); regras de **entrada** do firewall desativadas: só este computador |
| Partição | `DC=aghuse,DC=local`; contas em `OU=people`, conta de serviço `CN=aghuse-leitura,OU=servicos` |
| Esquema | `MS-InetOrgPerson.LDF`, `MS-User.LDF`, `MS-UserProxy.LDF` (importados na criação) |
| Login no AGHUse | `LDAP_USER_DN=CN=%s,OU=people,DC=aghuse,DC=local`, filtro `(&(objectClass=inetOrgPerson)(uid=%s))` |
| Administração | qualquer Administrador do Windows (SID `S-1-5-32-544` no papel `Administrators` da instância), via `usuario.bat` ou `ldp.exe` |

| Problema | Sintoma | Solução |
|---|---|---|
| `Administrator=` com um grupo no arquivo de respostas | `adaminstall` sai com **20085** em 2 s ("Depois de atualizar o arquivo de instalação autônoma..."); o `adamsetup.log` diz que é preciso ser administrador da instância para importar os LDF | Não informar `Administrator=` (fica quem instala) e incluir o grupo Administradores depois, por SID: `member: <SID=S-1-5-32-544>` em `CN=Administrators,CN=Roles,<configuração>` |
| Nome da instância igual ao do serviço do AGHUse | O AD LDS registra `ADAM_<instância>` com **nome de exibição** igual ao da instância. Com a instância `aghuse`, `Get-Service -Name aghuse` devolvia o serviço do LDAP: o instalador "iniciava" o LDAP (já ativo) e esperava 15 minutos por um WildFly que nunca foi iniciado | Instância `<SERVICO>ldap` (`aghuseldap`, serviço `ADAM_aghuseldap`) |
| `adamuninstall /force` | Mostra a caixa "A remoção do AD LDS foi bem-sucedida" e espera um clique para sempre (em modo silencioso, trava) | `/q /force` e limite de tempo; o `adaminstall` também tem limite (20 min) |
| Troca de senha sem TLS | `unicodePwd` recusado fora de LDAPS | `dSHeuristics=0000000001001` (13º caractere = 1). Aceitável só porque a porta não é exposta na rede |
| Usuário comum não enxerga o diretório | Busca feita com a própria conta retorna "O objeto não existe"; a troca de senha da variante não acha o DN | Toda conta criada entra no papel `CN=Readers,CN=Roles,DC=aghuse,DC=local` |
| Password Modify (RFC 3062) | AD LDS responde `protocolError` | A variante cai no método do AD (remove + add em `unicodePwd`), testado |
| PowerShell: `function Pwd` / `function R` | Não são chamadas: `pwd` e `r` são *aliases* (Get-Location, Invoke-History), que têm prioridade sobre funções | Nomes que não colidem (`Ldap-SenhaUnicode`) |
| PowerShell: função que devolve `byte[]` | O array é "desenrolado" em `object[]` e o servidor recebe bytes como texto ("CONSTRAINT_ATT_TYPE ... unicodePwd") | Devolver com vírgula: `return , $bytes` |
| `SearchRequest` com lista de atributos `@(...)` | Nenhum atributo volta | Passar `[string[]]@(...)` |
| Política de senha do Windows Server (complexidade) | Senha gerada sem número ou sem maiúscula é recusada | `Gerar-SenhaForte` garante maiúscula, minúscula e número |

## 8. Limitações conhecidas

- **Windows, LDAP local:** o AD LDS precisa do recurso opcional do Windows. Em máquinas sem a imagem completa (alguns Windows "N" ou instalações reduzidas), habilitá-lo pode exigir internet ou a mídia de instalação.
- **Windows:** o setup tem ~960 MB porque inclui tudo. Ele é distribuído na página *Releases* do GitHub, não no repositório.
- Os instaladores não configuram ambientes distribuídos: vários servidores de aplicação, banco separado ou balanceamento.
