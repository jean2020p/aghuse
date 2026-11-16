package br.gov.mec.aghu.casca.business;

import static org.junit.jupiter.api.Assertions.assertArrayEquals;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.lang.reflect.Field;
import java.nio.charset.StandardCharsets;

import javax.naming.AuthenticationException;
import javax.naming.NamingEnumeration;
import javax.naming.NamingException;
import javax.naming.directory.DirContext;
import javax.naming.directory.ModificationItem;
import javax.naming.directory.SearchControls;
import javax.naming.directory.SearchResult;
import javax.naming.ldap.ExtendedRequest;
import javax.naming.ldap.InitialLdapContext;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import br.gov.mec.aghu.casca.business.ServicoDiretorioSenha.FalhaTrocaSenhaException;
import br.gov.mec.aghu.casca.business.ServicoDiretorioSenha.Motivo;
import br.gov.mec.aghu.core.commons.ParametrosSistema;

/**
 * Testes da troca de senha no diretorio LDAP/AD (integracao-ldap).
 * O servidor LDAP e simulado: a conexao (InitialLdapContext) e substituida por um mock.
 */
public class ServicoDiretorioSenhaTest {

	private static final String USER_DN = "uid=%s,ou=people,dc=aghuse,dc=local";

	private ParametrosSistema parametros;
	private InitialLdapContext ctx;
	private ServicoDiretorioSenha servico;
	private String principalUsado;
	private String senhaUsada;
	private NamingException falhaAoConectar;

	@BeforeEach
	public void setUp() throws Exception {
		parametros = mock(ParametrosSistema.class);
		when(parametros.getParametro(ParametrosSistema.SD_SERVER_ADDRESS)).thenReturn("127.0.0.1");
		when(parametros.getParametro(ParametrosSistema.SD_SERVER_PORT)).thenReturn("389");
		when(parametros.getParametro(ParametrosSistema.SD_USER_DN)).thenReturn(USER_DN);
		when(parametros.getParametro(ParametrosSistema.SD_USER_CONTEXT)).thenReturn("ou=people,dc=aghuse,dc=local");
		when(parametros.getParametro(ParametrosSistema.SD_FILTER_EXPRESSION)).thenReturn("(&(objectClass=inetOrgPerson)(uid=%s))");
		ctx = mock(InitialLdapContext.class);
		falhaAoConectar = null;
		servico = new ServicoDiretorioSenha() {
			@Override
			InitialLdapContext conectar(String principal, String senha) throws NamingException {
				principalUsado = principal;
				senhaUsada = senha;
				if (falhaAoConectar != null) {
					throw falhaAoConectar;
				}
				return ctx;
			}
		};
		Field f = ServicoDiretorioSenha.class.getDeclaredField("parametros");
		f.setAccessible(true);
		f.set(servico, parametros);
	}

	// ---------------------------------------------------------------- configuracao

	@Test
	public void diretorioConfiguradoQuandoHaServidorEDnComMarcador() {
		assertTrue(servico.isDiretorioConfigurado());
	}

	@Test
	public void diretorioNaoConfiguradoNoModoBanco() {
		when(parametros.getParametro(ParametrosSistema.SD_SERVER_ADDRESS)).thenReturn("");
		assertFalse(servico.isDiretorioConfigurado());
	}

	@Test
	public void diretorioNaoConfiguradoSemMarcadorNoDn() {
		when(parametros.getParametro(ParametrosSistema.SD_USER_DN)).thenReturn("uid=fixo,ou=people");
		assertFalse(servico.isDiretorioConfigurado());
	}

	// ---------------------------------------------------------------- troca pela RFC 3062 (OpenLDAP)

	@Test
	public void trocaComSucessoPelaRfc3062AutenticandoComoOProprioUsuario() throws Exception {
		servico.alterarSenha("MSILVA", "senhaAtual123", "senhaNova456");

		assertEquals("uid=MSILVA,ou=people,dc=aghuse,dc=local", principalUsado);
		assertEquals("senhaAtual123", senhaUsada);
		ArgumentCaptor<ExtendedRequest> req = ArgumentCaptor.forClass(ExtendedRequest.class);
		verify(ctx).extendedOperation(req.capture());
		assertEquals("1.3.6.1.4.1.4203.1.11.1", req.getValue().getID());
		verify(ctx, never()).modifyAttributes(anyString(), any(ModificationItem[].class));
		verify(ctx).close();
	}

