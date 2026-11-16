/** AGHUse - Aplicativo de Gestao Hospitalar
  *
  * Direitos Autorais Reservados (c) 2016, Hospital de Clinicas de Porto Alegre
  *
  * Este programa e software livre; voce pode redistribui-lo e/ou modifica-lo sob os termos de
  * Licenca Publica Geral GNU conforme publicada pela Free Software Foundation; tanto a versao
  * 2 da Licenca, como (a seu criterio) qualquer versao posterior.
  *
  * Este programa e distribuido na expectativa de que seja util, porem, SEM NENHUMA GARANTIA;
  * nem mesmo a garantia implicita de COMERCIABILIDADE OU ADEQUACAO A UMA FINALIDADE ESPECIFICA.
  * Consulte a Licenca Publica Geral do GNU para mais detalhes.
  *
  * Voce deve ter recebido uma copia da Licenca Publica Geral do GNU junto com este programa;
  * se nao, escreva para a Free Software Foundation, Ind., no endereco 59 Temple Street, Suite
  * 330, Boston, MA 02111-137 USA.
  *
  * Hospital de Clinicas de Porto Alegre. Rua Ramiro Barcelos, 2350 - 2Andar CGTI - Bairro Santa Cecilia, Porto Alegre - RS, 90.035-903. E-mail: centralAGHUse@hcpa.edu.br
  */

package br.gov.mec.aghu.casca.business;

import java.io.ByteArrayOutputStream;
import java.nio.charset.StandardCharsets;
import java.util.Hashtable;

import javax.inject.Inject;
import javax.naming.AuthenticationException;
import javax.naming.Context;
import javax.naming.NamingEnumeration;
import javax.naming.NamingException;
import javax.naming.directory.BasicAttribute;
import javax.naming.directory.DirContext;
import javax.naming.directory.ModificationItem;
import javax.naming.directory.SearchControls;
import javax.naming.directory.SearchResult;
import javax.naming.ldap.ExtendedRequest;
import javax.naming.ldap.ExtendedResponse;
import javax.naming.ldap.InitialLdapContext;

import org.apache.commons.logging.Log;
import org.apache.commons.logging.LogFactory;

import br.gov.mec.aghu.core.commons.ParametrosSistema;

/**
 * Troca da senha do proprio usuario no diretorio LDAP / Active Directory.
 *
 * MODIFICACAO (instalador independente do AGHUse, integracao-ldap): no AGHUse 13.250 o metodo
 * UsuarioON.alterarSenha apenas lancava UnsupportedOperationException ("Alteracao de senha no
 * LDAP/AD nao suportada"), de modo que a tela "Trocar Senha" (menu "Senha") nao funcionava fora
 * do HCPA. Esta classe implementa a troca usando a mesma configuracao LDAP que o AGHUse ja usa
 * para o login (sd_server_address, sd_server_port, sd_user_dn, sd_user_context_dn,
 * sd_filter_expression), sem novas dependencias:
 *
 * 1. conecta ao diretorio autenticando COMO O PROPRIO USUARIO, com a senha atual (prova de posse);
 * 2. tenta a operacao padrao LDAP "Password Modify" (RFC 3062), aceita por OpenLDAP e outros:
 *    o servidor confere a senha atual, aplica o hash configurado (ex.: {SSHA}) e a politica de senhas;
 * 3. se o servidor nao suportar a RFC 3062 (Active Directory / AD LDS), usa o metodo do AD:
 *    remove a senha atual e grava a nova no atributo unicodePwd. O AD exige conexao segura
 *    (LDAPS, porta 636) para isso.
 *
 * Nenhuma conta administrativa e usada: o usuario so consegue alterar a propria senha.
 */
public class ServicoDiretorioSenha {

	private static final Log LOG = LogFactory.getLog(ServicoDiretorioSenha.class);

	/** OID da operacao estendida LDAP Password Modify (RFC 3062). */
	private static final String OID_PASSWORD_MODIFY = "1.3.6.1.4.1.4203.1.11.1";

