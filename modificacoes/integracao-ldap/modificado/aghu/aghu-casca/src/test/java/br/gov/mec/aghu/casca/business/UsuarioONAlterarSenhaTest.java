package br.gov.mec.aghu.casca.business;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import org.junit.jupiter.api.Test;
import org.mockito.Mock;

import br.gov.mec.aghu.casca.business.ServicoDiretorioSenha.FalhaTrocaSenhaException;
import br.gov.mec.aghu.casca.business.ServicoDiretorioSenha.Motivo;
import br.gov.mec.aghu.casca.business.UsuarioON.UsuarioONExceptionCode;
import br.gov.mec.aghu.core.exception.ApplicationBusinessException;
import br.gov.mec.aghu.core.test.AGHUBaseUnitTest;

/**
 * Testes de UsuarioON.alterarSenha (integracao-ldap).
 * No AGHUse 13.250 original o metodo lancava UnsupportedOperationException.
 */
public class UsuarioONAlterarSenhaTest extends AGHUBaseUnitTest<UsuarioON> {

	@Mock
	private ServicoDiretorioSenha mockedServicoDiretorioSenha;

	@Mock
	private ServicoSenhaBanco mockedServicoSenhaBanco;

	@Test
	public void trocaComSucesso() throws Exception {
		when(mockedServicoDiretorioSenha.isDiretorioConfigurado()).thenReturn(true);
		assertTrue(systemUnderTest.alterarSenha("MSILVA", "senhaAtual123", "senhaNova456"));
		verify(mockedServicoDiretorioSenha).alterarSenha("MSILVA", "senhaAtual123", "senhaNova456");
	}

	@Test
	public void semLdapESemBancoIndisponivel() throws Exception {
		when(mockedServicoDiretorioSenha.isDiretorioConfigurado()).thenReturn(false);
		when(mockedServicoSenhaBanco.isDisponivel()).thenReturn(false);
		ApplicationBusinessException e = assertThrows(ApplicationBusinessException.class,
				() -> systemUnderTest.alterarSenha("MSILVA", "senhaAtual123", "senhaNova456"));
		assertEquals(UsuarioONExceptionCode.CASCA_MENSAGEM_SENHA_DIRETORIO_INDISPONIVEL, e.getCode());
		verify(mockedServicoDiretorioSenha, never()).alterarSenha(anyString(), anyString(), anyString());
		verify(mockedServicoSenhaBanco, never()).alterarSenha(anyString(), anyString(), anyString());
	}

	@Test
	public void modoBancoTrocaNoPostgres() throws Exception {
		when(mockedServicoDiretorioSenha.isDiretorioConfigurado()).thenReturn(false);
		when(mockedServicoSenhaBanco.isDisponivel()).thenReturn(true);
		assertTrue(systemUnderTest.alterarSenha("AGHU", "senhaAtual123", "senhaNova456"));
		verify(mockedServicoSenhaBanco).alterarSenha("AGHU", "senhaAtual123", "senhaNova456");
		verify(mockedServicoDiretorioSenha, never()).alterarSenha(anyString(), anyString(), anyString());
	}

	@Test
	public void modoBancoSenhaAtualInvalida() throws Exception {
		when(mockedServicoDiretorioSenha.isDiretorioConfigurado()).thenReturn(false);
		when(mockedServicoSenhaBanco.isDisponivel()).thenReturn(true);
		doThrow(new FalhaTrocaSenhaException(Motivo.CREDENCIAL_INVALIDA, "simulado", null))
				.when(mockedServicoSenhaBanco).alterarSenha(anyString(), anyString(), anyString());
		ApplicationBusinessException e = assertThrows(ApplicationBusinessException.class,
				() -> systemUnderTest.alterarSenha("AGHU", "errada", "senhaNova456"));
		assertEquals(UsuarioONExceptionCode.ERRO_AUTENTICACAO, e.getCode());
	}

	@Test
	public void modoLdapTemPrioridadeSobreBanco() throws Exception {
		when(mockedServicoDiretorioSenha.isDiretorioConfigurado()).thenReturn(true);
		systemUnderTest.alterarSenha("MSILVA", "senhaAtual123", "senhaNova456");
		verify(mockedServicoDiretorioSenha).alterarSenha("MSILVA", "senhaAtual123", "senhaNova456");
		verify(mockedServicoSenhaBanco, never()).alterarSenha(anyString(), anyString(), anyString());
	}

	@Test
	public void novaSenhaAbaixoDoTamanhoMinimo() throws Exception {
		when(mockedServicoDiretorioSenha.isDiretorioConfigurado()).thenReturn(true);
		ApplicationBusinessException e = assertThrows(ApplicationBusinessException.class,
				() -> systemUnderTest.alterarSenha("MSILVA", "senhaAtual123", "curta"));
		assertEquals(UsuarioONExceptionCode.CASCA_MENSAGEM_SENHA_TAMANHO_MINIMO, e.getCode());
		verify(mockedServicoDiretorioSenha, never()).alterarSenha(anyString(), anyString(), anyString());
	}

	@Test
	public void novaSenhaNula() {
		when(mockedServicoDiretorioSenha.isDiretorioConfigurado()).thenReturn(true);
		ApplicationBusinessException e = assertThrows(ApplicationBusinessException.class,
				() -> systemUnderTest.alterarSenha("MSILVA", "senhaAtual123", null));
		assertEquals(UsuarioONExceptionCode.CASCA_MENSAGEM_SENHA_TAMANHO_MINIMO, e.getCode());
	}

	private void falhaDoDiretorio(Motivo motivo, UsuarioONExceptionCode esperado) throws Exception {
		when(mockedServicoDiretorioSenha.isDiretorioConfigurado()).thenReturn(true);
		doThrow(new FalhaTrocaSenhaException(motivo, "simulado", null))
				.when(mockedServicoDiretorioSenha).alterarSenha(anyString(), anyString(), anyString());
		ApplicationBusinessException e = assertThrows(ApplicationBusinessException.class,
				() -> systemUnderTest.alterarSenha("MSILVA", "senhaAtual123", "senhaNova456"));
		assertEquals(esperado, e.getCode());
	}

	@Test
	public void senhaAtualInvalida() throws Exception {
		falhaDoDiretorio(Motivo.CREDENCIAL_INVALIDA, UsuarioONExceptionCode.ERRO_AUTENTICACAO);
	}

	@Test
	public void politicaDeSenhaDoDiretorio() throws Exception {
		falhaDoDiretorio(Motivo.POLITICA_SENHA, UsuarioONExceptionCode.CASCA_MENSAGEM_SENHA_POLITICA_DIRETORIO);
	}

	@Test
	public void diretorioNaoPermite() throws Exception {
		falhaDoDiretorio(Motivo.NAO_PERMITIDO, UsuarioONExceptionCode.CASCA_MENSAGEM_SENHA_DIRETORIO_NAO_PERMITE);
	}

	@Test
	public void erroDeComunicacaoComODiretorio() throws Exception {
		falhaDoDiretorio(Motivo.ERRO_DIRETORIO, UsuarioONExceptionCode.CASCA_MENSAGEM_SENHA_ERRO_DIRETORIO);
	}
}
