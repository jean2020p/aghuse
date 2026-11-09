# Instalador AGHUse 13.250-STABLE para Linux

Instalação automatizada do **AGHUse – Aplicativo para Gestão Hospitalar** em um servidor Linux. Com um comando, o instalador prepara Java, servidor de aplicação, banco de dados, base inicial, autenticação e serviço do sistema.

O AGHUse é desenvolvido pelo Hospital de Clínicas de Porto Alegre (HCPA) e mantido pela Comunidade AGHUse. Ele tem origem comum com o **AGHU – Aplicativo de Gestão para Hospitais Universitários**, a versão distribuída pela Ebserh aos hospitais universitários federais.

---

## Aviso importante

> **Este pacote destina-se exclusivamente a TESTE, AVALIAÇÃO e ESTUDO do sistema.**
>
> - É fornecido **"no estado em que se encontra", sem garantia de qualquer natureza e sem suporte técnico**.
> - É uma iniciativa independente. **Não é uma distribuição oficial** do AGHUse e não tem vínculo com a Comunidade AGHUse, o Hospital de Clínicas de Porto Alegre ou a EBSERH.
> - O suporte técnico ao AGHUse é prestado pela Comunidade AGHUse **somente às instituições integrantes da comunidade**. Fora dela, o acesso se limita aos arquivos e às instruções de instalação.
> - Quem instala, configura e opera o sistema assume toda a responsabilidade por seu uso, pela segurança das informações e pelo cumprimento da legislação aplicável, inclusive a LGPD.
> - **Use uma máquina dedicada e recém-instalada**, física ou virtual, com Linux e sem outros sistemas em funcionamento. **Não execute o instalador em servidores que já estão em produção ou que hospedam outros sistemas.** Ele instala e reconfigura pacotes e serviços (PostgreSQL, OpenLDAP, Java, serviços systemd) e altera permissões de banco de dados, o que pode afetar aplicações existentes. A execução em máquinas compartilhadas é feita **por conta e risco** de quem a realiza.
> - O uso com dados reais de pacientes exige a validação descrita em [Uso em produção](#uso-em-produção).

---

## O que é instalado

| Componente | Versão | Origem |
|---|---|---|
| AGHUse | 13.250-STABLE (compilado do código-fonte, com identificação de versão e data) | incluído no pacote |
| Base inicial do banco | base de demonstração, sem dados de pacientes | incluída no pacote |
| OpenJDK | 17.0.2 | `dependencias/java` (obtido de jdk.java.net), conferido por SHA-256 |
| WildFly | 26.1.3.Final | `dependencias/wildfly` (obtido de github.com/wildfly), conferido por SHA-256 |
| PostgreSQL | 15 (configurável) | `dependencias/apt` (obtido de apt.postgresql.org) |
| OpenLDAP | versão da distribuição | só no modo `ldap-local`; `dependencias/apt` (obtido dos repositórios do Ubuntu) |

## Origem dos arquivos

| Arquivo | Fonte |
|---|---|
| `aghuse_28052025.zip`: código-fonte do AGHUse 13.250-STABLE, base inicial (`esperanto_20250528.dmp`) e manual `Montagem_do_Ambiente_CD_AGHUSE.pdf` | https://drive.google.com/file/d/13xhhZt9QcydvJ9beILK5mNCYp2aSxdpH/view?usp=sharing |
| OpenJDK 17, Apache Maven 3.9.9 e WildFly 26.1.3.Final | Fontes oficiais indicadas no manual `Montagem_do_Ambiente_CD_AGHUSE.pdf`: jdk.java.net, maven.apache.org e wildfly.org |
| PostgreSQL 15 | Repositório oficial do PostgreSQL (apt.postgresql.org). O manual não define a versão do banco; foi adotada a mesma versão principal em que a base inicial foi gerada (PostgreSQL 15.3) |
| OpenLDAP e utilitários do sistema | Repositórios oficiais da distribuição Linux |

A aplicação `aghu.ear` deste pacote foi compilada a partir do código-fonte contido no `aghuse_28052025.zip`, seguindo o procedimento de compilação do projeto.

## Requisitos

| Recurso | Mínimo | Recomendado |
|---|---|---|
| Processador | 4 núcleos x86_64 | 6 núcleos ou mais |
| Memória RAM | 8 GB | **16 GB** |
| Disco | 40 GB livres | **100 GB** (SSD) |
| Sistema operacional | Ubuntu Server 22.04 LTS | Ubuntu Server 22.04 LTS |
| Rede | IP fixo na rede interna | IP fixo e nome DNS interno |

- O WildFly reserva 5 GB de memória para a aplicação; o mínimo aceito é 4 GB, e com menos o sistema não inicializa. O PostgreSQL e o sistema operacional precisam do restante. Com menos de 12 GB de RAM, o instalador usa 4 GB; com menos de 8 GB, a instalação é recusada.
- O espaço em disco recomendado considera o crescimento do banco, os logs, os índices de busca e os backups locais.
- **Sistemas suportados:** Ubuntu Server 22.04 LTS (instalação completa sem internet). Ubuntu 24.04 LTS e Debian 12 também são aceitos, mas o PostgreSQL e o OpenLDAP são baixados dos repositórios oficiais.
- **Máquina dedicada:** servidor ou máquina virtual com Linux recém-instalado, reservado só para o AGHUse. Não use servidores com outros sistemas em funcionamento (veja o [Aviso importante](#aviso-importante)). Uma máquina virtual permite descartar o ambiente e repetir a instalação com facilidade.
- **Acesso:** usuário com permissão de administrador (`sudo`).
- **Navegador:** versões atuais do Google Chrome, Mozilla Firefox ou Microsoft Edge.
- **Internet:** não é necessária no Ubuntu 22.04. Todos os componentes estão na pasta `dependencias/`. Em outras versões do sistema, o PostgreSQL e o OpenLDAP são baixados dos repositórios oficiais.

## Conteúdo do pacote

```
aghuse/
├── instalar.sh          instalador
├── aghuse.conf          parâmetros da instalação (edite antes de instalar)
├── usuario.sh           contas de acesso (login e senha) no diretório LDAP
├── verificar.sh         verificação do estado da instalação
├── README.md            este documento
├── LICENSE              licença GPL v2
├── lib/
│   └── configurar_wildfly.py
├── pacote/
│   ├── aghu.ear                         aplicação AGHUse
│   ├── dbaghu.dmp                       base inicial (PostgreSQL)
│   ├── wildfly-aghuse-overlay.tar.gz    módulos e configuração do AGHUse para o WildFly
│   ├── wildfly-aghuse-removidos.txt
│   └── SHA256SUMS                       hashes de integridade
└── dependencias/                        componentes obtidos das fontes oficiais
    ├── java/                            OpenJDK 17.0.2
    ├── wildfly/                         WildFly 26.1.3.Final
    ├── apt/ubuntu-22.04/                pacotes do PostgreSQL 15, OpenLDAP e utilitários
    └── SHA256SUMS
```

O instalador usa primeiro os arquivos da pasta `dependencias/` e só busca na internet o que não estiver nela. Os hashes SHA-256 de todos os arquivos são conferidos antes da instalação.

---

## Arquitetura recomendada

### Teste e avaliação: servidor único

Para testes, um único servidor com a aplicação e o banco de dados é suficiente, com os requisitos da seção anterior. **O instalador configura essa arquitetura:** aplicação, banco e, opcionalmente, o LDAP no mesmo servidor.

### Produção: servidores separados

Em produção, a aplicação e o banco de dados devem ficar em servidores distintos, com redundância. Há duas referências públicas.

**Infraestrutura mínima.** Fonte: [Nota Técnica CONASS nº 05/2023](https://www.conass.org.br/biblioteca/wp-content/uploads/2024/09/NT-05-2023-software-hospitalar.pdf), "Requisitos técnicos", infraestrutura mínima estabelecida para o AGHU, a versão da Rede Ebserh, com a mesma arquitetura.

| Função | Quantidade | vCPU | Memória RAM | Disco |
|---|---|---|---|---|
| Servidor web / balanceador de carga (Apache com `mod_jk`, protocolo AJP) | 1 | 4 | 16 GB | 20 GB |
| Servidor de aplicação (WildFly) | 3 | 4 (cada) | 16 GB (cada) | 50 GB (cada) |
| Servidor de banco de dados (PostgreSQL, principal e réplica, com `pgbouncer`) | 2 | 8 (cada) | 24 GB (cada) | 100 GB (cada) |
| Servidor de impressão (CUPS) | 1 | 2 | 4 GB | 20 GB |

Total de 7 máquinas virtuais. Mais servidores de aplicação podem ser incluídos no balanceamento conforme a demanda.

**Instituição de grande porte.** Fonte: [Cardápio AGHUse](https://www.hcpa.edu.br/downloads/ccom/inst_projeto_aghuse/cardapio_aghuse_site.pdf), do Hospital de Clínicas de Porto Alegre, "Requisitos de configuração da infraestrutura de servidores físicos ou virtuais – ambiente de produção".

| Função | Quantidade | vCPU | Memória RAM | Disco |
|---|---|---|---|---|
| Servidor de aplicação (WildFly) | 8 nós | 12 | 16 GB | 30 GB |
| Servidor de banco de dados (PostgreSQL) | 2 nós | 24 | 128 GB | 2 TB + 500 GB de backup |
| Balanceamento de carga (Apache) | 2 nós | 8 | 8 GB | 120 GB |
| Servidor de impressão (CUPS) | 1 | 8 | 8 GB | 40 GB |

**Rede, segundo a mesma referência:**
- núcleo de 10 Gigabit Ethernet para os servidores e borda Gigabit para as estações;
- switch core redundante em camada 3 e switches de borda gerenciáveis em camada 2;
- conexão por fibra óptica entre os switches de borda e o core;
- firewall redundante de nova geração e rede DMZ para os servidores;
- uma VLAN para cada função: servidores, microcomputadores, impressoras e access points;
- software de gerência e monitoramento da rede.

**Também segundo a referência:**
- É recomendado manter um **ambiente de homologação** separado para testar novas versões, com no mínimo a configuração de uma instituição de pequeno porte.
- O AGHUse é homologado para os bancos de dados **PostgreSQL e Oracle**.

**Observações:**
- Dimensione entre as duas referências de acordo com o número de leitos, de usuários simultâneos e de módulos em uso.
- As duas referências citam versões de sistema operacional, PostgreSQL e Java já descontinuadas (Debian 6 a 8, PostgreSQL 9.4, Java 7). Use versões atuais e com suporte: por exemplo, Ubuntu Server 22.04 LTS ou Debian 12, PostgreSQL 15 e Java 17 nos servidores.
- Este instalador não configura ambientes distribuídos: servidores de banco separados, múltiplos nós de aplicação ou balanceamento de carga. Esses ambientes exigem projeto e implantação pela equipe técnica da instituição.

---

## Equipe recomendada

O AGHUse é um sistema de grande porte, que abrange processos assistenciais, administrativos e de apoio. Sua implantação exige equipe multiprofissional, não apenas técnica.

A [Nota Técnica CONASS nº 05/2023](https://www.conass.org.br/biblioteca/wp-content/uploads/2024/09/NT-05-2023-software-hospitalar.pdf) ("Equipe para implantação e suporte ao AGHU", Quadros 3 e 4) registra a orientação da Ebserh para a implantação do AGHU, que tem a mesma arquitetura. Ela prevê duas equipes.

**Equipe de coordenação técnica**: profissionais com experiência em processos de gestão e assistência hospitalar.

| Profissional | Perfil | Atribuições principais |
|---|---|---|
| Enfermeiro ou médico (1) | Ao menos 2 anos de experiência em assistência ou gestão hospitalar, ou residência em especialidade hospitalar | Coordenar a implantação nos setores assistenciais, planejar capacitações e educação permanente, avaliar o uso do sistema e participar da especificação de novas funcionalidades |
| Farmacêutico (1) | Mesma experiência | Coordenar a implantação na assistência farmacêutica (prescrição, dispensação e estoque) |
| Gestor administrativo (1) | Curso superior e ao menos 2 anos em assistência ou gestão hospitalar | Coordenar a implantação nos setores administrativos (compras, estoque, faturamento e custos) |
| Gestor de TI (1) | Curso superior em computação ou área similar e ao menos 2 anos de experiência | Planejar e coordenar a instalação e o suporte local, as contratações e aquisições, e dimensionar as equipes de desenvolvimento e infraestrutura |

**Equipe mínima de tecnologia da informação**: instalação, sustentação e evolução.

| Profissional | Atribuições principais |
|---|---|
| Analista de sistemas (1) | Desenvolvimento em Java, soluções acessórias ao sistema, extração de dados com ferramentas de *Business Intelligence* e levantamento de requisitos |
| Analista de sustentação (1) | Triagem de chamados, treinamentos técnicos e operacionais, investigação de incidentes, pareceres e notas técnicas |
| Administrador de dados PostgreSQL (1) | Desempenho, integrações, migração e carga de dados, backup e controle de acesso ao banco |
| Analista de infraestrutura Linux (1) | Preparação e instalação do ambiente, servidores de aplicação, balanceamento, monitoramento e investigação de incidentes de infraestrutura |

Para a avaliação com este instalador, basta **um profissional de TI** com conhecimento de Linux, PostgreSQL e servidores de aplicação Java. A equipe acima é a referência para a implantação em produção.

---

## Instalação

**1. Baixe o instalador no servidor**

```bash
sudo apt-get install -y git
git clone https://github.com/jean2020p/aghuse.git
cd aghuse
```

Também é possível baixar o arquivo ZIP pelo botão **Code → Download ZIP** desta página e descompactá-lo no servidor. Os arquivos grandes estão divididos em partes de até 95 MB (`*.parte-001`, `*.parte-002` ...), e o instalador os junta automaticamente antes de conferir os hashes SHA-256.

**2. Revise os parâmetros**

```bash
nano aghuse.conf
```

Para um ambiente de teste, os valores padrão já servem: o login é feito em um diretório LDAP instalado no próprio servidor (`MODO_LOGIN="ldap-local"`).

**3. Execute o instalador**

```bash
sudo ./instalar.sh
```

A instalação leva de 20 a 60 minutos, conforme o desempenho do disco. A restauração da base inicial é a etapa mais demorada; em disco SSD, leva cerca de 15 minutos. No final, o instalador mostra o endereço de acesso e onde ficou gravada a senha do administrador.

**4. Acesse o sistema**

```
http://<ip-do-servidor>:8080/aghu
```

- **Usuário:** `AGHU`
- **Senha:** gerada na instalação e gravada em `/root/aghuse-credenciais-aghuse.txt`.

Para consultar a senha:

```bash
sudo cat /root/aghuse-credenciais-aghuse.txt
```

---

## Acesso por HTTPS (proxy reverso)

Em produção, o AGHUse deve ser publicado atrás de um proxy reverso (nginx, Apache ou balanceador), que recebe as conexões HTTPS e as repassa ao WildFly.

**Configuração necessária no WildFly.** No arquivo `standalone-full.xml`, o `http-listener` precisa do atributo `proxy-address-forwarding="true"`:

```xml
<!-- com proxy reverso e HTTPS -->
<http-listener name="default" socket-binding="http" redirect-socket="https" proxy-address-forwarding="true" .../>

<!-- sem proxy e sem HTTPS (acesso direto) -->
<http-listener name="default" socket-binding="http" redirect-socket="https" .../>
```

Sem esse atributo, o WildFly não reconhece que o acesso original foi feito por HTTPS. Depois de clicar em **Acessar**, o navegador é redirecionado para `http://...` em vez de `https://...`, e o login falha. Com o atributo, o WildFly usa os cabeçalhos `X-Forwarded-Proto`, `X-Forwarded-Host` e `X-Forwarded-For` enviados pelo proxy.

O instalador aplica o atributo quando `PROXY_REVERSO="sim"`. Use também `HTTP_BIND="127.0.0.1"` (ou restrinja a porta 8080 no firewall), para que ninguém acesse o WildFly direto, sem passar pelo proxy. Com o atributo ligado, os cabeçalhos `X-Forwarded-*` passam a ser aceitos, e só o proxy deve conseguir enviá-los.

**Exemplo de configuração do nginx:**

```nginx
server {
    listen 443 ssl http2;
    server_name aghuse.instituicao.uf.gov.br;
    ssl_certificate     /etc/ssl/certs/aghuse.crt;
    ssl_certificate_key /etc/ssl/private/aghuse.key;

    location /aghu {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host              $host;
        proxy_set_header X-Real-IP         $remote_addr;
        proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Port  443;
        proxy_read_timeout 300s;
        client_max_body_size 350m;
    }
}

server {
    listen 80;
    server_name aghuse.instituicao.uf.gov.br;
    return 301 https://$host$request_uri;
}
```

A tela do sistema usa *websocket* para avisos de sessão. Se o proxy tiver regras específicas para *websocket*, inclua também `proxy_http_version 1.1`, `proxy_set_header Upgrade $http_upgrade` e `proxy_set_header Connection "upgrade"`.

---

## Parâmetros (`aghuse.conf`)

| Parâmetro | Padrão | Descrição |
|---|---|---|
| `AMBIENTE` | `teste` | `teste` ou `producao`. Em produção, há verificações adicionais. |
| `CONFIRMO_PRODUCAO` | `nao` | Precisa ser `sim` quando `AMBIENTE=producao`. |
| `NOME_AMBIENTE` | `AGHUSE-TESTE` | Nome de identificação do ambiente. |
| `MODO_LOGIN` | `ldap-local` | `ldap-local`, `ldap-externo` ou `banco` (ver [Autenticação e usuários](#autenticação-e-usuários)). |
| `ADMIN_LOGIN` / `ADMIN_SENHA` | `AGHU` / gerada | Administrador da base inicial. |
| `PG_VERSAO` | `15` | Versão do PostgreSQL. |
| `PG_PORTA` | automática | Porta do cluster PostgreSQL. |
| `DB_NOME`, `DB_USUARIO`, `DB_SENHA` | `dbaghu`, `ugen_aghu`, gerada | Banco e usuário da aplicação. |
| `RECRIAR_BANCO` | `nao` | `sim` apaga e recria o banco a partir da base inicial. |
| `PREFIXO` | `/opt/aghuse` | Diretório de instalação do Java e do WildFly. |
| `SERVICO` | `aghuse` | Nome do serviço systemd. |
| `USUARIO_SO` | `aghuse` | Usuário do sistema que executa o WildFly. |
| `HTTP_BIND` | `0.0.0.0` | Interface de rede da aplicação (`127.0.0.1` para uso com proxy reverso). |
| `PROXY_REVERSO` | `nao` | `sim` quando o acesso for por um proxy reverso com HTTPS (ver [Acesso por HTTPS](#acesso-por-https-proxy-reverso)). Obrigatório em produção. |
| `PORT_OFFSET` | `0` | Deslocamento de portas (`100` coloca a aplicação na porta 8180). |
| `MEMORIA_JVM` | automática | Memória do WildFly (5 GB recomendados). |
| `FUSO_HORARIO` | `America/Sao_Paulo` | Fuso horário da aplicação. |
| `SMTP_HOST` | `127.0.0.1` | Servidor de e-mail. |

### Senhas

- **Senhas em branco são geradas automaticamente:** 32 caracteres aleatórios, gravados em `/root/aghuse-credenciais-<SERVICO>.txt`, que só o usuário root lê.
- **Senhas informadas manualmente:** só letras e números, com no mínimo 16 caracteres (20 em produção).
- **Senhas dos usuários do banco:** gravadas no formato `scram-sha-256`.
- **Acesso ao PostgreSQL:** somente pela própria máquina.

## Autenticação e usuários

### Como funciona

O AGHUse separa a **conta de acesso** do **cadastro no sistema**:

| O quê | Onde fica | Quem administra |
|---|---|---|
| Login e senha | Diretório LDAP / Active Directory | Administrador do diretório |
| Usuário, perfis e permissões | AGHUse (Configuração → Acesso → Usuário) | Administrador do AGHUse |
| Pessoa e vínculo (servidor, matrícula) | AGHUse (Reg. Colaboradores → Administrar Servidores) | Área de gestão de pessoas |

O AGHUse **não armazena nem altera senhas**; a troca de senha é feita no diretório. A cada login, o sistema verifica, nesta ordem:

1. **Diretório:** autenticação (*bind*) no LDAP/AD com o DN definido em `LDAP_USER_DN` e a senha digitada.
2. **Usuário:** o login está cadastrado no AGHUse e está **ativo**.
3. **Perfil:** o usuário tem ao menos um **perfil ativo** e não expirado.
4. **Vínculo:** existe um **servidor** com esse usuário e vínculo ativo (com lotação, horário e ocupação, quando o vínculo os exige).

Se qualquer etapa falhar, o login é recusado. Nesta versão, o login **não exige grupo no LDAP/AD**: quem controla o acesso, dentro do sistema, são os perfis. Para restringir quais contas do diretório aparecem em **Importar Usuário**, inclua um filtro de grupo em `LDAP_FILTRO`, por exemplo `(&(objectClass=user)(memberOf=CN=AGHUse,OU=Grupos,DC=instituicao,DC=local)(sAMAccountName=%s))`. Esse filtro limita apenas a importação, não o login.

### Modos de autenticação

| Modo | Diretório de senhas | Indicado para |
|---|---|---|
| `ldap-local` (padrão) | OpenLDAP instalado no próprio servidor, acessível só pela própria máquina | Testes e avaliação. Contas criadas com `usuario.sh`. |
| `ldap-externo` | LDAP ou Active Directory da instituição | **Produção** (obrigatório quando `AMBIENTE=producao`). |
| `banco` | Sem diretório: a senha é conferida pelo PostgreSQL, em um banco separado e vazio (`aghuse_login`), sem acesso aos dados | Avaliação sem diretório. Contas criadas com `usuario.sh`. |

**Exemplo de `ldap-externo` com Active Directory:**

```bash
MODO_LOGIN="ldap-externo"
LDAP_HOST="ad.instituicao.local"
LDAP_PORTA="389"
LDAP_USER_DN="%s@instituicao.local"
LDAP_BASE_USUARIOS="DC=instituicao,DC=local"
LDAP_ATRIBUTO_LOGIN="sAMAccountName"
LDAP_FILTRO="(&(objectClass=user)(sAMAccountName=%s))"
LDAP_BIND_DN="svc-aghuse@instituicao.local"   # conta de serviço, usada em "Importar Usuário"
LDAP_BIND_SENHA="..."
```

Antes de instalar, teste o acesso ao diretório a partir do servidor:

```bash
ldapwhoami -x -H ldap://ad.instituicao.local -D "login@instituicao.local" -W
```

### Incluir um novo usuário

O procedimento abaixo foi verificado nesta versão. Cada etapa libera a seguinte; enquanto alguma faltar, o login é recusado, e o log do servidor (`server.log`) indica o motivo.

**1. Conta de acesso no diretório (login e senha)**

- `ldap-externo`: a conta é criada pelo administrador do LDAP/AD da instituição.
- `ldap-local` ou `banco`: na pasta do instalador, execute o comando abaixo. A senha é solicitada no terminal; se ficar em branco, uma senha aleatória é gerada e exibida uma única vez. No modo `banco`, este passo é **obrigatório mesmo para usuários cadastrados pela aplicação**: a aplicação não cria a credencial no PostgreSQL, e sem ela o login é recusado com *"Erro ao conectar no banco com o usuario"*.

```bash
sudo ./usuario.sh criar MSILVA "MARIA SILVA" maria.silva@hospital.org.br
sudo ./usuario.sh senha MSILVA      # redefinir a senha
sudo ./usuario.sh listar
sudo ./usuario.sh remover MSILVA
```

Somente com a conta no diretório, o login é recusado com *"Este usuário não foi encontrado no sistema"*.

**2. Usuário e perfil.** Na aplicação, com um usuário que tenha perfil de administração (na base inicial, `AGHU`, com o perfil `SUPER`):

1. Abra *Outros Módulos → Configuração → Acesso → Usuário* (ou digite "Usuário" em **Pesquisar no Menu**) e clique em **Pesquisar**.
2. Clique em **Importar Usuário**, informe o login e clique em **Pesquisar**. A tela lista as contas do diretório ainda não cadastradas no AGHUse. Clique em **Adicionar**.
3. Confira **Nome** e **E-mail**, que são obrigatórios e vêm do diretório (`displayName` e `mail`), e clique em **Gravar**. O e-mail deve ter um domínio válido, por exemplo `@hospital.org.br`.
4. Na lista de usuários, use a ação **Editar Perfil**, selecione um perfil (a base inicial tem 631 perfis ativos, como `ADM01`), clique em **Adicionar** e em **Gravar**.

Sem perfil, o login é recusado com *"Usuário não tem perfil associado ou todos seus perfis estão inativos"*.

**3. Pessoa.** Abra *Reg. Colaboradores → Administração de Pessoal → Administrar Servidores → Pessoas*, clique em **Pesquisar** e depois em **Novo**. Os campos obrigatórios são nome (igual ao nome do usuário), nome da mãe, sexo, data de nascimento, nacionalidade, número de identidade e CPF válido.

**4. Servidor (vínculo).** Abra *Reg. Colaboradores → Administração de Pessoal → Administrar Servidores → Servidores*, clique em **Pesquisar** e depois em **Novo**. Informe:
- a **pessoa**;
- o **login** do usuário;
- o **vínculo** e a **matrícula** (gerada automaticamente quando o vínculo é configurado para isso);
- o **início do vínculo**;
- **centro de custo de lotação, horário e ocupação**, quando o vínculo os exigir.

Na base inicial, o vínculo `955` (VINCULO INTEGRACAO) não exige esses três últimos dados.

Sem o servidor, o login é recusado com *"Nenhum Servidor do HU encontrado associado ao usuário"*. Com as quatro etapas concluídas, o usuário entra no sistema.

**Caminho sem diretório (modo `banco`).** Como não há diretório para importar, faça primeiro a **Pessoa** (etapa 3) e o **Servidor** (etapa 4) sem informar login. Em seguida, na tela *Usuário*, pesquise pela matrícula: o servidor aparece com a ação **Criar Login**. Ela abre o cadastro com matrícula, nome e vínculo preenchidos e sugere um login a partir do nome; o usuário já fica associado ao servidor. Informe o e-mail, grave, atribua o perfil (**Editar Perfil**) e crie a credencial com `sudo ./usuario.sh criar LOGIN`, usando o mesmo login.

**Observações**
- **Pesquisar primeiro:** os botões **Novo** e **Importar Usuário** aparecem depois de clicar em **Pesquisar**.
- **Acessos simultâneos:** cada usuário tem um limite de sessões simultâneas (campo *Quantidade Máxima de Logins*, padrão 1). Um novo login do mesmo usuário oferece encerrar a sessão anterior.
- **Reiniciar Senha:** a ação *Reiniciar Senha do Usuário*, da tela de usuários, aplica-se apenas ao ambiente do HCPA. Para redefinir senhas, use o diretório ou `usuario.sh senha LOGIN`.
- **Sem sincronização automática:** nesta versão não há sincronização entre o diretório e o AGHUse. A leitura do diretório ocorre apenas na tela **Importar Usuário**, e os cadastros de pessoa e de servidor são feitos na aplicação.

### Contexto: evolução da autenticação

O AGHUse evoluiu ao longo de muitos anos e convive com mecanismos de gerações diferentes. Conhecer essa trajetória ajuda a entender por que existem três modos de login e por que algumas funções da tela de usuários não têm efeito fora da instituição de origem. A síntese abaixo foi feita a partir do código-fonte e da estrutura do banco desta versão; o pacote não inclui o histórico de versões do código.

| Geração | Como o usuário era autenticado | Vestígios nesta versão |
|---|---|---|
| Sistema original em Oracle (Forms/PL-SQL) | Cada pessoa era um usuário do próprio banco de dados, com senha inicial, expiração e troca de senha | Mais de 1.300 classes com regras marcadas como convertidas do Oracle (`ORADB`); colunas `senha_inicial`, `troca_senha_em` e `expirado_em` em `casca.csc_usuario`; o realm `AghuseDbConnectionSecurityRealm` (modo `banco`) |
| Primeiras versões em Java (JBoss) | Módulo de login JAAS (`AghuBaseLoginModule`) | Citado em comentários do código; não existe mais |
| Versão atual (WildFly 26 / Elytron) | Diretório LDAP/Active Directory (`AghuseLdapSecurityRealm`), com o cadastro, os perfis e o vínculo validados no banco | Realm padrão; tela **Importar Usuário** |

**Integração de identidade no ambiente de origem.** O código contém um fluxo de identidade única, usado pelo hospital que desenvolve o sistema. Ao cadastrar um usuário no AGHUse:
- a conta é criada no Active Directory (colunas `cria_user_rede` e `consiste_rede`);
- a conta é incluída em grupos do AD conforme os perfis do sistema (tabela `casca.csc_grupo_ad_usuarios`);
- o acesso remoto por VPN, com autenticação em dois fatores, é liberado por uma tarefa agendada;
- ainda é criado um usuário de banco (somente Oracle), bloqueado logo em seguida, como legado do modelo original.

Esse fluxo depende de serviços internos daquela instituição (parâmetro `P_URL_BARRAMENTO`) e só é executado quando `P_AGHU_PARAMETRO_HU` vale `HCPA`. Nas demais instituições, a conta é criada no diretório pela equipe de TI e o cadastro é feito na aplicação, como descrito em [Incluir um novo usuário](#incluir-um-novo-usuário). Também há parâmetros previstos para login único (SSO, padrão SAML: `login_sso_*`), que vêm vazios.

---

## Após a instalação

| Tarefa | Comando |
|---|---|
| Verificar a instalação | `sudo ./verificar.sh` (na pasta do instalador) |
| Situação do serviço | `sudo systemctl status aghuse` |
| Parar / iniciar / reiniciar | `sudo systemctl stop\|start\|restart aghuse` |
| Log da aplicação | `sudo tail -f /opt/aghuse/wildfly/standalone/log/server.log` |
| Log da instalação | `/var/log/aghuse-instalador-aghuse.log` |
| Credenciais | `sudo cat /root/aghuse-credenciais-aghuse.txt` |

A inicialização do serviço leva de 3 a 10 minutos.

**Backup do banco:**

```bash
sudo -u postgres pg_dump -p <PG_PORTA> -Fc dbaghu > /caminho/backup/dbaghu-$(date +%F).dmp
```

**Reinstalação ou troca de modo de login:** altere o `aghuse.conf` e execute `sudo ./instalar.sh` de novo.
- O banco existente é **preservado** (a menos que `RECRIAR_BANCO="sim"`).
- O WildFly é reinstalado.
- A configuração anterior é guardada em `/opt/aghuse/backup/`.
- As senhas em branco são geradas de novo.

**Remoção:**

```bash
sudo systemctl disable --now aghuse
sudo rm -rf /opt/aghuse /etc/systemd/system/aghuse.service
sudo -u postgres psql -p <PG_PORTA> -c "DROP DATABASE dbaghu"
```

---

## Pontos de atenção

Informações técnicas úteis para quem instala, configura ou compila o AGHUse manualmente. O instalador já trata todos estes pontos.

**Configuração do WildFly (perfil Maven `configuracao`)**
- O comando `mvn initialize -P configuracao` lê os parâmetros nesta ordem, e cada arquivo sobrescreve o anterior: `defaults/*.properties` → `datasource.properties` (artefato `br.gov.mec.aghu.external:<ambiente>-<banco>`) → `env-conf.properties` (artefato `br.gov.mec.aghu.external:environment`).
- O artefato `environment` distribuído com o código contém os parâmetros de rede da instituição de origem: LDAP/AD, servidor de e-mail e URL de documentação. Para usar outros valores, gere um artefato `environment` próprio. Parâmetros LDAP informados em outro lugar são sobrescritos por ele.
- O código traz apenas o artefato de ambiente para Oracle (`homolog-ora`). Para PostgreSQL, crie o equivalente `homolog-pg` com `datasource.url`, `dbuser`, `dbpwd`, `dbuserfit` e `dbpwdfit`.
- Toda nova execução do perfil apaga e recopia `modules/br/gov/mec/aghu` e sobrescreve o `standalone-full.xml`. Ajustes manuais nesses arquivos precisam ser reaplicados.

**Autenticação**
- O realm padrão (`AghuseLdapSecurityRealm`) faz um *bind* LDAP com o DN definido em `sd_user_dn` (o `%s` é o login digitado) e depois valida o cadastro, o perfil e o vínculo do usuário no banco.
- O AGHUse não armazena nem altera senhas: a troca de senha pela aplicação não é suportada quando o login é feito no LDAP/AD.
- **Importar Usuário** consulta o diretório com a conta de serviço (`sd_bind_dn` / `sd_bind_credentials`), a base `sd_user_context_dn` e o filtro `sd_filter_expression`, e traz login, e-mail (`mail`) e nome (`displayName`) das contas ainda não cadastradas.
- Algumas rotinas do cadastro de usuários (criação automática de contas no AD e no banco Oracle e inclusão em grupos do AD) são exclusivas do HCPA: só são executadas quando o parâmetro `P_AGHU_PARAMETRO_HU` vale `HCPA` e dependem de um serviço interno daquela instituição. Mantenha esse parâmetro com a sigla da sua instituição (a base inicial usa `HU_UFGD`).
- Para avaliações sem diretório, existe o realm `AghuseDbConnectionSecurityRealm`, que valida a senha abrindo e fechando uma conexão no PostgreSQL com o login digitado, sem executar consultas. Ele exige a propriedade `loginDatasource` e um datasource com `<allow-multiple-users/>`, e cada login precisa de uma credencial no PostgreSQL.
- Se o `loginDatasource` apontar para o banco da aplicação, cada usuário passa a ter acesso direto a esse banco, inclusive às tabelas e views liberadas a `PUBLIC` na base inicial (mais de mil objetos). O instalador aponta o `loginDatasource` para um banco vazio (`aghuse_login`) e retira de `PUBLIC` o direito de conexão ao `dbaghu`.

**Servidor de aplicação**
- Atrás de um proxy reverso com HTTPS, o `http-listener` do Undertow precisa de `proxy-address-forwarding="true"`; caso contrário, o login falha por redirecionar para `http://`. Ver [Acesso por HTTPS](#acesso-por-https-proxy-reverso).
- O AGHUse grava os índices de busca (Lucene) num caminho relativo à pasta `bin` do WildFly. Em serviços systemd, defina `WorkingDirectory=<wildfly>/bin`; caso contrário, a implantação falha no `WeldStartService`.
- Use o arquivo `standalone-full.xml` e reserve ao menos 5 GB de heap (`-Xms5G -Xmx5G`).

**Banco de dados**
- Antes de restaurar a base, crie as roles referenciadas nas permissões: `acesso_completo`, `acesso_leitura`, `escrita_integra`, `ugen_bi`, `ugen_pesquisa`, `ugen_surex` e `agh`.
- Restaure com `pg_restore --no-tablespaces -j <núcleos>`.
- O driver JDBC distribuído (PostgreSQL 42.6.0) é compatível com autenticação `scram-sha-256`, o padrão das versões atuais do PostgreSQL.

**Compilação a partir do código-fonte**
- Ordem: `aghu-entidades` e depois `aghu`, com `mvn clean install -P '!PMD,gitinfo' -Dmaven.test.skip=true -Dpmd.skip=true`.
- O perfil `gitinfo` registra versão, commit e data da compilação, exibidos na tela de login. Ele exige que o código esteja num repositório git (`git init` e `git commit`, se necessário). Sem o perfil, a tela exibe `???git_commit_id_abbrev???`.
- A opção `--builder smart`, usada em alguns pipelines, requer a extensão Takari Smart Builder. Sem ela, use apenas `--threads 1C`.
- O código acompanha um repositório Maven local (`dependencias-maven`). Aponte o `localRepository` do `settings.xml` para ele.

---

## Aviso de segurança: estrutura herdada do banco de dados

> **Leia antes de qualquer uso com dados reais.** O modelo de permissões do banco do AGHUse foi herdado de gerações anteriores do sistema e concede acessos amplos ao grupo `PUBLIC` do PostgreSQL. Esse grupo inclui **todos** os usuários do banco.

**O que foi verificado na base inicial desta versão (13.250):**

| Privilégio concedido a `PUBLIC` | Quantidade de tabelas e views |
|---|---|
| `SELECT` (leitura) | 865 |
| `INSERT` (inclusão) | 825 |
| `UPDATE` (alteração) | 822 |
| `DELETE` (exclusão) | 820 |
| `TRUNCATE`, `REFERENCES`, `TRIGGER` | 13 |

Também há uso liberado de 8 esquemas (`agh`, `casca`, `pesquisa`, `hist`, `bi`, `conv`, `agh_ceps` e `public`) e execução de 57 funções. Os objetos incluem tabelas relacionadas a pacientes, exames e prescrições, e também **tabelas de auditoria** (`*_aud`, `*_jn`).

**Risco.** Qualquer conta que consiga se conectar ao banco da aplicação herda esses privilégios. Ela pode ler, alterar ou excluir dados clínicos e registros de auditoria diretamente, sem passar pela aplicação, pelos perfis de acesso ou pelos logs do sistema. Exemplos de contas assim: uma conta criada para relatórios ou BI, uma integração, ou contas individuais no modo de login pelo banco.

**Medidas aplicadas por este instalador:**
- o direito de **conexão** ao banco `dbaghu` é retirado de `PUBLIC` e concedido apenas às contas da aplicação (`ugen_aghu` e `ugen_aghu_fit`);
- no modo `banco`, as senhas dos usuários são conferidas em um banco separado e vazio (`aghuse_login`), sem acesso aos dados;
- o PostgreSQL aceita conexões apenas da própria máquina, com autenticação `scram-sha-256`.

**Recomendações para a instituição:**
1. **Contas no banco:** não crie contas no banco da aplicação para pessoas. Integrações, relatórios e BI devem usar contas próprias, com o mínimo de privilégios e acesso preferencialmente a uma réplica ou a views específicas.
2. **Conexão a partir de `PUBLIC`:** antes de conceder `CONNECT` no `dbaghu` a qualquer nova conta, lembre-se de que ela herdará os privilégios de `PUBLIC`.
3. **Revogação dos privilégios de `PUBLIC`:** não revogue diretamente. Nesta versão, a conta da aplicação **depende** desses privilégios em cerca de 855 objetos, que não estão concedidos ao papel `acesso_completo`; a revogação direta interrompe a aplicação. O caminho seguro é:
   1. conceder os mesmos privilégios ao papel da aplicação;
   2. revogar de `PUBLIC`;
   3. homologar todos os módulos em uso.

   Faça isso em ambiente de homologação, com backup, e mantenha o procedimento para reaplicar a cada atualização da base.
4. **Proteção da auditoria:** restrinja `UPDATE`, `DELETE` e `TRUNCATE` nas tabelas de auditoria (`*_aud`, `*_jn`) e mantenha cópias dos logs fora do servidor do banco.
5. **Configurações de fábrica do servidor de aplicação:** revise o usuário interno `ejbuser` (`application-users.properties`), as senhas dos *keystores* em `standalone-full.xml` e as chaves de integração em `app-parameters.properties`. Elas vêm com valores conhecidos, distribuídos com o código-fonte.

**Consultas para auditoria** (como `postgres`, no banco `dbaghu`):

```sql
-- privilégios concedidos a PUBLIC, por tipo
SELECT privilege_type, count(*)
  FROM information_schema.table_privileges
 WHERE grantee = 'PUBLIC' AND table_schema NOT IN ('pg_catalog','information_schema')
 GROUP BY 1 ORDER BY 2 DESC;

-- contas que conseguem se conectar ao banco da aplicação
SELECT rolname FROM pg_roles
 WHERE rolcanlogin AND has_database_privilege(rolname, 'dbaghu', 'CONNECT')
 ORDER BY 1;

-- objetos em que a aplicação depende de PUBLIC (sem privilégio no papel acesso_completo)
SELECT p.table_schema||'.'||p.table_name AS objeto, string_agg(p.privilege_type, ',') AS privilegios
  FROM information_schema.table_privileges p
 WHERE p.grantee = 'PUBLIC' AND p.table_schema NOT IN ('pg_catalog','information_schema')
   AND NOT EXISTS (SELECT 1 FROM information_schema.table_privileges q
                    WHERE q.table_schema = p.table_schema AND q.table_name = p.table_name
                      AND q.privilege_type = p.privilege_type AND q.grantee = 'acesso_completo')
 GROUP BY 1 ORDER BY 1;
```

---

## Uso em produção

O modo `producao` aplica estas verificações:
- exige `CONFIRMO_PRODUCAO="sim"`;
- exige `PROXY_REVERSO="sim"` (acesso somente por proxy reverso com HTTPS);
- exige `MODO_LOGIN="ldap-externo"` (LDAP/Active Directory da instituição);
- exige senhas manuais com no mínimo 20 caracteres.

**Ele não substitui a validação técnica da instituição.** Antes de usar o sistema com dados reais, a instituição deve, no mínimo:

1. **HTTPS:** publicar o sistema somente atrás de um proxy reverso com HTTPS (por exemplo, Nginx ou Apache com certificado válido), com `PROXY_REVERSO="sim"` e `HTTP_BIND="127.0.0.1"`.
2. **Firewall:** liberar apenas as portas necessárias. PostgreSQL (5432) e o console do WildFly (9990) não devem ficar expostos.
3. **Autenticação:** usar o LDAP/Active Directory institucional (`ldap-externo`), de preferência com LDAPS, e uma conta de serviço só de leitura.
4. **Administrador:** criar no diretório institucional a conta do usuário administrador (`AGHU` ou outro login com perfil de administrador), cadastrar usuários nominais para cada profissional e inativar contas genéricas.
5. **Usuários internos do WildFly:** revisar os usuários e as senhas internas do servidor de aplicação (`application-users.properties`, keystores e parâmetros em `app-parameters.properties`) de acordo com a política de segurança da instituição.
6. **Backup:** implantar backup automático e testado do banco (`pg_dump` ou backup físico) e da pasta de configuração do WildFly.
7. **Atualizações:** manter o sistema operacional, o Java e o PostgreSQL com as atualizações de segurança.
8. **Monitoramento:** monitorar o serviço, o espaço em disco, a memória e os logs.
9. **Dimensionamento:** ajustar a memória (`MEMORIA_JVM`) e os recursos do PostgreSQL ao volume de uso.
10. **Validação funcional:** homologar os módulos que serão usados e a integração com os demais sistemas da instituição.
11. **LGPD:** avaliar o tratamento de dados pessoais e sensíveis, os perfis de acesso e os registros de auditoria.
12. **Banco de dados:** aplicar as recomendações do [Aviso de segurança: estrutura herdada do banco de dados](#aviso-de-segurança-estrutura-herdada-do-banco-de-dados).
13. **Equipe:** dispor da [equipe recomendada](#equipe-recomendada) para implantação, sustentação e suporte.

---

## Licenças

- **AGHUse:** © Hospital de Clínicas de Porto Alegre, distribuído sob a Licença Pública Geral GNU (GPL), versão 2 ou posterior. Contato da comunidade: centralAGHUse@hcpa.edu.br.
- **OpenJDK:** GPL v2 com Classpath Exception.
- **WildFly:** Apache License 2.0 / LGPL.
- **PostgreSQL:** PostgreSQL License.
- **OpenLDAP:** OpenLDAP Public License.

Os scripts deste instalador são distribuídos sem garantia, nos mesmos termos da GPL v2 ou posterior.