	private static final String TEMPO_CONEXAO_MS = "10000";
	private static final String TEMPO_LEITURA_MS = "20000";

	/** Motivo da falha na troca de senha, traduzido pelo UsuarioON em mensagem de negocio. */
	public enum Motivo {
		/** a senha atual nao confere (bind recusado). */
		CREDENCIAL_INVALIDA,
		/** o diretorio recusou a nova senha (politica de senhas, historico, complexidade). */
		POLITICA_SENHA,
		/** o diretorio nao permite a troca por esta conexao (ex.: AD sem LDAPS). */
		NAO_PERMITIDO,
		/** outro erro de comunicacao ou do servidor. */
		ERRO_DIRETORIO
	}

	/** Falha na troca de senha. */
	public static class FalhaTrocaSenhaException extends Exception {
		private static final long serialVersionUID = 1L;
		private final Motivo motivo;

		public FalhaTrocaSenhaException(Motivo motivo, String mensagem, Throwable causa) {
			super(mensagem, causa);
			this.motivo = motivo;
		}

		public Motivo getMotivo() {
			return motivo;
		}
	}

	@Inject
	private ParametrosSistema parametros;

	/**
	 * Indica se a autenticacao e feita por LDAP/AD (ha servidor e DN de usuario configurados).
	 * No modo "banco" (realm AghuseDbConnectionSecurityRealm) estes parametros ficam vazios.
	 */
	public boolean isDiretorioConfigurado() {
		String servidor = parametros.getParametro(ParametrosSistema.SD_SERVER_ADDRESS);
		String userDn = parametros.getParametro(ParametrosSistema.SD_USER_DN);
		return servidor != null && !servidor.isBlank() && userDn != null && userDn.contains("%s");
	}

	/**
	 * Altera a senha do usuario no diretorio.
	 *
	 * @param login login do usuario (o mesmo usado no AGHUse)
	 * @param senhaAtual senha atual
	 * @param senhaNova nova senha
	 */
	public void alterarSenha(String login, String senhaAtual, String senhaNova) throws FalhaTrocaSenhaException {
		String userDn = parametros.getParametro(ParametrosSistema.SD_USER_DN).replace("%s", escaparValorDn(login));
		InitialLdapContext ctx = null;
		try {
			try {
				ctx = conectar(userDn, senhaAtual);
			} catch (AuthenticationException e) {
				throw new FalhaTrocaSenhaException(Motivo.CREDENCIAL_INVALIDA, "senha atual recusada pelo diretorio", e);
			}

			try {
				ctx.extendedOperation(new PasswordModifyRequest(senhaAtual, senhaNova));
				LOG.info("Senha alterada no diretorio (RFC 3062) para o usuario " + login);
				return;
			} catch (NamingException e) {
				int codigo = codigoLdap(e);
				if (codigo == 19) { // constraintViolation: politica de senhas
					throw new FalhaTrocaSenhaException(Motivo.POLITICA_SENHA, e.getMessage(), e);
				}
				if (codigo == 49) { // invalidCredentials: senha atual nao confere
					throw new FalhaTrocaSenhaException(Motivo.CREDENCIAL_INVALIDA, e.getMessage(), e);
				}
				if (codigo == 50) { // insufficientAccessRights: ACL nao permite
					throw new FalhaTrocaSenhaException(Motivo.NAO_PERMITIDO, e.getMessage(), e);
				}
				LOG.info("Diretorio nao aceitou Password Modify (RFC 3062), tentando metodo do Active Directory: " + e.getMessage());
			}

			alterarSenhaActiveDirectory(ctx, login, senhaAtual, senhaNova);
			LOG.info("Senha alterada no diretorio (unicodePwd) para o usuario " + login);

		} catch (NamingException e) {
			throw new FalhaTrocaSenhaException(Motivo.ERRO_DIRETORIO, e.getMessage(), e);
		} finally {
			if (ctx != null) {
				try {
					ctx.close();
				} catch (NamingException e) {
					LOG.debug("Erro ao fechar a conexao com o diretorio", e);
				}
			}
		}
	}