	@Test
	public void senhaAtualRecusadaNoBind() {
		falhaAoConectar = new AuthenticationException("[LDAP: error code 49 - Invalid Credentials]");
		FalhaTrocaSenhaException e = assertThrows(FalhaTrocaSenhaException.class,
				() -> servico.alterarSenha("MSILVA", "errada", "senhaNova456"));
		assertEquals(Motivo.CREDENCIAL_INVALIDA, e.getMotivo());
	}

	@Test
	public void politicaDeSenhaDoDiretorio() throws Exception {
		when(ctx.extendedOperation(any())).thenThrow(new NamingException("[LDAP: error code 19 - Password fails quality checking policy]"));
		FalhaTrocaSenhaException e = assertThrows(FalhaTrocaSenhaException.class,
				() -> servico.alterarSenha("MSILVA", "senhaAtual123", "fraca"));
		assertEquals(Motivo.POLITICA_SENHA, e.getMotivo());
		verify(ctx).close();
	}

	@Test
	public void senhaAtualRecusadaPelaOperacaoDeTroca() throws Exception {
		when(ctx.extendedOperation(any())).thenThrow(new NamingException("[LDAP: error code 49 - Invalid Credentials]"));
		FalhaTrocaSenhaException e = assertThrows(FalhaTrocaSenhaException.class,
				() -> servico.alterarSenha("MSILVA", "senhaAtual123", "senhaNova456"));
		assertEquals(Motivo.CREDENCIAL_INVALIDA, e.getMotivo());
	}

	@Test
	public void aclDoDiretorioNaoPermite() throws Exception {
		when(ctx.extendedOperation(any())).thenThrow(new NamingException("[LDAP: error code 50 - Insufficient Access Rights]"));
		FalhaTrocaSenhaException e = assertThrows(FalhaTrocaSenhaException.class,
				() -> servico.alterarSenha("MSILVA", "senhaAtual123", "senhaNova456"));
		assertEquals(Motivo.NAO_PERMITIDO, e.getMotivo());
	}

	// ---------------------------------------------------------------- alternativa Active Directory (unicodePwd)

	@SuppressWarnings("unchecked")
	private void simularBuscaDoDn(String dn) throws NamingException {
		NamingEnumeration<SearchResult> resultado = mock(NamingEnumeration.class);
		SearchResult sr = mock(SearchResult.class);
		when(sr.getNameInNamespace()).thenReturn(dn);
		when(resultado.hasMore()).thenReturn(true);
		when(resultado.next()).thenReturn(sr);
		when(ctx.search(anyString(), anyString(), any(SearchControls.class))).thenReturn(resultado);
	}

	@Test
	public void semRfc3062UsaUnicodePwdDoActiveDirectory() throws Exception {
		when(ctx.extendedOperation(any())).thenThrow(new NamingException("[LDAP: error code 2 - unsupported extended operation]"));
		simularBuscaDoDn("CN=Maria Silva,OU=people,DC=hospital,DC=local");

		servico.alterarSenha("MSILVA", "senhaAtual123", "senhaNova456");

		ArgumentCaptor<ModificationItem[]> mods = ArgumentCaptor.forClass(ModificationItem[].class);
		verify(ctx).modifyAttributes(eq("CN=Maria Silva,OU=people,DC=hospital,DC=local"), mods.capture());
		ModificationItem[] m = mods.getValue();
		assertEquals(2, m.length);
		assertEquals(DirContext.REMOVE_ATTRIBUTE, m[0].getModificationOp());
		assertEquals("unicodePwd", m[0].getAttribute().getID());
		assertArrayEquals("\"senhaAtual123\"".getBytes(StandardCharsets.UTF_16LE), (byte[]) m[0].getAttribute().get());
		assertEquals(DirContext.ADD_ATTRIBUTE, m[1].getModificationOp());
		assertArrayEquals("\"senhaNova456\"".getBytes(StandardCharsets.UTF_16LE), (byte[]) m[1].getAttribute().get());
	}

