#!/usr/bin/env python3
"""Preenche a configuracao do WildFly/AGHUse a partir das variaveis de ambiente AGHUSE_*.

Uso: configurar_wildfly.py <JBOSS_HOME>
"""
import os
import re
import sys
from xml.sax.saxutils import escape

WF = sys.argv[1]
XML = os.path.join(WF, "standalone/configuration/standalone-full.xml")
PROPS = os.path.join(WF, "modules/br/gov/mec/aghu/configuration/main/properties/app-parameters.properties")

E = os.environ
modo = E["AGHUSE_MODO_LOGIN"]
REALM_LDAP = "br.gov.mec.aghu.casca.autenticacao.AghuseLdapSecurityRealm"
REALM_BANCO = "br.gov.mec.aghu.casca.autenticacao.AghuseDbConnectionSecurityRealm"

valores = {
    "NOME_AMBIENTE": E["AGHUSE_NOME_AMBIENTE"],
    "DB_HOST": "127.0.0.1",
    "DB_PORTA": E["AGHUSE_PG_PORTA"],
    "DB_NOME": E["AGHUSE_DB_NOME"],
    "DB_USUARIO": E["AGHUSE_DB_USUARIO"],
    "DB_SENHA": E["AGHUSE_DB_SENHA"],
    "DB_USUARIO_FIT": E["AGHUSE_DB_USUARIO_FIT"],
    "DB_SENHA_FIT": E["AGHUSE_DB_SENHA_FIT"],
    "REALM_CLASSE": REALM_BANCO if modo == "banco" else REALM_LDAP,
    "LDAP_HOST": E.get("AGHUSE_LDAP_HOST", ""),
    "LDAP_PORTA": E.get("AGHUSE_LDAP_PORTA", "389"),
    "LDAP_USER_DN": E.get("AGHUSE_LDAP_USER_DN", ""),
    "LDAP_BIND_DN": E.get("AGHUSE_LDAP_BIND_DN", ""),
    "LDAP_BIND_SENHA": E.get("AGHUSE_LDAP_BIND_SENHA", ""),
    "LDAP_BASE_USUARIOS": E.get("AGHUSE_LDAP_BASE_USUARIOS", ""),
    "LDAP_ATRIBUTO_LOGIN": E.get("AGHUSE_LDAP_ATRIBUTO_LOGIN", ""),
    "LDAP_FILTRO": E.get("AGHUSE_LDAP_FILTRO", ""),
    "SMTP_HOST": E.get("AGHUSE_SMTP_HOST", "127.0.0.1"),
}
if modo == "banco":  # porta LDAP precisa ser numerica mesmo sem uso
    valores["LDAP_PORTA"] = valores["LDAP_PORTA"] or "389"


def preencher(texto, esc):
    for k, v in valores.items():
        texto = texto.replace("__AGHUSE_%s__" % k, esc(v))
    resto = re.findall(r"__AGHUSE_[A-Z_]+__", texto)
    if resto:
        sys.exit("ERRO: marcadores sem valor: %s" % sorted(set(resto)))
    return texto


def props_escape(v):
    return v.replace("\\", "\\\\")


# ---------- standalone-full.xml ----------
x = open(XML, encoding="utf-8").read()
x = preencher(x, lambda v: escape(v, {'"': "&quot;"}))

if modo == "banco":
    alvo = 'class-name="%s">\n                    <configuration>\n' % REALM_BANCO
    if alvo not in x:
        sys.exit("ERRO: bloco do realm nao encontrado no standalone-full.xml")
    x = x.replace(alvo, alvo + '                        <property name="loginDatasource" value="java:/aghuLoginDatasource"/>\n', 1)
    ds = """                <datasource jndi-name="java:/aghuLoginDatasource" pool-name="aghulogin" enabled="true" use-java-context="true">
                    <connection-url>jdbc:postgresql://127.0.0.1:%s/%s</connection-url>
                    <driver>PostgresqlDriver</driver>
                    <pool>
                        <min-pool-size>0</min-pool-size>
                        <max-pool-size>5</max-pool-size>
                        <prefill>false</prefill>
                        <allow-multiple-users/>
                    </pool>
                    <validation>
                        <check-valid-connection-sql>select now()</check-valid-connection-sql>
                        <validate-on-match>true</validate-on-match>
                    </validation>
                </datasource>
""" % (escape(valores["DB_PORTA"]), escape(E.get("AGHUSE_DB_LOGIN", "aghuse_login")))
    if "                <drivers>" not in x:
        sys.exit("ERRO: secao <drivers> nao encontrada no standalone-full.xml")
    x = x.replace("                <drivers>", ds + "                <drivers>", 1)
# proxy reverso com HTTPS: o WildFly passa a usar X-Forwarded-Proto/Host/For
# (sem isso, apos o login o navegador e redirecionado para http://)
if E.get("AGHUSE_PROXY_REVERSO", "nao") == "sim":
    padrao = re.compile(r'<http-listener name="default"(?![^>]*proxy-address-forwarding)')
    if not padrao.search(x):
        sys.exit("ERRO: http-listener 'default' nao encontrado no standalone-full.xml")
    x = padrao.sub('<http-listener name="default" proxy-address-forwarding="true"', x, count=1)
open(XML, "w", encoding="utf-8").write(x)

# ---------- app-parameters.properties ----------
p = open(PROPS, encoding="utf-8").read()
p = preencher(p, props_escape)
p = p.replace("@bloq.metodo.logout@", "websocket")
p = re.sub(r"@[a-z][a-zA-Z._-]*@", "", p)

porta_http = 8080 + int(E.get("AGHUSE_PORT_OFFSET", "0"))
p = re.sub(r"(?m)^remote_ejb_server=.*$", "remote_ejb_server=localhost:%d" % porta_http, p)
open(PROPS, "w", encoding="utf-8").write(p)

print("configuracao do WildFly gerada (login: %s)" % modo)