	/** Active Directory / AD LDS: remove a senha atual e adiciona a nova em unicodePwd (exige LDAPS). */
	private void alterarSenhaActiveDirectory(InitialLdapContext ctx, String login, String senhaAtual, String senhaNova)
			throws NamingException, FalhaTrocaSenhaException {
		String dn = localizarDn(ctx, login);
		ModificationItem[] mods = new ModificationItem[] {
				new ModificationItem(DirContext.REMOVE_ATTRIBUTE, new BasicAttribute("unicodePwd", senhaUnicodePwd(senhaAtual))),
				new ModificationItem(DirContext.ADD_ATTRIBUTE, new BasicAttribute("unicodePwd", senhaUnicodePwd(senhaNova))) };
		try {
			ctx.modifyAttributes(dn, mods);
		} catch (NamingException e) {
			int codigo = codigoLdap(e);
			if (codigo == 19) {
				throw new FalhaTrocaSenhaException(Motivo.POLITICA_SENHA, e.getMessage(), e);
			}
			if (codigo == 53 || codigo == 50) { // unwillingToPerform (sem LDAPS) ou sem permissao
				throw new FalhaTrocaSenhaException(Motivo.NAO_PERMITIDO, e.getMessage(), e);
			}
			throw e;
		}
	}

	/** Localiza o DN real do usuario (no AD o login pode ser %s@dominio, que nao e um DN). */
	private String localizarDn(InitialLdapContext ctx, String login) throws NamingException {
		String base = parametros.getParametro(ParametrosSistema.SD_USER_CONTEXT);
		String filtro = parametros.getParametro(ParametrosSistema.SD_FILTER_EXPRESSION);
		if (base == null || base.isBlank() || filtro == null || !filtro.contains("%s")) {
			return parametros.getParametro(ParametrosSistema.SD_USER_DN).replace("%s", escaparValorDn(login));
		}
		SearchControls controles = new SearchControls();
		controles.setSearchScope(SearchControls.SUBTREE_SCOPE);
		controles.setReturningAttributes(new String[0]);
		controles.setCountLimit(1);
		NamingEnumeration<SearchResult> resultado = ctx.search(base, filtro.replace("%s", escaparValorFiltro(login)), controles);
		try {
			if (resultado.hasMore()) {
				return resultado.next().getNameInNamespace();
			}
		} finally {
			resultado.close();
		}
		throw new NamingException("usuario " + login + " nao encontrado em " + base);
	}

	/** Abre a conexao autenticada (visivel no pacote para os testes substituirem por um simulador). */
	InitialLdapContext conectar(String principal, String senha) throws NamingException {
		Hashtable<String, String> env = new Hashtable<>();
		env.put(Context.INITIAL_CONTEXT_FACTORY, "com.sun.jndi.ldap.LdapCtxFactory");
		env.put(Context.PROVIDER_URL, montarUrls(parametros.getParametro(ParametrosSistema.SD_SERVER_ADDRESS),
				parametros.getParametro(ParametrosSistema.SD_SERVER_PORT)));
		env.put(Context.SECURITY_AUTHENTICATION, "simple");
		env.put(Context.SECURITY_PRINCIPAL, principal);
		env.put(Context.SECURITY_CREDENTIALS, senha);
		env.put("com.sun.jndi.ldap.connect.timeout", TEMPO_CONEXAO_MS);
		env.put("com.sun.jndi.ldap.read.timeout", TEMPO_LEITURA_MS);
		return new InitialLdapContext(env, null);
	}

	/** Mesma regra do ServicoDiretorio (varios servidores separados por virgula); porta 636 usa LDAPS. */
	static String montarUrls(String servidores, String porta) {
		StringBuilder urls = new StringBuilder();
		for (String servidor : servidores.split(",")) {
			if (!servidor.isBlank()) {
				String esquema = "636".equals(porta == null ? "" : porta.trim()) ? "ldaps://" : "ldap://";
				urls.append(esquema).append(servidor.trim()).append(':').append(porta == null ? "389" : porta.trim()).append(' ');
			}
		}
		return urls.toString().trim();
	}