	@Test
	public void activeDirectorySemLdapsNaoPermite() throws Exception {
		when(ctx.extendedOperation(any())).thenThrow(new NamingException("[LDAP: error code 2 - unsupported]"));
		simularBuscaDoDn("CN=MSILVA,OU=people,DC=hospital,DC=local");
		doThrow(new NamingException("[LDAP: error code 53 - 0000001F: SvcErr: DSID-031A12D2, problem 5003 (WILL_NOT_PERFORM)]"))
				.when(ctx).modifyAttributes(anyString(), any(ModificationItem[].class));
		FalhaTrocaSenhaException e = assertThrows(FalhaTrocaSenhaException.class,
				() -> servico.alterarSenha("MSILVA", "senhaAtual123", "senhaNova456"));
		assertEquals(Motivo.NAO_PERMITIDO, e.getMotivo());
	}

	@Test
	public void activeDirectoryPoliticaDeSenha() throws Exception {
		when(ctx.extendedOperation(any())).thenThrow(new NamingException("[LDAP: error code 2 - unsupported]"));
		simularBuscaDoDn("CN=MSILVA,OU=people,DC=hospital,DC=local");
		doThrow(new NamingException("[LDAP: error code 19 - 0000052D: Constraint violation]"))
				.when(ctx).modifyAttributes(anyString(), any(ModificationItem[].class));
		FalhaTrocaSenhaException e = assertThrows(FalhaTrocaSenhaException.class,
				() -> servico.alterarSenha("MSILVA", "senhaAtual123", "senhaNova456"));
		assertEquals(Motivo.POLITICA_SENHA, e.getMotivo());
	}

	// ---------------------------------------------------------------- utilitarios

	@Test
	public void codificacaoBerDaRequisicaoRfc3062() {
		byte[] v = new ServicoDiretorioSenha.PasswordModifyRequest("velha", "nova123").getEncodedValue();
		byte[] esperado = { 0x30, 16, (byte) 0x81, 5, 'v', 'e', 'l', 'h', 'a', (byte) 0x82, 7, 'n', 'o', 'v', 'a', '1', '2', '3' };
		assertArrayEquals(esperado, v);
	}

	@Test
	public void codificacaoBerComSenhaLonga() {
		String longa = "x".repeat(200);
		byte[] v = new ServicoDiretorioSenha.PasswordModifyRequest("a", longa).getEncodedValue();
		// [2] newPasswd com comprimento em forma longa: 0x82 0x81 0xC8 (200)
		assertEquals((byte) 0x82, v[v.length - 200 - 3]);
		assertEquals((byte) 0x81, v[v.length - 200 - 2]);
		assertEquals((byte) 200, v[v.length - 200 - 1]);
	}

	@Test
	public void leituraDoCodigoDeErroLdap() {
		assertEquals(19, ServicoDiretorioSenha.codigoLdap(new NamingException("[LDAP: error code 19 - policy]")));
		assertEquals(53, ServicoDiretorioSenha.codigoLdap(new NamingException("[LDAP: error code 53 - WILL_NOT_PERFORM]")));
		assertEquals(-1, ServicoDiretorioSenha.codigoLdap(new NamingException("connection refused")));
	}

	@Test
	public void montagemDasUrls() {
		assertEquals("ldap://127.0.0.1:389", ServicoDiretorioSenha.montarUrls("127.0.0.1", "389"));
		assertEquals("ldaps://ad1.local:636 ldaps://ad2.local:636", ServicoDiretorioSenha.montarUrls("ad1.local, ad2.local", "636"));
	}

	@Test
	public void escapesDeDnEFiltro() {
		assertEquals("a\\,b\\+c", ServicoDiretorioSenha.escaparValorDn("a,b+c"));
		assertEquals("\\#x", ServicoDiretorioSenha.escaparValorDn("#x"));
		assertEquals("a\\2ab\\28c\\29", ServicoDiretorioSenha.escaparValorFiltro("a*b(c)"));
	}
}
