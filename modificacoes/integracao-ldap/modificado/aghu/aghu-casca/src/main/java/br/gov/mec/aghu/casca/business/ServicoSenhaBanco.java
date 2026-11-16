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

import java.sql.Connection;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.LinkedHashSet;
import java.util.Set;

import javax.naming.InitialContext;
import javax.naming.NamingException;
import javax.sql.DataSource;

import org.apache.commons.logging.Log;
import org.apache.commons.logging.LogFactory;

import br.gov.mec.aghu.casca.business.ServicoDiretorioSenha.FalhaTrocaSenhaException;
import br.gov.mec.aghu.casca.business.ServicoDiretorioSenha.Motivo;

/**
 * Troca da senha do proprio usuario quando o login e feito pelo PostgreSQL (modo "banco",
 * realm AghuseDbConnectionSecurityRealm). MODIFICACAO (integracao-ldap, variante nao oficial).
 *
 * No modo banco cada login e uma role do PostgreSQL, conferida pelo datasource de login
 * (java:/aghuLoginDatasource, banco vazio "aghuse_login", com allow-multiple-users). A troca:
 * 1. conecta pelo datasource de login COMO O PROPRIO USUARIO, com a senha atual (prova de posse);
 * 2. executa ALTER ROLE CURRENT_USER PASSWORD (o PostgreSQL permite a qualquer role trocar a
 *    propria senha, sem conta administrativa; o hash segue password_encryption, ex.: scram-sha-256);
 * 3. encerra as conexoes daquela role (pg_terminate_backend), inclusive as guardadas no pool
 *    do servidor de aplicacao com a senha antiga, para que a senha antiga deixe de valer na hora.
 * O instalador cria a role em maiusculas e em minusculas (o login e aceito dos dois jeitos):
 * as duas sao atualizadas.
 *
 * Requisito: o datasource de login deve ser NAO transacional (jta="false"); caso contrario o
 * servidor de aplicacao recusa a conexao dentro da transacao da tela ("multiple last resources").
 */
public class ServicoSenhaBanco {

	private static final Log LOG = LogFactory.getLog(ServicoSenhaBanco.class);

	static final String JNDI_DATASOURCE_LOGIN = "java:/aghuLoginDatasource";

	/** SQLSTATE do PostgreSQL para senha invalida (invalid_password). */
	private static final String SQLSTATE_SENHA_INVALIDA = "28P01";

	/** Datasource de login (visivel no pacote para os testes substituirem). */
	DataSource obterDataSource() {
		try {
			return (DataSource) new InitialContext().lookup(JNDI_DATASOURCE_LOGIN);
		} catch (NamingException | ClassCastException e) {
			return null;
		}
	}

	/** Indica se o login e feito pelo PostgreSQL (existe o datasource de login). */
	public boolean isDisponivel() {
		return obterDataSource() != null;
	}

	public void alterarSenha(String login, String senhaAtual, String senhaNova) throws FalhaTrocaSenhaException {
		DataSource ds = obterDataSource();
		if (ds == null) {
			throw new FalhaTrocaSenhaException(Motivo.NAO_PERMITIDO, "datasource de login nao encontrado: " + JNDI_DATASOURCE_LOGIN, null);
		}
		Set<String> roles = new LinkedHashSet<>();
		roles.add(login);
		roles.add(login.toUpperCase());
		roles.add(login.toLowerCase());

		int alteradas = 0;
		boolean senhaRecusada = false;
		SQLException ultimoErro = null;
		for (String role : roles) {
			try (Connection c = ds.getConnection(role, senhaAtual)) {
				try (Statement st = c.createStatement()) {
					st.execute("ALTER ROLE CURRENT_USER PASSWORD " + literalSql(senhaNova));
				}
				encerrarConexoesDaRole(c);
				alteradas++;
				LOG.info("Senha alterada no PostgreSQL (modo banco) para a role " + role);
			} catch (SQLException e) {
				if (SQLSTATE_SENHA_INVALIDA.equals(estadoSql(e))) {
					senhaRecusada = true; // role inexistente ou com outra senha: so conta se nenhuma for alterada
				} else {
					ultimoErro = e;
				}
				LOG.debug("Troca de senha da role " + role + " nao realizada: " + e.getMessage());
			}
		}
		if (alteradas > 0) {
			return;
		}
		if (ultimoErro != null && !senhaRecusada) {
			throw new FalhaTrocaSenhaException(Motivo.ERRO_DIRETORIO, ultimoErro.getMessage(), ultimoErro);
		}
		throw new FalhaTrocaSenhaException(Motivo.CREDENCIAL_INVALIDA, "senha atual recusada pelo PostgreSQL", ultimoErro);
	}

	/**
	 * Encerra as outras conexoes da role (pool com a senha antiga) e, por ultimo, a propria
	 * conexao, para que ela nao volte ao pool autenticada com a senha antiga.
	 */
	private void encerrarConexoesDaRole(Connection c) {
		try (Statement st = c.createStatement()) {
			st.execute("SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE usename = current_user AND pid <> pg_backend_pid()");
		} catch (SQLException e) {
			LOG.debug("Nao foi possivel encerrar as outras conexoes da role: " + e.getMessage());
		}
		try (Statement st = c.createStatement()) {
			st.execute("SELECT pg_terminate_backend(pg_backend_pid())");
		} catch (SQLException e) {
			LOG.debug("Conexao propria encerrada (esperado): " + e.getMessage());
		}
	}

	/** Literal SQL com aspas simples duplicadas (standard_conforming_strings = on, padrao do PostgreSQL). */
	static String literalSql(String valor) {
		return "'" + valor.replace("'", "''") + "'";
	}

	/** SQLSTATE da excecao ou de alguma causa encadeada (o pool pode embrulhar a excecao do driver). */
	static String estadoSql(Throwable e) {
		for (Throwable t = e; t != null; t = t.getCause()) {
			if (t instanceof SQLException && ((SQLException) t).getSQLState() != null) {
				return ((SQLException) t).getSQLState();
			}
		}
		return null;
	}
}
