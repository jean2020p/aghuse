# Como cadastrar um usuário no AGHUse (passo a passo)

Este guia mostra **o que fazer e onde fazer** para que uma pessoa (um médico, um enfermeiro, um administrativo...) consiga entrar no AGHUse instalado por este instalador.

## A regra principal: o usuário existe em DOIS lugares

```
 1. CONTA DE ACESSO  (login + senha)            2. CADASTRO NA APLICAÇÃO (AGHUse)
    fica no LDAP/AD ou no PostgreSQL               usuário + perfil + pessoa + servidor
    ─ criada no TERMINAL (ou pela TI no AD)        ─ feito nas TELAS do AGHUse
                     └──────────── MESMO LOGIN nos dois lugares ────────────┘
```

- O AGHUse **não guarda senhas**: no login, ele confere a senha no diretório (LDAP/AD) ou no PostgreSQL (modo `banco`).
- Depois de conferir a senha, ele verifica se o login está **cadastrado na aplicação**, com **perfil** e **vínculo de servidor**.
- **Faltando qualquer um dos dois lados, o login é recusado.** A mensagem de erro indica o que falta (ver a [tabela no final](#se-o-login-for-recusado)).

---

## Passo 0: descubra o modo de login da sua instalação

| Onde olhar | Linux | Windows |
|---|---|---|
| Arquivo de credenciais (linha `Login:`) | `sudo cat /root/aghuse-credenciais-aghuse.txt` | menu Iniciar → AGHUse → *Credenciais da instalação* |
| Arquivo de parâmetros (`MODO_LOGIN=`) | `aghuse.conf` na pasta do instalador | `C:\AGHUse\ferramentas\aghuse.conf` |

| Modo | Onde fica a senha | Padrão em | Siga o caminho |
|---|---|---|---|
| `ldap-local` | diretório LDAP no próprio computador (OpenLDAP no Linux, AD LDS no Windows) | **Linux e Windows** | [A](#caminho-a-ldap-local-linux-e-windows-padrão) |
| `banco` | PostgreSQL (sem diretório) | avançado (só avaliação) | [B](#caminho-b-banco-avançado) |
| `ldap-externo` | LDAP / Active Directory da instituição | produção | [C](#caminho-c-ldap--active-directory-da-instituição) |

Os passos dentro do AGHUse são feitos com um usuário que tenha perfil de administração. Na base inicial, é o **`AGHU`**, com o perfil `SUPER`.

---

## Caminho A: LDAP local (Linux e Windows, padrão)

### A1. Criar a conta de acesso no LDAP (terminal do servidor)

**Linux**, na pasta do instalador:

```bash
sudo ./usuario.sh criar MSILVA "MARIA SILVA" maria.silva@hospital.org.br
```

**Windows**, num **Prompt de Comando aberto como Administrador**:

```bat
C:\AGHUse\ferramentas\usuario.bat criar MSILVA "MARIA SILVA" maria.silva@hospital.org.br
```

- **Login:** letras, números, ponto, hífen ou sublinhado (ex.: `MSILVA`).
- **Nome completo e e-mail:** vão para o LDAP e são **trazidos automaticamente** para o AGHUse no passo A2. O e-mail precisa ter um domínio válido (ex.: `@hospital.org.br`).
- **Senha:** o comando pede a senha (mínimo de 8 caracteres). Se você deixar em branco, ele gera uma senha forte e a mostra **uma única vez**. Anote e entregue ao usuário por um meio seguro.

### A2. Trazer o usuário para o AGHUse (Importar Usuário)

1. Entre no AGHUse como `AGHU`.
2. Abra *Outros Módulos → Configuração → Acesso → Usuário* (ou digite "Usuário" em **Pesquisar no Menu**).
3. Clique em **Pesquisar**. Os botões **Novo** e **Importar Usuário** só aparecem depois da pesquisa.
4. Clique em **Importar Usuário**, digite o login (`MSILVA`) e clique em **Pesquisar**. A conta criada no passo A1 aparece na lista.
5. Clique em **Adicionar**, confira **Nome** e **E-mail** (vindos do LDAP) e clique em **Gravar**.

### A3. Dar um perfil ao usuário

1. Na lista de usuários, use a ação **Editar Perfil** do `MSILVA`.
2. Escolha um perfil, clique em **Adicionar** e em **Gravar**.
   - A base inicial tem 631 perfis ativos. Exemplos: **`MED01`** para médicos (profissionais de medicina com registro no CRM), `ADM01` para administrativos.

### A4. Cadastrar a pessoa

1. Abra *Reg. Colaboradores → Administração de Pessoal → Administrar Servidores → Pessoas*.
2. Clique em **Pesquisar** e depois em **Novo**.
3. Preencha os campos obrigatórios:
   - nome, **igual ao do usuário**;
   - nome da mãe, sexo, data de nascimento e nacionalidade;
   - número de identidade e **CPF válido**.
4. Grave.

### A5. Cadastrar o servidor (vínculo)

1. Abra *Reg. Colaboradores → Administração de Pessoal → Administrar Servidores → Servidores*.
2. Clique em **Pesquisar** e depois em **Novo**.
3. Informe:
   - a **pessoa** (do passo A4);
   - o **login** (`MSILVA`);
   - o **vínculo** e a matrícula;
   - o **início do vínculo**.
   - Na base inicial, o vínculo `955` (VINCULO INTEGRACAO) não exige lotação, horário e ocupação.
4. Grave.

### A6. Testar

Saia e entre com `MSILVA` e a senha do passo A1. Pronto.

> **Na versão com troca de senha** (variante "integração LDAP"), o próprio usuário pode trocar a senha recebida em *Outros Módulos → Configuração → Acesso → **Senha***. Na versão original, a troca é feita pelo administrador: `sudo ./usuario.sh senha MSILVA` (Linux) ou `usuario.bat senha MSILVA` (Windows).

---

## Caminho B: banco (avançado)

No modo `banco` não há diretório para importar. Por isso a ordem muda: primeiro a **pessoa** e o **servidor**, depois o **usuário** pela ação **Criar Login**, e por fim a **senha** no terminal.

### B1. Cadastrar a pessoa
Igual ao [passo A4](#a4-cadastrar-a-pessoa).

### B2. Cadastrar o servidor, **sem** login
Igual ao [passo A5](#a5-cadastrar-o-servidor-vínculo), mas **deixe o login em branco**. Anote a **matrícula**.

> **Atenção:** use sempre um servidor **novo**, cadastrado no passo B2. **Não** use **Criar Login** no servidor de matrícula **9999999** (vínculo 955): ele é o vínculo do administrador `AGHU`. Se outro login for criado nele, o `AGHU` perde o vínculo e deixa de conseguir entrar e trocar a senha. As instalações feitas por este instalador recusam essa operação e mostram: *"O servidor 9999999 (vinculo 955) pertence ao administrador AGHU..."*.

### B3. Criar o usuário a partir do servidor
1. Abra *Outros Módulos → Configuração → Acesso → Usuário* e pesquise pela **matrícula**.
2. O servidor aparece com a ação **Criar Login**. Ela abre o cadastro com matrícula, nome e vínculo preenchidos e sugere um login a partir do nome. Anote o login.
3. Informe o **e-mail** (domínio válido) e clique em **Gravar**.
4. Na lista, use **Editar Perfil** e dê um perfil (ex.: `MED01`), como no [passo A3](#a3-dar-um-perfil-ao-usuário).

### B4. Criar a senha do usuário (terminal), **obrigatório**

A aplicação **não** cria a senha no PostgreSQL. Sem este passo, o login falha com *"Erro ao conectar no banco com o usuario"*.

**Windows:** abra o **Prompt de Comando como Administrador** e rode:

```bat
C:\AGHUse\ferramentas\usuario.bat criar MSILVA
```

**Linux, se instalado no modo banco:**

```bash
sudo ./usuario.sh criar MSILVA
```

Use **exatamente o mesmo login** do passo B3. A senha é pedida no terminal; em branco, é gerada e mostrada uma única vez.

### B5. Testar
Entre com o login e a senha. Na versão com troca de senha, o usuário pode trocá-la no menu **Senha**.

---

## Caminho C: LDAP / Active Directory da instituição

1. **A TI cria a conta no AD/LDAP da instituição**, com login, nome (`displayName`) e e-mail (`mail`). Este instalador não cria contas no AD.
2. No AGHUse, siga os passos [A2](#a2-trazer-o-usuário-para-o-aghuse-importar-usuário) (Importar Usuário), [A3](#a3-dar-um-perfil-ao-usuário) (perfil), [A4](#a4-cadastrar-a-pessoa) (pessoa) e [A5](#a5-cadastrar-o-servidor-vínculo) (servidor).
3. A senha é a do AD. Ela é trocada pelos meios da instituição ou, na versão com troca de senha, pelo menu **Senha** (no Active Directory isso exige conexão segura, LDAPS).

---

## Manutenção das contas (terminal)

| Ação | Linux (`ldap-local` ou `banco`) | Windows (`ldap-local` ou `banco`) |
|---|---|---|
| Criar conta | `sudo ./usuario.sh criar LOGIN ["NOME"] [email]` | `usuario.bat criar LOGIN ["NOME"] [email]` |
| Redefinir senha (esqueceu) | `sudo ./usuario.sh senha LOGIN` | `usuario.bat senha LOGIN` |
| Remover conta | `sudo ./usuario.sh remover LOGIN` | `usuario.bat remover LOGIN` |
| Listar contas | `sudo ./usuario.sh listar` | `usuario.bat listar` |

- No Windows, o `usuario.bat` fica em `C:\AGHUse\ferramentas\` e deve ser executado num **Prompt de Comando aberto como Administrador**.
- Ao **remover** a conta, **inative também o usuário no AGHUse**, na tela Usuário.
- No `ldap-externo`, essas ações são feitas no AD pela TI.

---

## Se o login for recusado

| Mensagem | O que falta | Passo |
|---|---|---|
| "Erro de autenticação. Verifique o nome de usuário e senha" | conta de acesso inexistente ou senha errada | A1 / B4 / C1 |
| "Erro ao conectar no banco com o usuario..." (modo banco) | a senha não foi criada no PostgreSQL | B4 |
| "Este usuário não foi encontrado no sistema" | o login não foi cadastrado na aplicação | A2 / B3 |
| "Usuário não tem perfil associado ou todos seus perfis estão inativos" | falta perfil | A3 |
| "Nenhum Servidor do HU encontrado associado ao usuário" | falta o servidor (vínculo) com esse login | A5 / B2 |
| `AGHU`: "senha atual não confere" na tela Senha, ou login recusado; no `server.log`: "Nenhum Servidor do HU encontrado associado ao usuário AGHU" | o servidor do `AGHU` (matrícula 9999999) recebeu outro login pelo **Criar Login** | Reinstalar (o instalador devolve o vínculo) ou rodar o SQL em README, [Pontos de atenção → Banco de dados](../README.md#pontos-de-atenção) |
| Login aceito, mas a **página fica em branco** | ícones da tela inicial gravados em dobro (o mesmo usuário entrou duas vezes ao mesmo tempo no primeiro acesso); defeito do AGHUse | README, [Pontos de atenção → Banco de dados](../README.md#pontos-de-atenção). Instalações feitas por este instalador já vêm protegidas |

O motivo exato também aparece no log da aplicação (`server.log`):

| Sistema | Caminho do `server.log` |
|---|---|
| Linux | `/opt/aghuse/wildfly/standalone/log/server.log` |
| Windows | `C:\AGHUse\wildfly-26.1.3.Final\standalone\log\server.log` |

## Observações

- **Médicos:** o perfil `MED01` dá o acesso de médico. Para atuar clinicamente (prescrever, atender no ambulatório), normalmente também são necessários o registro no conselho (**CRM**, nas qualificações da pessoa/servidor), a ocupação de médico e as especialidades do profissional. Este guia cobre o acesso ao sistema; o cadastro clínico completo segue as regras da instituição.
- **Sessões simultâneas:** cada usuário pode ter só 1 sessão ativa por padrão (campo *Quantidade Máxima de Logins*). Um novo login oferece encerrar a sessão anterior.
- **Sem sincronização automática:** o AGHUse só lê o diretório na tela **Importar Usuário**. Alterar o nome ou o e-mail no LDAP não atualiza o cadastro já feito.
- **"Reiniciar Senha do Usuário"**, na tela de usuários, funciona apenas no ambiente do HCPA. Use o terminal (tabela acima) ou, na versão com troca de senha, o menu **Senha** pelo próprio usuário.
