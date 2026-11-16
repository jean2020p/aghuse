package br.gov.mec.aghu.casca.business;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.sql.Connection;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.List;

import javax.sql.DataSource;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import br.gov.mec.aghu.casca.business.ServicoDiretorioSenha.FalhaTrocaSenhaException;
import br.gov.mec.aghu.casca.business.ServicoDiretorioSenha.Motivo;

/**
 * Testes da troca de senha no modo "banco" (integracao-ldap). O PostgreSQL e simulado:
 * o datasource de login, a conexao e o statement sao mocks.
 */
public class ServicoSenhaBancoTest {

	private DataSource ds;
	private Connection conexao;
	private Statement st;
	private ServicoSenhaBanco servico;

	@BeforeEach
	public void setUp() throws Exception {
		ds = mock(DataSource.class);
		conexao = mock(Connection.class);
		st = mock(Statement.class);
		when(conexao.createStatement()).thenReturn(st);
		servico = new ServicoSenhaBanco() {
			@Override
			DataSource obterDataSource() {
				return ds;
			}
		};
	}

	private static SQLException senhaInvalida() {
		return new SQLException("FATAL: password authentication failed", "28P01");
	}

	@Test
	public void disponivelQuandoHaDatasourceDeLogin() {
		assertTrue(servico.isDisponivel());
	}

	@Test
	public void indisponivelSemDatasourceDeLogin() {
		ServicoSenhaBanco semDs = new ServicoSenhaBanco() {
			@Override
			DataSource obterDataSource() {
				return null;
			}
		};
		assertFalse(semDs.isDisponivel());
		FalhaTrocaSenhaException e = assertThrows(FalhaTrocaSenhaException.class, () -> semDs.alterarSenha("AGHU", "a", "b"));
		assertEquals(Motivo.NAO_PERMITIDO, e.getMotivo());
	}

	@Test
	public void trocaAsDuasRolesConectandoComoOProprioUsuario() throws Exception {
		when(ds.getConnection(anyString(), eq("senhaAtual123"))).thenReturn(conexao);

		servico.alterarSenha("AGHU", "senhaAtual123", "senhaNova456");

		verify(ds).getConnection("AGHU", "senhaAtual123");
		verify(ds).getConnection("aghu", "senhaAtual123");
		ArgumentCaptor<String> sql = ArgumentCaptor.forClass(String.class);
		verify(st, org.mockito.Mockito.times(6)).execute(sql.capture());
		List<String> comandos = sql.getAllValues();
		assertEquals("ALTER ROLE CURRENT_USER PASSWORD 'senhaNova456'", comandos.get(0));
		assertTrue(comandos.get(1).contains("pg_terminate_backend(pid)"), "encerra as outras conexoes da role (pool com a senha antiga)");
		assertEquals("SELECT pg_terminate_backend(pg_backend_pid())", comandos.get(2));
	}

	@Test
	public void roleEmMinusculasInexistenteNaoImpedeATroca() throws Exception {
		when(ds.getConnection("AGHU", "senhaAtual123")).thenReturn(conexao);
		when(ds.getConnection("aghu", "senhaAtual123")).thenThrow(senhaInvalida());

		servico.alterarSenha("AGHU", "senhaAtual123", "senhaNova456");

		verify(st).execute("ALTER ROLE CURRENT_USER PASSWORD 'senhaNova456'");
	}

	@Test
	public void senhaAtualErrada() throws Exception {
		when(ds.getConnection(anyString(), anyString())).thenThrow(senhaInvalida());
		FalhaTrocaSenhaException e = assertThrows(FalhaTrocaSenhaException.class,
				() -> servico.alterarSenha("AGHU", "errada", "senhaNova456"));
		assertEquals(Motivo.CREDENCIAL_INVALIDA, e.getMotivo());
		verify(st, never()).execute(anyString());
	}

	@Test
	public void senhaInvalidaEmbrulhadaPeloPoolEReconhecida() throws Exception {
		SQLException doPool = new SQLException("IJ031020: Unable to obtain connection", (String) null);
		doPool.initCause(senhaInvalida());
		when(ds.getConnection(anyString(), anyString())).thenThrow(doPool);
		FalhaTrocaSenhaException e = assertThrows(FalhaTrocaSenhaException.class,
				() -> servico.alterarSenha("AGHU", "errada", "senhaNova456"));
		assertEquals(Motivo.CREDENCIAL_INVALIDA, e.getMotivo());
	}

	@Test
	public void erroDeComunicacaoComOBanco() throws Exception {
		when(ds.getConnection(anyString(), anyString())).thenThrow(new SQLException("Connection refused", "08001"));
		FalhaTrocaSenhaException e = assertThrows(FalhaTrocaSenhaException.class,
				() -> servico.alterarSenha("AGHU", "senhaAtual123", "senhaNova456"));
		assertEquals(Motivo.ERRO_DIRETORIO, e.getMotivo());
	}

	@Test
	public void literalSqlEscapaAspas() {
		assertEquals("'abc'", ServicoSenhaBanco.literalSql("abc"));
		assertEquals("'a''b''''c'", ServicoSenhaBanco.literalSql("a'b''c"));
	}

	@Test
	public void estadoSqlProcuraNasCausas() {
		SQLException externa = new SQLException("externa");
		externa.initCause(new RuntimeException("meio", new SQLException("x", "28P01")));
		assertEquals("28P01", ServicoSenhaBanco.estadoSql(externa));
		assertNull(ServicoSenhaBanco.estadoSql(new RuntimeException("sem sql")));
	}
}
