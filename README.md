# Instalador AGHUse 13.250-STABLE para Linux

Instalação automatizada do **AGHUse – Aplicativo de Gestão para Hospitais Universitários** em um servidor Linux. Com um comando, o instalador prepara Java, servidor de aplicação, banco de dados, base inicial, autenticação e serviço do sistema.

---

## Aviso importante

> **Este pacote destina-se exclusivamente a TESTE, AVALIAÇÃO e ESTUDO do sistema.**
>
> - É fornecido **"no estado em que se encontra", sem garantia de qualquer natureza e sem suporte técnico**.
> - É uma iniciativa independente. **Não é uma distribuição oficial** do AGHUse e não tem vínculo com a Comunidade AGHUse, o Hospital de Clínicas de Porto Alegre ou a EBSERH.
> - O suporte técnico ao AGHUse é prestado pela Comunidade AGHUse **somente às instituições integrantes da comunidade**. Fora dela, o acesso se limita aos arquivos e às instruções de instalação.
> - Quem instala, configura e opera o sistema assume toda a responsabilidade por seu uso, pela segurança das informações e pelo cumprimento da legislação aplicável, inclusive a LGPD.
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
- **Acesso:** usuário com permissão de administrador (`sudo`).
- **Navegador:** versões atuais do Google Chrome, Mozilla Firefox ou Microsoft Edge.
- **Internet:** não é necessária no Ubuntu 22.04. Todos os componentes estão na pasta `dependencias/`. Em outras versões do sistema, o PostgreSQL e o OpenLDAP são baixados dos repositórios oficiais.

## Conteúdo do pacote

