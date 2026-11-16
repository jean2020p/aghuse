package br.gov.mec.aghu.casca.business;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.junit.jupiter.api.Assumptions.assumeTrue;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.lang.reflect.Field;
import java.util.Hashtable;

import javax.naming.Context;
import javax.naming.NamingException;
import javax.naming.directory.BasicAttribute;
import javax.naming.directory.BasicAttributes;
import javax.naming.directory.DirContext;
import javax.naming.directory.InitialDirContext;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import br.gov.mec.aghu.casca.business.ServicoDiretorioSenha.FalhaTrocaSenhaException;
import br.gov.mec.aghu.casca.business.ServicoDiretorioSenha.Motivo;
import br.gov.mec.aghu.core.commons.ParametrosSistema;

/**
 * Teste de integracao da troca de senha (integracao-ldap) contra um servidor LDAP REAL (ex.: OpenLDAP).
 *
 * So executa quando as propriedades abaixo sao informadas; caso contrario e ignorado (assumeTrue):
 *   -Daghuse.it.ldap.host=127.0.0.1 -Daghuse.it.ldap.port=389
 *   -Daghuse.it.ldap.base=ou=people,dc=aghuse,dc=local
 *   -Daghuse.it.ldap.admin.dn=cn=admin,dc=aghuse,dc=local -Daghuse.it.ldap.admin.senha=...
 * Cria uma conta temporaria uid=teste-it-<numero> na base, troca a senha e remove a conta ao final.
 */
public class ServicoDiretorioSenhaLdapRealTest {

	private String host;
	private String porta;
	private String base;
	private String adminDn;
	private String adminSenha;
	private String login;
	private String dn;
	private ServicoDiretorioSenha servico;

	@BeforeEach
	public void setUp() throws Exception {
		host = System.getProperty("aghuse.it.ldap.host");
		assumeTrue(host != null && !host.isBlank(), "LDAP real nao informado (-Daghuse.it.ldap.host): teste ignorado");
		porta = System.getProperty("aghuse.it.ldap.port", "389");
		base = System.getProperty("aghuse.it.ldap.base");
		adminDn = System.getProperty("aghuse.it.ldap.admin.dn");
		adminSenha = System.getProperty("aghuse.it.ldap.admin.senha");
		login = "teste-it-" + System.currentTimeMillis();
		dn = "uid=" + login + "," + base;

		BasicAttributes attrs = new BasicAttributes(true);
		BasicAttribute oc = new BasicAttribute("objectClass");
		oc.add("inetOrgPerson");
		attrs.put(oc);
		attrs.put("uid", login);
		attrs.put("cn", "Teste Integracao");
		attrs.put("sn", "Integracao");
		attrs.put("userPassword", "SenhaInicial123");
		DirContext admin = conectar(adminDn, adminSenha);
		admin.createSubcontext(dn, attrs);
		admin.close();

		ParametrosSistema parametros = mock(ParametrosSistema.class);
		when(parametros.getParametro(ParametrosSistema.SD_SERVER_ADDRESS)).thenReturn(host);
		when(parametros.getParametro(ParametrosSistema.SD_SERVER_PORT)).thenReturn(porta);
		when(parametros.getParametro(ParametrosSistema.SD_USER_DN)).thenReturn("uid=%s," + base);
		when(parametros.getParametro(ParametrosSistema.SD_USER_CONTEXT)).thenReturn(base);
		when(parametros.getParametro(ParametrosSistema.SD_FILTER_EXPRESSION)).thenReturn("(&(objectClass=inetOrgPerson)(uid=%s))");
		servico = new ServicoDiretorioSenha();
		Field f = ServicoDiretorioSenha.class.getDeclaredField("parametros");
		f.setAccessible(true);
		f.set(servico, parametros);
	}

	@AfterEach
	public void limpar() throws Exception {
		if (host != null && !host.isBlank()) {
			DirContext admin = conectar(adminDn, adminSenha);
			try {
				admin.destroySubcontext(dn);
			} finally {
				admin.close();
			}
		}
	}

	private DirContext conectar(String principal, String senha) throws NamingException {
		Hashtable<String, String> env = new Hashtable<>();
		env.put(Context.INITIAL_CONTEXT_FACTORY, "com.sun.jndi.ldap.LdapCtxFactory");
		env.put(Context.PROVIDER_URL, "ldap://" + host + ":" + porta);
		env.put(Context.SECURITY_AUTHENTICATION, "simple");
		env.put(Context.SECURITY_PRINCIPAL, principal);
		env.put(Context.SECURITY_CREDENTIALS, senha);
		return new InitialDirContext(env);
	}

	private boolean autentica(String senha) {
		try {
			conectar(dn, senha).close();
			return true;
		} catch (NamingException e) {
			return false;
		}
	}

	@Test
	public void trocaDeSenhaNoLdapReal() throws Exception {
		assertTrue(autentica("SenhaInicial123"));

		servico.alterarSenha(login, "SenhaInicial123", "SenhaNovaIntegracao456");

		assertTrue(autentica("SenhaNovaIntegracao456"), "a nova senha deve autenticar");
		assertFalse(autentica("SenhaInicial123"), "a senha antiga nao deve mais autenticar");
	}

	@Test
	public void senhaAtualErradaNoLdapReal() {
		FalhaTrocaSenhaException e = assertThrows(FalhaTrocaSenhaException.class,
				() -> servico.alterarSenha(login, "SenhaErrada000", "SenhaNovaIntegracao456"));
		assertEquals(Motivo.CREDENCIAL_INVALIDA, e.getMotivo());
		assertTrue(autentica("SenhaInicial123"), "a senha original deve continuar valendo");
	}
}