	/** Codigo de resultado LDAP contido na mensagem da excecao JNDI ("[LDAP: error code 19 - ...]"). */
	static int codigoLdap(NamingException e) {
		String msg = e.getMessage();
		if (msg != null) {
			int i = msg.indexOf("error code ");
			if (i >= 0) {
				int j = i + "error code ".length();
				int k = j;
				while (k < msg.length() && Character.isDigit(msg.charAt(k))) {
					k++;
				}
				if (k > j) {
					return Integer.parseInt(msg.substring(j, k));
				}
			}
		}
		return -1;
	}

	/** Formato exigido pelo AD em unicodePwd: a senha entre aspas, em UTF-16LE. */
	static byte[] senhaUnicodePwd(String senha) {
		return ("\"" + senha + "\"").getBytes(StandardCharsets.UTF_16LE);
	}

	/** Escapa caracteres especiais de um valor de RDN (RFC 4514). */
	static String escaparValorDn(String valor) {
		StringBuilder sb = new StringBuilder();
		for (int i = 0; i < valor.length(); i++) {
			char c = valor.charAt(i);
			if (",+\"\\<>;=".indexOf(c) >= 0 || (i == 0 && (c == ' ' || c == '#')) || (i == valor.length() - 1 && c == ' ')) {
				sb.append('\\');
			}
			sb.append(c);
		}
		return sb.toString();
	}

	/** Escapa caracteres especiais de um valor em filtro LDAP (RFC 4515). */
	static String escaparValorFiltro(String valor) {
		StringBuilder sb = new StringBuilder();
		for (char c : valor.toCharArray()) {
			switch (c) {
			case '*': sb.append("\\2a"); break;
			case '(': sb.append("\\28"); break;
			case ')': sb.append("\\29"); break;
			case '\\': sb.append("\\5c"); break;
			case '\0': sb.append("\\00"); break;
			default: sb.append(c);
			}
		}
		return sb.toString();
	}

	/**
	 * Requisicao Password Modify (RFC 3062) para o proprio usuario autenticado:
	 * PasswdModifyRequestValue ::= SEQUENCE { oldPasswd [1] OCTET STRING, newPasswd [2] OCTET STRING }
	 */
	static class PasswordModifyRequest implements ExtendedRequest {
		private static final long serialVersionUID = 1L;
		private final byte[] valor;

		PasswordModifyRequest(String senhaAtual, String senhaNova) {
			ByteArrayOutputStream seq = new ByteArrayOutputStream();
			escreverTlv(seq, 0x81, senhaAtual.getBytes(StandardCharsets.UTF_8));
			escreverTlv(seq, 0x82, senhaNova.getBytes(StandardCharsets.UTF_8));
			ByteArrayOutputStream total = new ByteArrayOutputStream();
			escreverTlv(total, 0x30, seq.toByteArray());
			this.valor = total.toByteArray();
		}

		@Override
		public String getID() {
			return OID_PASSWORD_MODIFY;
		}

		@Override
		public byte[] getEncodedValue() {
			return valor.clone();
		}

		@Override
		public ExtendedResponse createExtendedResponse(String id, byte[] berValue, int offset, int length) {
			return new ExtendedResponse() {
				private static final long serialVersionUID = 1L;

				@Override
				public String getID() {
					return id;
				}

				@Override
				public byte[] getEncodedValue() {
					return berValue;
				}
			};
		}

		private static void escreverTlv(ByteArrayOutputStream out, int tag, byte[] conteudo) {
			out.write(tag);
			int n = conteudo.length;
			if (n < 0x80) {
				out.write(n);
			} else if (n < 0x100) {
				out.write(0x81);
				out.write(n);
			} else {
				out.write(0x82);
				out.write((n >> 8) & 0xFF);
				out.write(n & 0xFF);
			}
			out.write(conteudo, 0, n);
		}
	}
}
