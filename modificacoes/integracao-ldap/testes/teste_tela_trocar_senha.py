# Teste da integracao-ldap: troca de senha pela tela "Trocar Senha" do AGHUse.
# Executar na VM Linux como root:  python3 teste_trocar_senha.py
# Usa a senha do AGHU do arquivo de credenciais (P0), troca para P1, confere no LDAP,
# faz login com P1 e volta para P0 pela mesma tela.
import subprocess, sys
from playwright.sync_api import sync_playwright

BASE = "http://127.0.0.1:8080/aghu"
P0 = open("/root/aghuse-credenciais-aghuse.txt").read().split("Senha do administrador ...: ")[1].split()[0]
P1 = "SenhaNovaTesteLdap2026xyz"   # 25 caracteres: tambem testa o limite (antes 20)
UDN = "uid=AGHU,ou=people,dc=aghuse,dc=local"
falhas = []

def ldap_ok(senha):
    return subprocess.run(["ldapwhoami", "-x", "-H", "ldap://127.0.0.1", "-D", UDN, "-w", senha],
                          capture_output=True).returncode == 0

def msgs(page):
    out = []
    for m in page.query_selector_all(".ui-messages-error-summary, .ui-messages-warn-summary, .ui-messages-info-summary, .ui-growl-title, .ui-growl-message p, .ui-message-error-detail"):
        t = m.inner_text().strip()
        if t and t not in out: out.append(t)
    return out

def idle(page, ms=2500):
    try: page.wait_for_load_state("load", timeout=60000)
    except Exception: pass
    page.wait_for_timeout(ms)

def login(page, senha):
    page.goto(BASE + "/pages/casca/casca.xhtml", timeout=180000)
    for _ in range(4):
        if page.is_visible("#loginBtn"):
            page.fill("input[name='username:username:inputId']", "AGHU")
            page.fill("input[name='password:inputId']", senha)
            page.click("#loginBtn")
        idle(page, 5000)
        if page.is_visible("#bt_matar_outro"):   # acesso simultaneo: encerra a sessao anterior
            page.click("#bt_matar_outro"); idle(page, 5000)
        if page.is_visible("[id='pesquisaMenus_input']"):
            return True
    return False

def abrir_tela_senha(page):
    """Abre a tela pelo menu do AGHUse (Pesquisar no Menu > "Senha"), como um usuario faria."""
    page.click("[id='pesquisaMenus_input']"); page.keyboard.type("Senha", delay=80); page.wait_for_timeout(4000)
    print("   menu:", page.evaluate("""(()=>{const li=Array.from(document.querySelectorAll('.ui-autocomplete-item'))
        .find(e=>e.innerText.includes('Acesso -> Senha'));
        if(!li) return 'item Senha nao encontrado: '+Array.from(document.querySelectorAll('.ui-autocomplete-item')).map(e=>e.innerText.trim()).join(' | ');
        li.click(); return 'abrindo '+li.innerText.trim()})()"""))
    for _ in range(30):
        fr = [f for f in page.frames if "trocarSenha" in f.url]
        if fr and fr[-1].query_selector("[id='novaSenhaField:novaSenha']"): return fr[-1]
        page.wait_for_timeout(1000)
    raise RuntimeError("tela Trocar Senha nao abriu pelo menu")

def trocar(page, atual, nova, confirma=None):
    fr = abrir_tela_senha(page)
    fr.fill("[id='senhaAtualField:senhaAtual']", atual)
    fr.fill("[id='novaSenhaField:novaSenha']", nova)
    fr.fill("[id='confirmarSenhaField:confirmarSenha']", confirma if confirma is not None else nova)
    fr.click("button:has-text('Gravar'), a:has-text('Gravar'), [id$='botaoSalvar']"); page.wait_for_timeout(5000)
    return msgs(fr) + msgs(page)

def checa(nome, cond, extra=""):
    print(("  [OK]    " if cond else "  [FALHA] ") + nome + (("  -> " + extra) if extra else ""))
    if not cond: falhas.append(nome)

print("senha inicial no LDAP confere:", ldap_ok(P0))
with sync_playwright() as p:
    b = p.chromium.launch()
    page = b.new_page(viewport={"width": 1400, "height": 1000}, locale="pt-BR")
    page.set_default_timeout(20000)
    checa("login com a senha original", login(page, P0))
    fr = abrir_tela_senha(page)
    checa("tela Trocar Senha abre pelo menu", fr is not None, fr.url)
    checa("campo nova senha aceita 64 caracteres", fr.get_attribute("[id='novaSenhaField:novaSenha']", "maxlength") == "64",
          "maxlength=" + str(fr.get_attribute("[id='novaSenhaField:novaSenha']", "maxlength")))

    m = trocar(page, "senhaErradaQualquer123", P1)
    checa("senha atual errada e recusada", ldap_ok(P0) and not ldap_ok(P1), " | ".join(m))

    m = trocar(page, P0, "curta1")
    checa("nova senha curta e recusada", ldap_ok(P0), " | ".join(m))

    m = trocar(page, P0, P1)
    checa("troca P0 -> P1 informa sucesso", any("sucesso" in x.lower() for x in m), " | ".join(m))
    checa("LDAP aceita a senha nova", ldap_ok(P1))
    checa("LDAP recusa a senha antiga", not ldap_ok(P0))
    b.close()

    b = p.chromium.launch()
    page = b.new_page(viewport={"width": 1400, "height": 1000}, locale="pt-BR")
    page.set_default_timeout(20000)
    checa("login no AGHUse com a senha nova", login(page, P1))
    m = trocar(page, P1, P0)
    checa("troca de volta P1 -> P0 informa sucesso", any("sucesso" in x.lower() for x in m), " | ".join(m))
    b.close()

checa("ao final, a senha original voltou a valer", ldap_ok(P0) and not ldap_ok(P1))
print("RESULTADO:", "TODOS OS TESTES OK" if not falhas else "FALHAS: " + ", ".join(falhas))
sys.exit(1 if falhas else 0)