```
aghuse/
├── instalar.sh          instalador
├── aghuse.conf          parâmetros da instalação (edite antes de instalar)
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

Para um ambiente de teste com login pelo banco de dados, os valores padrão já servem.

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

## Parâmetros (`aghuse.conf`)

| Parâmetro | Padrão | Descrição |
|---|---|---|
| `AMBIENTE` | `teste` | `teste` ou `producao`. Em produção, há verificações adicionais. |
| `CONFIRMO_PRODUCAO` | `nao` | Precisa ser `sim` quando `AMBIENTE=producao`. |
| `NOME_AMBIENTE` | `AGHUSE-TESTE` | Nome de identificação do ambiente. |
| `MODO_LOGIN` | `banco` | `banco`, `ldap-local` ou `ldap-externo` (ver abaixo). |
| `ADMIN_LOGIN` / `ADMIN_SENHA` | `AGHU` / gerada | Administrador da base inicial. |
| `PG_VERSAO` | `15` | Versão do PostgreSQL. |
| `PG_PORTA` | automática | Porta do cluster PostgreSQL. |
| `DB_NOME`, `DB_USUARIO`, `DB_SENHA` | `dbaghu`, `ugen_aghu`, gerada | Banco e usuário da aplicação. |
| `RECRIAR_BANCO` | `nao` | `sim` apaga e recria o banco a partir da base inicial. |
| `PREFIXO` | `/opt/aghuse` | Diretório de instalação do Java e do WildFly. |
| `SERVICO` | `aghuse` | Nome do serviço systemd. |
| `USUARIO_SO` | `aghuse` | Usuário do sistema que executa o WildFly. |
| `HTTP_BIND` | `0.0.0.0` | Interface de rede da aplicação (`127.0.0.1` para uso com proxy reverso). |
| `PORT_OFFSET` | `0` | Deslocamento de portas (`100` coloca a aplicação na porta 8180). |
| `MEMORIA_JVM` | automática | Memória do WildFly (5 GB recomendados). |
| `FUSO_HORARIO` | `America/Sao_Paulo` | Fuso horário da aplicação. |
| `SMTP_HOST` | `127.0.0.1` | Servidor de e-mail. |

### Senhas

- **Senhas em branco são geradas automaticamente:** 32 caracteres aleatórios, gravados em `/root/aghuse-credenciais-<SERVICO>.txt`, que só o usuário root lê.
- **Senhas informadas manualmente:** só letras e números, com no mínimo 16 caracteres (20 em produção).
- **Senhas dos usuários do banco:** gravadas no formato `scram-sha-256`.
- **Acesso ao PostgreSQL:** somente pela própria máquina.

### Modos de autenticação

| Modo | Como funciona | Indicado para |
|---|---|---|
| `banco` | A senha é validada pelo PostgreSQL. Cada usuário do AGHUse precisa de um usuário de banco com o mesmo login. | Testes rápidos, sem diretório. |
| `ldap-local` | Instala um OpenLDAP no próprio servidor, acessível só pela própria máquina, e cria nele o usuário administrador. | Testar a autenticação por diretório. **Não é permitido em produção.** |
| `ldap-externo` | Usa um LDAP ou Active Directory já existente na instituição. | Ambientes institucionais. |

Em todos os modos, os **perfis e as permissões** de cada usuário continuam sendo definidos dentro do AGHUse. O login digitado precisa estar cadastrado no sistema.

**Para incluir um usuário no modo `banco`:**

```bash
sudo -u postgres psql -p <PG_PORTA> -c "CREATE ROLE \"LOGIN\" LOGIN PASSWORD 'senha'; GRANT CONNECT ON DATABASE dbaghu TO \"LOGIN\";"
```

**Para incluir um usuário no modo `ldap-local`** (os dados do administrador LDAP estão no arquivo de credenciais):

```bash
HASH=$(slappasswd -s 'senha')
ldapadd -x -H ldap://127.0.0.1 -D "cn=admin,dc=aghuse,dc=local" -W <<EOF
dn: uid=LOGIN,ou=people,dc=aghuse,dc=local
objectClass: inetOrgPerson
uid: LOGIN
cn: Nome Completo
sn: Sobrenome
userPassword: $HASH
EOF
```

**Exemplo de `ldap-externo` com Active Directory:**

```bash
MODO_LOGIN="ldap-externo"
LDAP_HOST="ad.instituicao.local"
LDAP_PORTA="389"
LDAP_USER_DN="%s@instituicao.local"
LDAP_BASE_USUARIOS="DC=instituicao,DC=local"
LDAP_ATRIBUTO_LOGIN="sAMAccountName"
LDAP_FILTRO="(&(objectClass=user)(sAMAccountName=%s))"
```

Antes de instalar, teste o acesso ao diretório a partir do servidor:

```bash
ldapwhoami -x -H ldap://ad.instituicao.local -D "login@instituicao.local" -W
```

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
- Sem servidor LDAP, use o realm `AghuseDbConnectionSecurityRealm`, que valida a senha abrindo uma conexão no PostgreSQL com o login digitado. Ele exige a propriedade `loginDatasource` e um datasource com `<allow-multiple-users/>`.

**Servidor de aplicação**
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

## Uso em produção

O modo `producao` aplica estas verificações:
- exige `CONFIRMO_PRODUCAO="sim"`;
- recusa o LDAP local de teste;
- exige senhas manuais com no mínimo 20 caracteres.

**Ele não substitui a validação técnica da instituição.** Antes de usar o sistema com dados reais, a instituição deve, no mínimo:

1. **HTTPS:** publicar o sistema somente atrás de um proxy reverso com HTTPS (por exemplo, Nginx ou Apache com certificado válido) e configurar `HTTP_BIND="127.0.0.1"`.
2. **Firewall:** liberar apenas as portas necessárias. PostgreSQL (5432) e o console do WildFly (9990) não devem ficar expostos.
3. **Autenticação:** usar o LDAP/Active Directory institucional (`ldap-externo`), de preferência com LDAPS, e uma conta de serviço só de leitura.
4. **Senha do administrador:** trocar a senha do usuário `AGHU` e criar usuários nominais para cada profissional.
5. **Usuários internos do WildFly:** revisar os usuários e as senhas internas do servidor de aplicação (`application-users.properties`, keystores e parâmetros em `app-parameters.properties`) de acordo com a política de segurança da instituição.
6. **Backup:** implantar backup automático e testado do banco (`pg_dump` ou backup físico) e da pasta de configuração do WildFly.
7. **Atualizações:** manter o sistema operacional, o Java e o PostgreSQL com as atualizações de segurança.
8. **Monitoramento:** monitorar o serviço, o espaço em disco, a memória e os logs.
9. **Dimensionamento:** ajustar a memória (`MEMORIA_JVM`) e os recursos do PostgreSQL ao volume de uso.
10. **Validação funcional:** homologar os módulos que serão usados e a integração com os demais sistemas da instituição.
11. **LGPD:** avaliar o tratamento de dados pessoais e sensíveis, os perfis de acesso e os registros de auditoria.

---

## Licenças

- **AGHUse:** © Hospital de Clínicas de Porto Alegre, distribuído sob a Licença Pública Geral GNU (GPL), versão 2 ou posterior. Contato da comunidade: centralAGHUse@hcpa.edu.br.
- **OpenJDK:** GPL v2 com Classpath Exception.
- **WildFly:** Apache License 2.0 / LGPL.
- **PostgreSQL:** PostgreSQL License.
- **OpenLDAP:** OpenLDAP Public License.

Os scripts deste instalador são distribuídos sem garantia, nos mesmos termos da GPL v2 ou posterior.
