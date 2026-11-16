# Teste da variante integracao-ldap no MODO BANCO (senha no PostgreSQL): tela "Trocar Senha".
# Uso: AGHUSE_URL=http://host:8080/aghu AGHUSE_SENHA=<senha atual do AGHU> python teste_trocar_senha_banco.py
# Troca P0 -> P1 pela tela, confere pelo login (P1 entra, P0 e recusada NA HORA, sem esperar o pool)
# e volta para P0 pela mesma tela.
import os, sys
from playwright.sync_api import sync_playwright

BASE = os.environ["AGHUSE_URL"].rstrip("/")
P0 = os.environ["AGHUSE_SENHA"]
P1 = "SenhaNovaTesteBanco2026xyz"
falhas = []

def checa(nome, cond, extra=""):
    print(("  [OK]    " if cond else "  [FALHA] ") + nome + (("  -> " + extra) if extra else ""))
    if not cond: falhas.append(nome)

def msgs(ctx):
    out = []
    for m in ctx.query_selector_all(".ui-messages-error-summary, .ui-messages-warn-summary, .ui-messages-info-summary, .ui-growl-title, .ui-growl-message p"):
        t = m.inner_text().strip()
        if t and t not in out: out.append(t)
    return out

def idle(page, ms=4000):
    try: page.wait_for_load_state("load", timeout=90000)
    except Exception: pass
    page.wait_for_timeout(ms)

def login(page, senha):
    page.goto(BASE + "/pages/casca/casca.xhtml", timeout=180000)
    for _ in range(4):
        if page.is_visible("#loginBtn"):
            page.fill("input[name='username:username:inputId']", "AGHU")
            page.fill("input[name='password:inputId']", senha)
            page.click("#loginBtn")
        idle(page, 6000)
        if page.is_visible("#bt_matar_outro"):
            page.click("#bt_matar_outro"); idle(page, 6000)
        if page.is_visible("[id='pesquisaMenus_input']"):
            return True
        if page.is_visible("#loginBtn") and msgs(page):
            return False
    return False

def abrir_tela_senha(page):
    page.click("[id='pesquisaMenus_input']"); page.keyboard.type("Senha", delay=80); page.wait_for_timeout(5000)
    page.evaluate("""(()=>{const li=Array.from(document.querySelectorAll('.ui-autocomplete-item')).find(e=>e.innerText.includes('Acesso -> Senha')); if(li) li.click();})()""")
    for _ in range(60):
        fr = [f for f in page.frames if "trocarSenha" in f.url]
        if fr and fr[-1].query_selector("[id='novaSenhaField:novaSenha']"): return fr[-1]
        page.wait_for_timeout(1000)
    raise RuntimeError("tela Trocar Senha nao abriu pelo menu")

def trocar(page, atual, nova):
    fr = abrir_tela_senha(page)
    fr.fill("[id='senhaAtualField:senhaAtual']", atual)
    fr.fill("[id='novaSenhaField:novaSenha']", nova)
    fr.fill("[id='confirmarSenhaField:confirmarSenha']", nova)
    fr.click("button:has-text('Gravar'), a:has-text('Gravar'), [id$='botaoSalvar']"); page.wait_for_timeout(8000)
    return msgs(fr) + msgs(page)

with sync_playwright() as p:
    def nova_pagina():
        b = p.chromium.launch(); pg = b.new_page(viewport={"width": 1400, "height": 1000}, locale="pt-BR"); pg.set_default_timeout(30000)
        return b, pg
    b, page = nova_pagina()
    checa("login com a senha original", login(page, P0))
    m = trocar(page, "senhaErradaQualquer123", P1)
    checa("senha atual errada e recusada", any("confer" in x.lower() for x in m), " | ".join(m))
    m = trocar(page, P0, P1)
    checa("troca P0 -> P1 informa sucesso (antes: 'Senha atual nao conferem')", any("sucesso" in x.lower() for x in m), " | ".join(m))
    b.close()

    b, page = nova_pagina()
    checa("login com a senha ANTIGA e recusado na hora", not login(page, P0))
    b.close()
    b, page = nova_pagina()
    checa("login com a senha NOVA funciona", login(page, P1))
    m = trocar(page, P1, P0)
    checa("troca de volta P1 -> P0 informa sucesso", any("sucesso" in x.lower() for x in m), " | ".join(m))
    b.close()
    b, page = nova_pagina()
    checa("ao final, login com a senha original funciona", login(page, P0))
    page.screenshot(path=os.path.join(os.path.dirname(os.path.abspath(__file__)), "banco-final.png"))
    b.close()

print("RESULTADO:", "TODOS OS TESTES OK" if not falhas else "FALHAS: " + ", ".join(falhas))
sys.exit(1 if falhas else 0)
