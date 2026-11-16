# Instalador AGHUse 13.250-STABLE para Linux

Instalação automatizada do **AGHUse – Aplicativo para Gestão Hospitalar** em um servidor Linux. Com um comando, o instalador prepara Java, servidor de aplicação, banco de dados, base inicial, autenticação e serviço do sistema.

O AGHUse é desenvolvido pelo Hospital de Clínicas de Porto Alegre (HCPA) e mantido pela Comunidade AGHUse. Ele tem origem comum com o **AGHU – Aplicativo de Gestão para Hospitais Universitários**, a versão distribuída pela Ebserh aos hospitais universitários federais.

> **Comunidade AGHUse:** para conhecer o projeto oficial, entrar em contato ou integrar a comunidade, acesse **[https://sites.google.com/hcpa.edu.br/aghuse/sobre-o-aghuse](https://sites.google.com/hcpa.edu.br/aghuse/sobre-o-aghuse)**.

> **Software público e livre.** O AGHUse é desenvolvido pelo Hospital de Clínicas de Porto Alegre, hospital público federal (empresa pública vinculada ao Ministério da Educação e à UFRGS), com recursos públicos, e distribuído como software livre sob a licença GPL v2. Qualquer pessoa ou instituição tem o direito de **baixar, usar, estudar, modificar e redistribuir** o sistema, nos termos da licença, sem custo de licenciamento. Este instalador e as modificações aqui publicadas seguem os mesmos termos, com o código-fonte aberto.

---

## Aviso importante

> **Este pacote destina-se exclusivamente a TESTE, AVALIAÇÃO e ESTUDO do sistema.**
>
> - É fornecido **"no estado em que se encontra", sem garantia de qualquer natureza e sem suporte técnico**.
> - É uma iniciativa independente. **Não é uma distribuição oficial** do AGHUse e não tem vínculo com a Comunidade AGHUse, o Hospital de Clínicas de Porto Alegre ou a EBSERH.
> - O suporte técnico ao AGHUse é prestado pela Comunidade AGHUse **somente às instituições integrantes da comunidade**. Fora dela, o acesso se limita aos arquivos e às instruções de instalação. Para conhecer a comunidade ou integrá-la: [https://sites.google.com/hcpa.edu.br/aghuse/sobre-o-aghuse](https://sites.google.com/hcpa.edu.br/aghuse/sobre-o-aghuse).
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

- O WildFly reserva 5 GB de memória para a aplicação, que é também o mínimo: com 4 GB a primeira inicialização termina em falta de memória (`OutOfMemoryError`). O PostgreSQL e o sistema operacional precisam do restante. Com menos de 8 GB de RAM, a instalação é recusada.
- O espaço em disco recomendado considera o crescimento do banco, os logs, os índices de busca e os backups locais.
- **Sistemas suportados:** Ubuntu Server 22.04 LTS (instalação completa sem internet). Ubuntu 24.04 LTS e Debian 12 também são aceitos, mas o PostgreSQL e o OpenLDAP são baixados dos repositórios oficiais.
- **Máquina dedicada:** servidor ou máquina virtual com Linux recém-instalado, reservado só para o AGHUse. Não use servidores com outros sistemas em funcionamento (veja o [Aviso importante](#aviso-importante)). Uma máquina virtual permite descartar o ambiente e repetir a instalação com facilidade.
- **Acesso:** usuário com permissão de administrador (`sudo`).
- **Navegador:** versões atuais do Google Chrome, Mozilla Firefox ou Microsoft Edge.
- **Internet:** não é necessária no Ubuntu 22.04. Todos os componentes estão na pasta `dependencias/`. Em outras versões do sistema, o PostgreSQL e o OpenLDAP são baixados dos repositórios oficiais.

## Conteúdo do pacote

Cada sistema operacional tem o **seu próprio arquivo de instalação**, só com o que é necessário para ele. Os arquivos ficam na página **[Versões (Releases)](https://github.com/jean2020p/aghuse/releases/latest)**.

**Windows:** um único instalador, `aghuse_setup_13.250-STABLE[_variante-...]_Windows.exe` (~960 MB), com tudo incluído. Depois de instalado, fica em `C:\AGHUse`:

```
C:\AGHUse\
├── jdk-17.0.2\  wildfly-26.1.3.Final\  pgsql\  pgdata\     Java, servidor de aplicação e PostgreSQL
└── ferramentas\
    ├── usuario.bat / verificar.bat / desinstalar.bat      contas de acesso, verificação e remoção
    ├── aghuse.conf                                        parâmetros usados na instalação
    ├── CADASTRO_DE_USUARIOS.md                            passo a passo para cadastrar usuários
    └── README.md, LICENSE
```

**Linux:** um arquivo compactado, `aghuse-13.250-STABLE[_variante-...]-linux.tar.gz` (~1 GB), que se descompacta na pasta `aghuse/`:

```
aghuse/
├── instalar-assistente.sh   instalador com telas (recomendado)
├── instalar.sh              instalador sem telas (lê o aghuse.conf)
├── aghuse.conf              parâmetros da instalação
├── usuario.sh               contas de acesso (login e senha)
├── verificar.sh             verificação da instalação
├── lib/                     rotinas de configuração e de verificação
├── pacote/                  aplicação (aghu.ear), base inicial e configuração do WildFly
├── dependencias/            OpenJDK 17, WildFly 26.1.3 e pacotes do Ubuntu 22.04 (instalação sem internet)
├── docs/CADASTRO_DE_USUARIOS.md
└── README.md, LICENSE
```

Os arquivos grandes estão divididos em partes de até 95 MB (`*.parte-001`, `*.parte-002` ...). O instalador junta as partes e confere os hashes SHA-256 de todos os arquivos antes de instalar.

Nos pacotes da **variante** também vão o arquivo `VARIANTE`, que identifica a versão modificada, e o resumo do que mudou (`modificacoes/integracao-ldap/README.md`).

**Repositório (para quem desenvolve):** além do conteúdo acima, o repositório guarda o código dos instaladores do Windows (`windows/`), a geração dos pacotes (`distribuicao/`), o código-fonte, o *patch* e os testes das modificações (`modificacoes/`) e as notas técnicas (`docs/INSTALADORES.md`). Nada disso é necessário para instalar.

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

### 1. Escolha a versão

Há **dois pacotes** para cada sistema. O instalador, o banco e a configuração são iguais nos dois; muda só a aplicação.

| | **Variante "integração LDAP"** (recomendada, não oficial) | **Original** |
|---|---|---|
| Aplicação | AGHUse 13.250-STABLE **com um ajuste nosso**: a troca de senha | AGHUse 13.250-STABLE **exatamente** como compilado do código oficial |
| Trocar a própria senha pela tela **Senha** do AGHUse | ✅ nos três modos de login: LDAP local (Linux), banco de dados (Windows) e AD/LDAP da instituição | ❌ dá erro (não implementado no original) |
| Identificação | "Variante não oficial: integração LDAP" no rodapé interno, após o login (a tela de login pública não muda) | — |
| Quando escolher | uso e avaliação no dia a dia | comparar com a versão da comunidade ou reproduzir um defeito para relatar a ela |

A variante é uma **modificação independente**, sem vínculo com a Comunidade AGHUse. Tudo o que mudou está documentado em [modificacoes/integracao-ldap/](modificacoes/integracao-ldap/README.md):
- objetivo, funcionamento e limitações;
- os arquivos **originais** e **modificados**, lado a lado, e o *patch*;
- os testes automatizados (38 novos, mais a regressão dos 40 já existentes no módulo);
- como voltar ao original.

Para trocar de uma versão para a outra numa instalação existente, basta rodar o instalador da outra versão: o banco e a configuração são preservados.

### 2. Instalação no Windows

**Requisitos:**
- Windows 10/11 (1809 ou superior) ou Windows Server 2019/2022/2025, 64 bits;
- **12 GB de RAM** (16 GB recomendado);
- 20 GB livres (100 GB recomendado);
- usuário administrador;
- computador **dedicado** (físico ou virtual).

**Passos:**
1. Baixe o instalador na página de [Versões](https://github.com/jean2020p/aghuse/releases/latest):
   - variante: `aghuse_setup_13.250-STABLE_variante-integracao-ldap-1_Windows.exe`;
   - ou original: `aghuse_setup_13.250-STABLE_Windows.exe`.
2. **Dê dois cliques no arquivo** e confirme a permissão de administrador.
3. Siga o assistente. **Não há nada a preencher**: o ambiente de teste vem pré-configurado.

   | Tela | O que fazer |
   |---|---|
   | Aviso | ler e aceitar as condições de uso |
   | Autenticação | **LDAP local** (recomendado, já marcado) ou banco de dados (avaliação rápida); nada a preencher |
   | Verificação dos requisitos | conferir; o assistente não deixa continuar abaixo do mínimo |
   | Outros sistemas neste computador | aparece só se houver outros sistemas (bancos de dados, servidores web, e-SUS...); para continuar, marque "Li, estou ciente... e assumo o risco" |
   | Pronto para instalar | mostra a configuração pré-definida; clique em **Instalar** |

   Configuração pré-definida: pasta `C:\AGHUse`, login por **LDAP local** (AD LDS, componente gratuito do próprio Windows), administrador `AGHU` com senha gerada, porta 8080 liberada no firewall (redes privadas e de domínio).

4. Aguarde de 15 a 45 minutos. A barra de progresso mostra cada etapa.
5. A tela final mostra o endereço, o usuário **e a senha** do administrador, e abre o **arquivo de credenciais**.
6. Acesse pelo ícone **AGHUse** na Área de Trabalho, que abre `http://localhost:8080/aghu`. De outros computadores da rede, use `http://<ip-do-computador>:8080/aghu`.

**Depois de instalado:**

| Item | Windows |
|---|---|
| Serviços | `aghuse` (WildFly, conta *LocalService*), `aghuse-postgresql` (PostgreSQL privativo, só conexões locais) e `ADAM_aghuseldap` (LDAP local, porta 50389, só este computador) |
| Credenciais | `C:\ProgramData\AGHUse\aghuse-credenciais-aghuse.txt` (somente Administradores); menu Iniciar → AGHUse → *Credenciais da instalação* |
| Cadastrar usuários | menu Iniciar → AGHUse → *Como cadastrar usuários* ([passo a passo](docs/CADASTRO_DE_USUARIOS.md)) |
| Contas de acesso | `C:\AGHUse\ferramentas\usuario.bat criar LOGIN "NOME" email` (Prompt de Comando como Administrador) |
| Verificação | menu Iniciar → AGHUse → *Verificar a instalação* |
| Logs | instalação: `C:\ProgramData\AGHUse\logs\`; aplicação: `C:\AGHUse\wildfly-26.1.3.Final\standalone\log\server.log` |
| Remoção | Painel de Controle → Programas → AGHUse. Pergunta "Deseja APAGAR também todos os dados e configurações?": **Sim** apaga tudo (banco, contas do LDAP local, senhas, credenciais e logs); **Não** (padrão) remove só o programa e mantém os dados para reinstalar |

**Diferenças em relação ao Linux:**
- O LDAP local usa o **AD LDS** do próprio Windows, no lugar do OpenLDAP. As contas ficam em `CN=<login>,OU=people,DC=aghuse,DC=local` e são administradas pelo `usuario.bat`.
- O mínimo de memória é maior: o Windows ocupa ~2,4 GB, contra ~0,5 GB de um Linux sem interface gráfica. Na medição de teste, o total foi de ~9,6 GB: WildFly ~6,5 GB, PostgreSQL ~0,2 GB e Windows ~2,4 GB.

**Instalação silenciosa (sem telas, para automação):**

Abra o **Prompt de Comando como Administrador**, vá até a pasta onde o instalador foi baixado e execute **um** dos comandos abaixo. O `start /wait` faz o Prompt esperar o fim da instalação (de 15 a 45 minutos).

Variante:

```bat
cd /d %USERPROFILE%\Downloads
start /wait aghuse_setup_13.250-STABLE_variante-integracao-ldap-1_Windows.exe /VERYSILENT /SUPPRESSMSGBOXES /LOG="C:\aghuse-setup.log"
```

Original:

```bat
cd /d %USERPROFILE%\Downloads
start /wait aghuse_setup_13.250-STABLE_Windows.exe /VERYSILENT /SUPPRESSMSGBOXES /LOG="C:\aghuse-setup.log"
```

Depois, confira o resultado:

```bat
echo Codigo de saida: %ERRORLEVEL%
type C:\ProgramData\AGHUse\aghuse-credenciais-aghuse.txt
```

O código `0` indica sucesso. O arquivo de credenciais traz o endereço, o usuário e a senha. Em caso de erro, veja `C:\aghuse-setup.log` (as linhas do instalador começam com `motor:`).

Opções que podem ser acrescentadas ao comando (todas opcionais):

| Opção | Efeito |
|---|---|
| `/ACEITO_RISCO=sim` | instala mesmo se o computador tiver outros sistemas (bancos de dados, servidores web, e-SUS). Sem ela, nesse caso, a instalação é recusada |
| `/PORTA=8180` | porta de acesso, de 8080 a 8999 (padrão: 8080) |
| `/MODO=banco` | login pelo banco de dados em vez do LDAP local (padrão: `ldap-local`) |
| `/RECRIAR=sim` | reinstalação: **apaga** o banco e restaura a base inicial (padrão: mantém os dados) |
| `/FIREWALL=nao` | não libera a porta no Firewall do Windows (padrão: libera) |
| `/MEMORIA=6G` | memória do WildFly (padrão: 5G) |

Exemplo completo, com porta 8180 e aceite de risco:

```bat
start /wait aghuse_setup_13.250-STABLE_variante-integracao-ldap-1_Windows.exe /VERYSILENT /SUPPRESSMSGBOXES /LOG="C:\aghuse-setup.log" /ACEITO_RISCO=sim /PORTA=8180
```

**Outra configuração (produção, AD da instituição, outra porta):** baixe o projeto, ajuste o `windows\aghuse.conf` (recomendado) e execute `instalar.bat` como Administrador.

### 3. Instalação no Linux

**Requisitos:**
- Ubuntu Server 22.04 LTS (instalação completa sem internet); Ubuntu 24.04 e Debian 12 também são aceitos, mas o PostgreSQL e o OpenLDAP são baixados da internet;
- 64 bits, **8 GB de RAM** (16 GB recomendado), 20 GB livres (100 GB recomendado);
- usuário com `sudo`;
- servidor **dedicado** (físico ou virtual).

**Passos** (no terminal do servidor, inclusive por SSH):

**1. Baixe o arquivo da sua versão**

```bash
# variante (recomendada)
wget https://github.com/jean2020p/aghuse/releases/latest/download/aghuse-13.250-STABLE_variante-integracao-ldap-1-linux.tar.gz
# ou original
wget https://github.com/jean2020p/aghuse/releases/latest/download/aghuse-13.250-STABLE-linux.tar.gz
```

Sem internet no servidor: baixe o arquivo em outro computador e copie-o (por exemplo, com `scp` ou um pendrive).

**2. (Recomendado) Confira a integridade**

```bash
wget https://github.com/jean2020p/aghuse/releases/latest/download/SHA256SUMS
sha256sum --ignore-missing -c SHA256SUMS
```

O resultado deve ser `OK` para o arquivo baixado.

**3. Descompacte e entre na pasta**

```bash
tar xzf aghuse-13.250-STABLE*-linux.tar.gz
cd aghuse
```

**4. Execute o instalador com telas**

```bash
sudo ./instalar-assistente.sh
```

Não há nada a preencher: o ambiente de teste vem **pré-configurado** (LDAP local, administrador `AGHU` com senha gerada, porta 8080). O assistente funciona no próprio terminal e segue as mesmas etapas do Windows:
1. aviso e aceite (nas telas de texto, use as setas para rolar e **TAB + Enter** para continuar);
2. verificação dos requisitos;
3. autenticação: **LDAP local** (recomendado, já marcado) ou banco de dados;
4. outros sistemas na máquina, com aceite de risco (marque com a **barra de espaço**);
5. em reinstalação: manter os dados ou apagar o banco;
6. resumo da configuração pré-definida e **Instalar**;
7. barra de progresso;
8. tela final com o endereço, o usuário e a senha do administrador, e a opção de ver as credenciais.

A instalação leva de 20 a 60 minutos; a etapa mais demorada é a restauração da base inicial. Para **produção ou outra configuração** (LDAP/AD da instituição, outra porta, proxy reverso), ajuste o `aghuse.conf` (recomendado) e use o `instalar.sh` abaixo.

**Alternativa sem telas (automação):** edite o `aghuse.conf` (parâmetros na seção [Parâmetros](#parâmetros-aghuseconf)) e execute:

```bash
sudo ./instalar.sh
```

Se a máquina tiver outros sistemas, o instalador **para** e pede o aceite: digite `ACEITO` no terminal ou use `ACEITO_RISCO="sim"` no `aghuse.conf`. O aceite fica registrado em `/etc/aghuse/aceite-risco-<SERVICO>.txt`. Em servidores de produção que já rodam outro sistema, por exemplo o e-SUS, **não instale**.

**5. Acesse o sistema**

```
http://<ip-do-servidor>:8080/aghu
```

- **Usuário:** `AGHU`
- **Senha:** gerada na instalação. Para consultar: `sudo cat /root/aghuse-credenciais-aghuse.txt`
- **Cadastrar usuários:** `sudo ./usuario.sh criar LOGIN "NOME" email`, depois o cadastro dentro do AGHUse ([passo a passo](docs/CADASTRO_DE_USUARIOS.md)).
- **Verificar a instalação:** `sudo ./verificar.sh`

> **Para quem desenvolve:** também é possível clonar o repositório (`git clone https://github.com/jean2020p/aghuse.git`) e instalar a partir dele com os mesmos comandos. Isso instala a versão **original**: a variante só existe nos pacotes da página de Versões, porque a aplicação modificada não fica no repositório.

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
| `ACEITO_RISCO` | `nao` | `sim` para instalar sem terminal em uma máquina com outros sistemas (ver [Instalação](#instalação)). |
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
- **Senhas informadas manualmente:** só letras e números. Senha do administrador (`ADMIN_SENHA`): no mínimo 8 caracteres; senhas internas (banco, conta de serviço): no mínimo 16 (20 em produção). Em branco, são geradas: 12 caracteres para o administrador, 32 para as internas. O mínimo de 8 do administrador é uma regra **deste instalador** para o ambiente de **teste** (o AGHUse em si não define tamanho de senha); em produção, use senhas de 12 caracteres ou mais e a política de senhas do AD/LDAP da instituição.
- **Senhas dos usuários do banco:** gravadas no formato `scram-sha-256`.
- **Acesso ao PostgreSQL:** somente pela própria máquina.

## Autenticação e usuários

> **Passo a passo para cadastrar um usuário** (conta de acesso no LDAP ou no banco + cadastro dentro do AGHUse), para cada modo de login: **[docs/CADASTRO_DE_USUARIOS.md](docs/CADASTRO_DE_USUARIOS.md)**.

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
| `ldap-local` (padrão) | Diretório no próprio computador, acessível só por ele: OpenLDAP no Linux, AD LDS no Windows | Testes e avaliação. Contas criadas com `usuario.sh` / `usuario.bat`. |
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

## Após a instalação (Linux)

No Windows, as mesmas tarefas estão no menu Iniciar → AGHUse e na tabela de [Instalação no Windows](#2-instalação-no-windows).

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
- **Página em branco depois do login** (defeito do AGHUse, presente no original e na variante). No primeiro login de cada usuário, o AGHUse grava os ícones da tela inicial na tabela `casca.csc_dashboard`. Se o mesmo usuário entrar duas vezes ao mesmo tempo nesse primeiro acesso (por exemplo, em dois navegadores), os ícones são gravados em dobro. A restrição única da tabela não impede, porque as colunas `modal` e `id_favorito` ficam vazias (`NULL`). A partir daí, todo login desse usuário mostra a página em branco, e o `server.log` registra `A ID de componente panel_NNNNN já foi encontrada na visualização`. O instalador remove as duplicatas e cria um índice que impede a repetição. Numa instalação feita por outro meio, a correção é:

  ```sql
  DELETE FROM casca.csc_dashboard d USING casca.csc_dashboard o
   WHERE d.id_usuario = o.id_usuario AND d.id_favorito IS NOT DISTINCT FROM o.id_favorito
     AND d.modal IS NOT DISTINCT FROM o.modal AND d.id > o.id;
  CREATE UNIQUE INDEX IF NOT EXISTS csc_dsh_uk_instalador
    ON casca.csc_dashboard (id_usuario, coalesce(modal, ''), coalesce(id_favorito, -1));
  ```

  Depois, basta recarregar a página: não é preciso reiniciar o serviço.
- **Vínculo do administrador `AGHU`.** Na base inicial, o `AGHU` está ligado ao servidor de matrícula **9999999** (vínculo 955), pelo campo `usuario` de `agh.rap_servidores`. Se alguém usar **Criar Login** nesse servidor (tela *Usuário*), o vínculo passa para o login novo e o `AGHU` fica sem servidor. A sessão aberta continua funcionando, mas os próximos logins e a troca de senha falham ("senha atual não confere"), e o `server.log` registra `Nenhum Servidor do HU encontrado associado ao usuário AGHU`. O instalador devolve o vínculo ao `AGHU` e cria um *trigger* que recusa essa operação. Numa instalação feita por outro meio:

  ```sql
  UPDATE agh.rap_servidores SET usuario = 'AGHU'
   WHERE matricula = 9999999 AND vin_codigo = 955
     AND NOT EXISTS (SELECT 1 FROM agh.rap_servidores s WHERE upper(s.usuario) = 'AGHU');
  ```

  O login que tinha tomado o vínculo fica sem servidor: inative-o na tela *Usuário* ou ligue-o a um servidor próprio.

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

O AGHUse é **software público**: feito por uma instituição pública com recursos públicos e distribuído como **software livre** (GPL v2 ou posterior). Isso garante a qualquer pessoa ou instituição as quatro liberdades da licença:

| Liberdade | O que significa na prática |
|---|---|
| **Usar** | instalar e usar o sistema para qualquer finalidade, sem pagar licença |
| **Estudar** | ter acesso ao código-fonte e entender como o sistema funciona |
| **Modificar** | adaptar o sistema às suas necessidades, como fizemos na [variante integração LDAP](modificacoes/integracao-ldap/README.md) |
| **Redistribuir** | compartilhar cópias, originais ou modificadas, mantendo a mesma licença e o código-fonte aberto |

Quem redistribui uma versão modificada deve publicar o código-fonte das mudanças e manter a mesma licença. Por isso as modificações deste instalador estão documentadas e disponíveis em `modificacoes/`.

- **AGHUse:** © Hospital de Clínicas de Porto Alegre, distribuído sob a Licença Pública Geral GNU (GPL), versão 2 ou posterior. Contato da comunidade: centralAGHUse@hcpa.edu.br. Página oficial: [https://sites.google.com/hcpa.edu.br/aghuse/sobre-o-aghuse](https://sites.google.com/hcpa.edu.br/aghuse/sobre-o-aghuse).
- **OpenJDK:** GPL v2 com Classpath Exception.
- **WildFly:** Apache License 2.0 / LGPL.
- **PostgreSQL:** PostgreSQL License.
- **OpenLDAP:** OpenLDAP Public License.

Os scripts deste instalador são distribuídos sem garantia, nos mesmos termos da GPL v2 ou posterior.
