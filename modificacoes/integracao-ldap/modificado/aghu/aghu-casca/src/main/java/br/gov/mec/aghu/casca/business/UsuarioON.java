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

import java.util.ArrayList;
import java.util.Date;
import java.util.HashSet;
import java.util.List;
import java.util.Objects;
import java.util.Set;

import javax.annotation.Resource;
import javax.ejb.EJB;
import javax.ejb.Stateless;
import javax.inject.Inject;
import javax.persistence.PersistenceException;

import org.apache.commons.collections4.CollectionUtils;
import org.apache.commons.lang3.StringUtils;
import org.apache.commons.logging.Log;
import org.apache.commons.logging.LogFactory;
import org.hibernate.exception.ConstraintViolationException;
import org.infinispan.Cache;
import org.infinispan.commons.util.CloseableIteratorSet;

import br.gov.mec.aghu.casca.dao.AcessoDAO;
import br.gov.mec.aghu.casca.dao.CseControleExpiracaoDAO;
import br.gov.mec.aghu.casca.dao.DashboardDAO;
import br.gov.mec.aghu.casca.dao.PerfisUsuariosDAO;
import br.gov.mec.aghu.casca.dao.PerfisUsuariosJnDAO;
import br.gov.mec.aghu.casca.dao.SenhaDAO;
import br.gov.mec.aghu.casca.dao.UsuarioDAO;
import br.gov.mec.aghu.casca.dao.UsuarioJnDAO;
import br.gov.mec.aghu.casca.dao.UsuariosAcessoVpnDAO;
import br.gov.mec.aghu.casca.model.Dashboard;
import br.gov.mec.aghu.casca.model.Perfil;
import br.gov.mec.aghu.casca.model.PerfisUsuarios;
import br.gov.mec.aghu.casca.model.PerfisUsuariosJn;
import br.gov.mec.aghu.casca.model.Senha;
import br.gov.mec.aghu.casca.model.Usuario;
import br.gov.mec.aghu.casca.model.UsuarioJn;
import br.gov.mec.aghu.casca.vo.FiltroUsuarioJnVO;
import br.gov.mec.aghu.core.business.BaseBusiness;
import br.gov.mec.aghu.core.dominio.DominioOperacoesJournal;
import br.gov.mec.aghu.core.exception.ApplicationBusinessException;
import br.gov.mec.aghu.core.exception.BusinessExceptionCode;
import br.gov.mec.aghu.core.factory.BaseJournalFactory;
import br.gov.mec.aghu.core.utils.ElytronUtil;
import br.gov.mec.aghu.csc.ICscFacade;
import br.gov.mec.aghu.dao.ObjetosOracleDAO;
import br.gov.mec.aghu.dominio.DominioSimNao;
import br.gov.mec.aghu.enums.SituacaoExpiracaoUsuarioEnum;
import br.gov.mec.aghu.model.CseControleExpiracao;
import br.gov.mec.aghu.model.CseGrupoExpiracao;
import br.gov.mec.aghu.model.RapServidores;
import br.gov.mec.aghu.model.UsuariosAcessoVpn;
import br.gov.mec.aghu.registrocolaborador.business.IRegistroColaboradorFacade;
import br.gov.mec.aghu.registrocolaborador.business.IServidorLogadoFacade;
import br.gov.mec.aghu.registrocolaborador.dao.RapServidoresAuxiliarDAO;
import br.gov.mec.aghu.registrocolaborador.dao.StarhDAO;

/**
 * 
 * @author murillo.marinho
 * 
 */
@Stateless
public class UsuarioON extends BaseBusiness {

	private static final long serialVersionUID = -2096230202644314695L;

	@Resource(name = "java:jboss/infinispan/cache/aghu_container/permission_cache")
	private Cache<String, Boolean> permissionCache;

	@EJB
	private PerfilON perfilON;

	private static final Log LOG = LogFactory.getLog(UsuarioON.class);

	@EJB
	private IServidorLogadoFacade servidorLogadoFacade;

	@EJB
	private ICascaFacade cascaFacade;

	@Inject
	private UsuarioJnDAO usuarioJnDAO;

	@Inject
	private PerfisUsuariosJnDAO perfisUsuariosJnDAO;

	@Inject
	private UsuarioDAO usuarioDAO;

	@Inject
	private PerfisUsuariosDAO perfisUsuariosDAO;

	@Inject
	private AcessoDAO acessoDAO;

	@Inject
	private ObjetosOracleDAO objetosOracleDAO;
	
	@Inject
	private UsuariosAcessoVpnDAO usuariosAcessoVpnDAO;

	@Inject
	private SenhaDAO senhaDAO;

	@EJB
	private CseUsuarioRN cseUsuarioRN;
	
	@EJB
	private CsePerfilUsuarioRN csePerfilUsuarioRN;
	@EJB
	private ValidaCriacaoUsuarioAdeBancoDeDadosRN validaCriacaoUsuarioAdeBancoDeDadosRN;
	@EJB
	private CriacaoUsuarioDeBancoDeDadosRN criacaoUsuarioDeBancoDeDadosRN;
	@EJB
	private CriacaoUsuarioRedeADRN criacaoUsuarioRedeADRN;
	@EJB
	private IRegistroColaboradorFacade registroColaboradorFacade;
	@Inject
	private RapServidoresAuxiliarDAO rapServidoresAuxiliarDAO;
	@EJB
	private PerfilComprasRN perfilComprasRN;
	@Inject
	private DashboardDAO dashboardDAO;
	@Inject
	private CseControleExpiracaoDAO controleExpiracaoDAO;
	@EJB
	private PerfisAutomaticosRN perfisAutomaticosRN;
	@EJB
	private ICscFacade cscFacade;
	@EJB
	private AtribuicaoGruposAdRN atribuicaoGruposAdRN;
	@Inject
	private StarhDAO starhDAO;
	/** integracao-ldap: troca de senha no diretorio LDAP/AD (antes nao suportada). */
	@Inject
	private ServicoDiretorioSenha servicoDiretorioSenha;
	/** integracao-ldap: troca de senha no PostgreSQL quando o login e pelo modo "banco". */
	@Inject
	private ServicoSenhaBanco servicoSenhaBanco;
    
	protected enum UsuarioONExceptionCode implements BusinessExceptionCode {
		CASCA_MENSAGEM_USUARIO_NAO_INFORMADO, CASCA_MENSAGEM_LOGIN_EXISTENTE, CASCA_MENSAGEM_USUARIO_NAO_ENCONTRADO, CASCA_MENSAGEM_PARAMETROS_NAO_INFORMADO,
		CASCA_MENSAGEM_USUARIO_INATIVO, CASCA_MENSAGEM_USUARIO_SEM_PERFIL, CASCA_MENSAGEM_HORA_DIFERENTE, MSG_NAO_FOI_POSSIVEL_EXCLUIR_USUARIO, ERRO_AUTENTICACAO,
		CASCA_MENSAGEM_PERFIL_EXISTENTE, MSG_LOGIN_EXISTENTE, CASCA_USUARIO_NOME_EXISTENTE,
		// integracao-ldap: mensagens da troca de senha no diretorio
		CASCA_MENSAGEM_SENHA_DIRETORIO_INDISPONIVEL, CASCA_MENSAGEM_SENHA_TAMANHO_MINIMO, CASCA_MENSAGEM_SENHA_POLITICA_DIRETORIO,
		CASCA_MENSAGEM_SENHA_DIRETORIO_NAO_PERMITE, CASCA_MENSAGEM_SENHA_ERRO_DIRETORIO;
	}

	/** integracao-ldap: tamanho minimo da nova senha aceito pelo AGHUse (o diretorio pode exigir mais). */
	private static final int SENHA_TAMANHO_MINIMO = 8;

    public void imprimirUsuarioLogado(String usuarioSetado) {
    	RapServidores servidor = servidorLogadoFacade.obterServidorLogadoSemCache();
    	if (servidor != null) {
    		LOG.info("Obtendo do servidorLogadoFacaade = " + servidor.getCodigoVinculoNomeServidor());
        	LOG.info("Login = " + servidor.getUsuario());	
    	} else {
    		LOG.info("Nao achou RapServidor para login " + ElytronUtil.getPrincipalUsername());
    	}
    	LOG.info("O que foi setado: " + usuarioSetado);
    	
    	if (!Objects.equals(ElytronUtil.getPrincipalUsername(), usuarioSetado)) {
    		LOG.error("Usuarios diferentes: ElytronUtil = " + ElytronUtil.getPrincipalUsername() + ", usuarioSetado = " + usuarioSetado);	
    	}
    }
    
	public Object[] verificarSituacaoContaUsuario() {
		Object[] situacao = objetosOracleDAO.verificaSituacaoContaUsuario(super.obterLoginUsuarioLogado());
		if (situacao != null && situacao[0] != null) {
			return new Object[] { SituacaoExpiracaoUsuarioEnum.getInstance((String) situacao[0]), situacao[1] };
		}

		return null;
	}

	public void atualizarAvisoExpiracaoContaUsuario() {
		objetosOracleDAO.atualizarAvisoExpiracaoContaUsuario(super.obterLoginUsuarioLogado());
	}

	/**
	 * Metodo responsavel por incluir ou alterar um usuario.
	 * 
	 * @param usuarios
	 */
	public void salvarUsuario(Usuario usuario, String login) throws ApplicationBusinessException {
		Usuario usuarioCriacao = null;
		if (StringUtils.isNotBlank(login)) {
			usuarioCriacao = usuarioDAO.recuperarUsuario(login);
		}
		if (usuario == null) {
			throw new ApplicationBusinessException(UsuarioONExceptionCode.CASCA_MENSAGEM_USUARIO_NAO_INFORMADO);
		}
		// Verifica se o usuário possui um nome que já existe em outro usuário
		verificarUsuarioNomeExistente(usuario);

		if (usuario.getId() == null) { // inclusao
			if (isLoginExistente(null, usuario.getLogin())) {
				throw new ApplicationBusinessException(UsuarioONExceptionCode.MSG_LOGIN_EXISTENTE, usuario.getLogin(), usuario.getLogin());
			}
			usuario.setDataCriacao(new Date());
			usuario.setLogin(usuario.getLogin().toUpperCase());
			usuario.setUsuario(usuarioCriacao);
			validaCriacaoUsuarioAdeBancoDeDadosRN.validaHistoricoUsuario(usuario);/// RN01 #141175
			criacaoUsuarioRedeADRN.validacaoUsuarioRede(usuario);
			validaCriacaoUsuarioAdeBancoDeDadosRN.realizaValidacoesNaCriacaoDeUsuarioBD(usuario);// RN02 #141175
			obterTratamentoCamposNovosObrigatoriosValorDefault(usuario);
			usuarioDAO.persistir(usuario);
			// cria a journal
			UsuarioJn usuarioJn = this.criarJournal(usuario, DominioOperacoesJournal.INS);
			// persiste a journal
			usuarioJnDAO.persistir(usuarioJn);
			if (usuario.getServidor() != null) {// #141188
				RapServidores servidores = rapServidoresAuxiliarDAO.obterServidorDados(usuario.getServidor().getId());
				servidores.setUsuario(usuario.getLogin());
				rapServidoresAuxiliarDAO.merge(servidores);
				registroColaboradorFacade.atualizarJournal(servidores);
			}

			if (usuarioDAO.isHCPA()) {
				criacaoUsuarioDeBancoDeDadosRN.efetuaCriacaoUsuarioBancoDeDados(usuario);// RN05,RN07(Em caso de falha) #141175
				criacaoUsuarioDeBancoDeDadosRN.efetuaLiberacaoUsuarioBancoDeDadosGRANT(usuario);// RN06,RN07(Em caso de falha) #141175
				cseUsuarioRN.realizaReplicaoCseUsuario(usuario, DominioOperacoesJournal.INS);
				criacaoUsuarioRedeADRN.criaUsuarioAD(usuario);// estória - Criação de usuário no AD P1 #141175
			}
			// #141207
			atribuicaoGruposAdRN.inserirGrupoAdGenericos(usuario.getLogin(), Boolean.FALSE);// RN01

			if (usuario.getServidor() != null) {
				// #141200
				perfisAutomaticosRN.fornecerPerfis(usuario.getServidor().getId().getMatricula(), usuario.getServidor().getId().getVinCodigo(), null, null);

				// 156777
				starhDAO.atualizarEmailPessoaFisicaStarh(usuario.getServidor().getPessoaFisica().getCodigo(), usuario.getEmail());
			}
			// #141207
			atribuicaoGruposAdRN.inserirGrupoAdPerfis(null, null, usuario);// RN02
		} else { // alteracao
			if (isLoginExistente(usuario.getId(), usuario.getLogin())) {
				throw new ApplicationBusinessException(UsuarioONExceptionCode.CASCA_MENSAGEM_LOGIN_EXISTENTE);
			}
			// cria a journal
			Usuario usuarioOld = usuarioDAO.obterOriginal(usuario);
			UsuarioJn usuarioJn = this.criarJournal(usuarioOld, DominioOperacoesJournal.UPD);
			usuarioDAO.merge(usuario);
			// persiste a journal
			usuarioJnDAO.persistir(usuarioJn);
			if (usuarioDAO.isHCPA()) {
				cseUsuarioRN.realizaReplicaoCseUsuario(usuario, DominioOperacoesJournal.UPD);
			}
			// 170401
			if (usuarioOld.isDelegarPerfil() && !usuario.isDelegarPerfil()) {
				this.cascaFacade.excluirPerfisDelegadoresUsuario(usuario.getId());
			}
		}
		usuarioDAO.flush();
	}

	public void reversaoCriacaoNovoUsuario(Usuario usuario) throws ApplicationBusinessException {// Reverte toda a criação de usuário que houver falha
		if (usuarioDAO.isHCPA()) {
			boolean existeUsuarioRede = cscFacade.verificarUsuarioAd(usuario.getLogin());
			if (existeUsuarioRede) {
				cscFacade.removerUsuarioAd(usuario.getLogin());// Remove usuário do active directory
			}
			if (usuarioDAO.isOracle()) {// Remove usuário de banco de dados
				boolean isExiste = cscFacade.verificarUsuarioBd(usuario.getLogin());
				if (isExiste) {
					cscFacade.removerUsuarioBd(usuario.getLogin());
				}
			}
		}
		if (usuario.getServidor() != null) {// retira o login da rap_servidores
			RapServidores servidores = rapServidoresAuxiliarDAO.obterServidorDados(usuario.getServidor().getId());
			if (StringUtils.isNotBlank(servidores.getUsuario())) {
				servidores.setUsuario(null);
				rapServidoresAuxiliarDAO.merge(servidores);
				registroColaboradorFacade.atualizarJournal(servidores);
			}
		}
	}

	private void obterTratamentoCamposNovosObrigatoriosValorDefault(Usuario usuario) {
		if (usuario.getConsisteRede() == null) {
			usuario.setConsisteRede(Boolean.TRUE);
		}
		if (usuario.getCriaUserRede() == null) {
			usuario.setCriaUserRede(Boolean.TRUE);
		}
		if (usuario.getIndMultiploLogon() == null) {
			usuario.setIndMultiploLogon(Boolean.FALSE);
		}
		if (usuario.getGrupoExpiracao() == null) {
			CseGrupoExpiracao grupo = new CseGrupoExpiracao();
			grupo.setSeq(Short.valueOf("1"));
			usuario.setGrupoExpiracao(grupo);
		}
	}

	/**
	 * Verifica se já existe um usuário cadastrado com o nome
	 * 
	 * @param usuario
	 * @throws CascaException
	 */
	private void verificarUsuarioNomeExistente(Usuario usuario) throws ApplicationBusinessException {
		List<Usuario> listaUsuarios = usuarioDAO.pesquisarUsuarioMesmoLogin(usuario.getId(), usuario.getLogin());
		if (!listaUsuarios.isEmpty()) {
			throw new ApplicationBusinessException(UsuarioONExceptionCode.CASCA_USUARIO_NOME_EXISTENTE);
		}

	}

	/**
	 * Metodo responsavel por pesquisar usuarios.
	 * 
	 * @param nomeUsuario
	 * @param login
	 * @return
	 */
	public List<Usuario> pesquisarUsuarios(Integer firstResult, Integer maxResult, String orderProperty, boolean asc, String nomeOuLogin) throws ApplicationBusinessException {
		return usuarioDAO.pesquisarUsuarios(firstResult, maxResult, orderProperty, asc, nomeOuLogin);
	}

	/**
	 * Recupera a quantidade de registros encontrados.
	 * 
	 * @param nomeUsuario
	 * @param login
	 * @return
	 * @throws ApplicationBusinessException
	 */
	public Long pesquisarUsuariosCount(String nomeOuLogin) {
		return usuarioDAO.pesquisarUsuariosCount(nomeOuLogin);
	}

	/**
	 * Busca o histórico do cadastro do usuário
	 * 
	 * @param firstResult
	 * @param maxResult
	 * @param orderProperty
	 * @param asc
	 * @param filtroUsuarioJnVO
	 * @return
	 */
	public List<UsuarioJn> pesquisarHistoricoPorUsuario(Integer firstResult, Integer maxResult, String orderProperty, boolean asc, FiltroUsuarioJnVO filtroUsuarioJnVO) {
		if (orderProperty == null) {
			orderProperty = UsuarioJn.Fields.SEQ_JN.toString();
			asc = false;
		}
		return usuarioJnDAO.pesquisarPorUsuario(firstResult, maxResult, orderProperty, asc, filtroUsuarioJnVO);
	}

	/**
	 * Quantidade de registros no histórico do cadastro do usuário
	 * 
	 * @param filtroUsuarioJnVO
	 * @return
	 */
	public Long pesquisarHistoricoPorUsuarioCount(FiltroUsuarioJnVO filtroUsuarioJnVO) {
		return usuarioJnDAO.pesquisarPorUsuarioCount(filtroUsuarioJnVO);
	}

	public Usuario obterUsuarioAtivo(String login) throws ApplicationBusinessException {
		Usuario usuario = obterUsuario(login);
		Usuario retorno = null;

		if (usuario != null && usuario.isAtivo()) {
			retorno = usuario;
		}

		return retorno;
	}

	/**
	 * 
	 * @param id
	 * @return
	 */
	public Usuario obterUsuario(Integer id) throws ApplicationBusinessException {
		if (id == null) {
			throw new ApplicationBusinessException(UsuarioONExceptionCode.CASCA_MENSAGEM_PARAMETROS_NAO_INFORMADO);
		}

		Usuario usuario = usuarioDAO.obterPorChavePrimaria(id);
		usuarioDAO.refresh(usuario);
		if (usuario == null) {
			throw new ApplicationBusinessException(UsuarioONExceptionCode.CASCA_MENSAGEM_USUARIO_NAO_ENCONTRADO);
		}
		return usuario;
	}

	/**
	 * Obter usuário pelo login
	 * 
	 * @param login
	 * @return usuário
	 * @throws ApplicationBusinessException
	 */
	public Usuario obterUsuario(String login) {
		return obterUsuario(login, true);
	}

	public Usuario obterUsuario(String login, boolean ignorarCaixa) {
		if (login == null) {
			return null;
		}
		return usuarioDAO.recuperarUsuario(login);
	}

	public boolean isServidorAtivo(Integer idUsuario) {
		boolean situacaoAtivo = rapServidoresAuxiliarDAO.buscarServidorAtivoPorUsuario(idUsuario);
		return situacaoAtivo;
	}

	public void associarPerfilUsuario(Integer idUsuario, List<PerfisUsuarios> listaPerfisUsuarios) throws ApplicationBusinessException {

		if (idUsuario == null) {
			throw new ApplicationBusinessException(UsuarioONExceptionCode.CASCA_MENSAGEM_PARAMETROS_NAO_INFORMADO);
		}

		Usuario usuario = usuarioDAO.obterOriginal(idUsuario);

		List<PerfisUsuarios> perfisUsuariosAtual = perfisUsuariosDAO.pequisarPerfisUsuarios(usuario);

		for (PerfisUsuarios perfilUsuario : perfisUsuariosAtual) {
			if (!listaPerfisUsuarios.contains(perfilUsuario)) {
				this.removerPerfisUsuario(perfilUsuario);
				csePerfilUsuarioRN.realizaIntegracaoCsePerfilUsuario(perfilUsuario, DominioOperacoesJournal.DEL);
				perfilComprasRN.revogarRegistroScoPontosServidores(perfilUsuario.getPerfil().getId(), usuario, usuario.getServidor() != null);
				criacaoUsuarioDeBancoDeDadosRN.revokeGrantPerfilBancoDeDados(perfilUsuario.getPerfil().getId(), perfilUsuario.getPerfil().getNome(), usuario);
			}
		}
		perfisUsuariosAtual = perfisUsuariosDAO.pequisarPerfisUsuarios(usuario);

		for (PerfisUsuarios perfilUsuario : listaPerfisUsuarios) {
			if (!perfisUsuariosAtual.contains(perfilUsuario)) {
				perfilUsuario.setDataCriacao(new Date());
				this.associaPerfisUsuarios(usuario, perfilUsuario);
				csePerfilUsuarioRN.realizaIntegracaoCsePerfilUsuario(perfilUsuario, DominioOperacoesJournal.INS);
				perfilComprasRN.liberarOperacoesModuloCompras(perfilUsuario.getPerfil().getId(), usuario, usuario.getServidor() != null, perfilUsuario.getPerfil().getNome());
				criacaoUsuarioDeBancoDeDadosRN.forneceGrantPerfilBancoDeDados(perfilUsuario.getPerfil().getId(), perfilUsuario.getPerfil().getNome(), usuario);
			}
		}
		if (usuario.getServidor() != null) {
			// #141200
			perfisAutomaticosRN.revogarPerfis(usuario.getServidor().getId().getMatricula(), usuario.getServidor().getId().getVinCodigo(), null, null);
			perfisAutomaticosRN.fornecerPerfis(usuario.getServidor().getId().getMatricula(), usuario.getServidor().getId().getVinCodigo(), null, null);
			// #141207
			atribuicaoGruposAdRN.inserirGrupoAdPerfis(usuario.getServidor().getId().getMatricula(), usuario.getServidor().getId().getVinCodigo(), null);// RN02
		}
		try {
			perfisUsuariosDAO.flush();
		} catch (Exception e) {
			if (e instanceof PersistenceException && e.getCause() instanceof ConstraintViolationException) {
				throw new ApplicationBusinessException(UsuarioONExceptionCode.CASCA_MENSAGEM_PERFIL_EXISTENTE);
			}
		}
	}

	public void associarPerfilUsuarioPatologista(Integer idUsuario, List<PerfisUsuarios> listaPerfis, List<Perfil> perfisPatologista) throws ApplicationBusinessException {

		if (idUsuario == null) {
			throw new ApplicationBusinessException(UsuarioONExceptionCode.CASCA_MENSAGEM_PARAMETROS_NAO_INFORMADO);
		}

		Usuario usuario = usuarioDAO.obterPorChavePrimaria(idUsuario);

		Set<PerfisUsuarios> perfisUsuariosAtual = usuario.getPerfisUsuario();
		List<PerfisUsuarios> perfisUsuariosAtualRemover = new ArrayList<PerfisUsuarios>(0);

		// LISTA PERFIS DA NOVA FUNÇÃO
		List<Perfil> perfisInserir = new ArrayList<Perfil>(0);
		for (PerfisUsuarios perfisUsuarios : listaPerfis) {
			perfisInserir.add(perfisUsuarios.getPerfil());
		}

		// LISTA PERFIS DA ANTIGA FUNÇÃO
		List<Perfil> perfisAtuais = new ArrayList<Perfil>(0);
		for (PerfisUsuarios perfisUsuarios : perfisUsuariosAtual) {
			perfisAtuais.add(perfisUsuarios.getPerfil());
		}

		// FILTRA PARA REMOVER APENAS PERFIS DE PATOLOGISTA NÃO REFERENTES A FUNÇÃO NOVA
		for (PerfisUsuarios perfisUsuariosA : perfisUsuariosAtual) {
			if (perfisPatologista.contains(perfisUsuariosA.getPerfil()) && !perfisInserir.contains(perfisUsuariosA.getPerfil())) {
				perfisUsuariosAtualRemover.add(perfisUsuariosA);
			}
		}

		// REMOVE PERFIS DE PATOLOGISTA REFERENTES A ANTIGA FUNÇÃO
		Set<PerfisUsuarios> perfisUsuariosRemover = new HashSet<PerfisUsuarios>();
		for (PerfisUsuarios perfilUsuario : perfisUsuariosAtualRemover) {
			perfisUsuariosRemover.add(perfilUsuario);
			this.removerPerfisUsuario(perfilUsuario);
		}
		// INSERE PERFIS REFERENTES A NOVA FUNÇÃO
		for (PerfisUsuarios perfilUsuario : listaPerfis) {
			if (!perfisAtuais.contains(perfilUsuario.getPerfil())) {
				this.associaPerfisUsuarios(usuario, perfilUsuario);
			}
		}
		perfisUsuariosAtual.removeAll(perfisUsuariosRemover);
	}

	/**
	 * 
	 * @param login
	 * @param perfilNome
	 * @throws CascaException
	 */
	public void atribuirPerfilUsuario(String login, String perfilNome, String usuarioLogado) throws ApplicationBusinessException {

		Usuario usuario = cascaFacade.obterUsuarioAtivo(login);
		Perfil perfil = cascaFacade.pesquisarPerfis(perfilNome).get(0);

		if (login == null || perfil == null) {
			throw new ApplicationBusinessException(UsuarioONExceptionCode.CASCA_MENSAGEM_PARAMETROS_NAO_INFORMADO);
		}

		PerfisUsuarios perfilUsuarioPossui = cascaFacade.obterPerfilUsuarioLogin(login, perfilNome);

		if (perfilUsuarioPossui == null) {
			PerfisUsuarios perfilUsuario = new PerfisUsuarios();
			perfilUsuario.setDataCriacao(new Date());
			perfilUsuario.setUsuario(usuario);
			perfilUsuario.setPerfil(perfil);
			this.associaPerfisUsuarios(usuario, perfilUsuario);
		}

	}

	/**
	 * 
	 * @param login
	 * @param perfilNome
	 * @throws CascaException
	 */
	public void removerPerfilUsuario(String login, String perfil, String usuarioLogado) throws ApplicationBusinessException {

		if (login.isEmpty() || perfil.isEmpty()) {
			throw new ApplicationBusinessException(UsuarioONExceptionCode.CASCA_MENSAGEM_PARAMETROS_NAO_INFORMADO);
		}

		PerfisUsuarios perfilUsuarioPossui = cascaFacade.obterPerfilUsuarioLogin(login, perfil);

		if (perfilUsuarioPossui != null) {
			this.removerPerfisUsuario(perfilUsuarioPossui);
		}

	}

	public void associaPerfisUsuarios(Usuario usuario, PerfisUsuarios perfilUsuario) throws ApplicationBusinessException {
		perfisUsuariosDAO.persistir(perfilUsuario);

		// cria a journal
		PerfisUsuariosJn perfisUsuariosJn = this.criarJournal(perfilUsuario, DominioOperacoesJournal.INS);

		// persiste a journal
		perfisUsuariosJnDAO.persistir(perfisUsuariosJn);
	}

	public void removerPerfisUsuario(PerfisUsuarios perfilUsuario) throws ApplicationBusinessException {
		PerfisUsuariosJn perfisUsuariosJn = this.criarJournal(perfilUsuario, DominioOperacoesJournal.DEL);
		perfisUsuariosDAO.removerPorId(perfilUsuario.getId());

		// persiste a journal
		perfisUsuariosJnDAO.persistir(perfisUsuariosJn);
	}

	public void excluirUsuarioManter(Integer idUsuario) throws ApplicationBusinessException {
		if (idUsuario == null) {
			throw new ApplicationBusinessException(UsuarioONExceptionCode.CASCA_MENSAGEM_PARAMETROS_NAO_INFORMADO);
		}

		Usuario usuario = obterUsuario(idUsuario);

		if (usuario == null) {
			throw new ApplicationBusinessException(UsuarioONExceptionCode.CASCA_MENSAGEM_USUARIO_NAO_ENCONTRADO);
		}
		// cria a journal
		UsuarioJn usuarioJn = this.criarJournal(usuario, DominioOperacoesJournal.DEL);
		acessoDAO.removerAcessos(usuario);
		usuarioDAO.remover(usuario);
		usuarioJnDAO.persistir(usuarioJn);
	}

	/**
	 * Metodo responsavel por excluir um usuario.
	 */
	public void excluirUsuario(Integer idUsuario, String paramPermiteExcluir) throws ApplicationBusinessException {
		Usuario usuario = obterUsuario(idUsuario);
		if (DominioSimNao.S.toString().equals(paramPermiteExcluir)) {
			realizaExclusaoUsuario(usuario, true);
		}
		if (DominioSimNao.N.toString().equals(paramPermiteExcluir)) {
			Long countAcesso = acessoDAO.obterAcessoC10(idUsuario);
			if (countAcesso == 0) {
				realizaExclusaoUsuario(usuario, false);
			} else {
				throw new ApplicationBusinessException(UsuarioONExceptionCode.MSG_NAO_FOI_POSSIVEL_EXCLUIR_USUARIO, usuario.getLogin());
			}
		}
	}

	private void realizaExclusaoUsuario(Usuario usuario, boolean isRemoveAcesso) throws ApplicationBusinessException {
		List<PerfisUsuarios> perfisUsuariosAtual = perfisUsuariosDAO.pequisarPerfisUsuarios(usuario);
		for (PerfisUsuarios perfilUsuario : perfisUsuariosAtual) {
			this.removerPerfisUsuario(perfilUsuario);
			csePerfilUsuarioRN.realizaIntegracaoCsePerfilUsuario(perfilUsuario, DominioOperacoesJournal.DEL);
			perfilComprasRN.revogarRegistroScoPontosServidores(perfilUsuario.getPerfil().getId(), usuario, usuario.getServidor() != null);
			criacaoUsuarioDeBancoDeDadosRN.revokeGrantPerfilBancoDeDados(perfilUsuario.getPerfil().getId(), perfilUsuario.getPerfil().getNome(), usuario);
		}
		List<Dashboard> dashboards = dashboardDAO.obterDashPorUsuarioId(usuario.getId());
		if (CollectionUtils.isNotEmpty(dashboards)) {
			for (Dashboard dash : dashboards) {
				dashboardDAO.remover(dash);
				dashboardDAO.flush();
			}
		}
		List<CseControleExpiracao> listaControlesExpiracao = controleExpiracaoDAO.obterControleExpiracaoPorLogin(usuario.getLogin());
		if (CollectionUtils.isNotEmpty(listaControlesExpiracao)) {
			for (CseControleExpiracao controle : listaControlesExpiracao) {
				controleExpiracaoDAO.remover(controle);
				controleExpiracaoDAO.flush();
			}
		}

		if (usuarioDAO.isHCPA()) {
			cseUsuarioRN.realizaReplicaoCseUsuario(usuario, DominioOperacoesJournal.DEL);
		}
		
		List<UsuariosAcessoVpn> usuariosVpn = usuariosAcessoVpnDAO.obterUsuariosAcessoVpnPorUsuario(usuario.getLogin());
		if (CollectionUtils.isNotEmpty(usuariosVpn)) {
			for (UsuariosAcessoVpn usuarioVpn : usuariosVpn) {
				usuariosAcessoVpnDAO.remover(usuarioVpn);
				usuariosAcessoVpnDAO.flush();
			}
		}
		// cria a journal
		UsuarioJn usuarioJn = this.criarJournal(usuario, DominioOperacoesJournal.DEL);
		if (isRemoveAcesso) {
			acessoDAO.removerAcessos(usuario);
		}
		atualizarServidorExclusaoUsuario(usuario);
		usuarioDAO.remover(usuario);
		usuarioJnDAO.persistir(usuarioJn);
		criacaoUsuarioDeBancoDeDadosRN.removerUsuarioBD(usuario.getLogin());
		criacaoUsuarioRedeADRN.excluirUsuarioRede(usuario.getLogin());
	}

	private void atualizarServidorExclusaoUsuario(Usuario usuario) {
		if (usuario != null && usuario.getServidor() != null) {
			RapServidores servidores = rapServidoresAuxiliarDAO.obterServidorDados(usuario.getServidor().getId());
			servidores.setUsuario(null);
			rapServidoresAuxiliarDAO.merge(servidores);
		}
	}

	/**
	 * Cria uma entidade journal da Usuario
	 * 
	 * @param usuario
	 * @param operacao
	 * @return
	 * @throws ApplicationBusinessException
	 */
	public UsuarioJn criarJournal(Usuario usuario, DominioOperacoesJournal operacao) throws ApplicationBusinessException {
		RapServidores servidorLogado = servidorLogadoFacade.obterServidorLogado();

		UsuarioJn usuarioJn = BaseJournalFactory.getBaseJournal(operacao, UsuarioJn.class, servidorLogado.getUsuario());
		usuarioJn.setId(usuario.getId());
		usuarioJn.setNome(usuario.getNome());
		usuarioJn.setLogin(usuario.getLogin());
		usuarioJn.setEmail(usuario.getEmail());
		usuarioJn.setAtivo(usuario.isAtivo());
		usuarioJn.setDelegarPerfil(usuario.isDelegarPerfil());
		usuarioJn.setTempoSessaoMinutos(usuario.getTempoSessaoMinutos());
		usuarioJn.setQtdMaxSessao(usuario.getQtdMaxSessao());
		usuarioJn.setServidor(usuario.getServidor());
		usuarioJn.setTipoUsuario(usuario.getTipoUsuario());
		usuarioJn.setGrupoExpiracao(usuario.getGrupoExpiracao());
		usuarioJn.setIndMultiploLogon(usuario.getIndMultiploLogon());
		usuarioJn.setSenhaInicial(usuario.getSenhaInicial());
		usuarioJn.setCriaUserRede(usuario.getCriaUserRede());
		usuarioJn.setConsisteRede(usuario.getConsisteRede());
		usuarioJn.setAssinadoEm(usuario.getAssinadoEm());
		usuarioJn.setTrocaSenhaEm(usuario.getTrocaSenhaEm());
		usuarioJn.setExpiradoEm(usuario.getExpiradoEm());
		return usuarioJn;
	}

	public void atualizarUsuarioJn(Usuario usuarioOld, DominioOperacoesJournal operacao) throws ApplicationBusinessException {
		UsuarioJn usuarioJn = this.criarJournal(usuarioOld, operacao);
		usuarioJnDAO.persistir(usuarioJn);
		usuarioJnDAO.flush();
	}

	public void atualizarUsuarioViaRotinaMigracaoMatricula(Usuario usuario) throws ApplicationBusinessException {
		if (isLoginExistente(usuario.getId(), usuario.getLogin())) {
			throw new ApplicationBusinessException(UsuarioONExceptionCode.CASCA_MENSAGEM_LOGIN_EXISTENTE);
		}
		usuarioDAO.merge(usuario);
		if (usuarioDAO.isHCPA()) {
			cseUsuarioRN.realizaReplicaoCseUsuario(usuario, DominioOperacoesJournal.UPD);
		}
	}

	/**
	 * Cria uma entidade joural da PerfisUsuarios
	 * 
	 * @param perfisUsuarios
	 * @param operacao
	 * @return
	 * @throws ApplicationBusinessException
	 */
	private PerfisUsuariosJn criarJournal(PerfisUsuarios perfisUsuarios, DominioOperacoesJournal operacao) throws ApplicationBusinessException {
		RapServidores servidorLogado = servidorLogadoFacade.obterServidorLogado();

		PerfisUsuariosJn perfisUsuariosJn = BaseJournalFactory.getBaseJournal(operacao, PerfisUsuariosJn.class, servidorLogado.getUsuario());
		perfisUsuariosJn.setId(perfisUsuarios.getId());
		perfisUsuariosJn.setIdUsuario(perfisUsuarios.getUsuario().getId());
		perfisUsuariosJn.setLogin(perfisUsuarios.getUsuario().getLogin());
		perfisUsuariosJn.setIdPerfil(perfisUsuarios.getPerfil().getId());
		perfisUsuariosJn.setNomePerfil(perfisUsuarios.getPerfil().getNome());
		perfisUsuariosJn.setDataExpiracao(perfisUsuarios.getDataExpiracao());
		perfisUsuariosJn.setValidoAte(perfisUsuarios.getValidoAte());
		perfisUsuariosJn.setMotivoDelegacao(perfisUsuarios.getMotivoDelegacao());
		perfisUsuariosJn.setEmpId(super.getCodEmpresa());
		return perfisUsuariosJn;
	}

	/**
	 * Altera a senha do usuario no diretorio LDAP / Active Directory.
	 *
	 * integracao-ldap: no AGHUse 13.250 original este metodo lancava UnsupportedOperationException e a
	 * tela "Trocar Senha" nao funcionava. Agora a troca e feita autenticando como o proprio usuario:
	 * - login por LDAP/AD: no diretorio (ServicoDiretorioSenha);
	 * - login pelo PostgreSQL (modo "banco"): na role do PostgreSQL (ServicoSenhaBanco).
	 */
	public boolean alterarSenha(String login, String senhaAtual, String senhaNova) throws ApplicationBusinessException {
		boolean ldap = servicoDiretorioSenha.isDiretorioConfigurado();
		if (!ldap && !servicoSenhaBanco.isDisponivel()) {
			throw new ApplicationBusinessException(UsuarioONExceptionCode.CASCA_MENSAGEM_SENHA_DIRETORIO_INDISPONIVEL);
		}
		if (senhaNova == null || senhaNova.length() < SENHA_TAMANHO_MINIMO) {
			throw new ApplicationBusinessException(UsuarioONExceptionCode.CASCA_MENSAGEM_SENHA_TAMANHO_MINIMO, SENHA_TAMANHO_MINIMO);
		}
		try {
			if (ldap) {
				servicoDiretorioSenha.alterarSenha(login, senhaAtual, senhaNova);
			} else {
				servicoSenhaBanco.alterarSenha(login, senhaAtual, senhaNova);
			}
			return true;
		} catch (ServicoDiretorioSenha.FalhaTrocaSenhaException e) {
			LOG.warn("Troca de senha de " + login + " recusada (" + e.getMotivo() + "): " + e.getMessage());
			switch (e.getMotivo()) {
			case CREDENCIAL_INVALIDA:
				throw new ApplicationBusinessException(UsuarioONExceptionCode.ERRO_AUTENTICACAO);
			case POLITICA_SENHA:
				throw new ApplicationBusinessException(UsuarioONExceptionCode.CASCA_MENSAGEM_SENHA_POLITICA_DIRETORIO);
			case NAO_PERMITIDO:
				throw new ApplicationBusinessException(UsuarioONExceptionCode.CASCA_MENSAGEM_SENHA_DIRETORIO_NAO_PERMITE);
			default:
				throw new ApplicationBusinessException(UsuarioONExceptionCode.CASCA_MENSAGEM_SENHA_ERRO_DIRETORIO);
			}
		}
	}

	/**
	 * 
	 * @param idUsuario
	 * @param login
	 * @return
	 * @throws ApplicationBusinessException
	 */
	private boolean isLoginExistente(Integer idUsuario, String login) throws ApplicationBusinessException {
		Usuario usuario = usuarioDAO.recuperarUsuario(login);
		// validacao para edicao
		if (usuario != null && idUsuario != null) {
			if (usuario.getId().equals(idUsuario)) {
				return false;
			}
			return true;
		}
		return usuario == null ? false : true;
	}

	/**
	 * Pesquisa, e retorna, todos os usuários com uma determinada permissão
	 * 
	 * @param permissao Nome da permissão
	 * @return Lista de usuários, ordenada por login, que possuem a permissão. Caso
	 *         a permissão não seja informada, retorna uma lista vazia.
	 */
	public List<String> pesquisarUsuariosComPermissao(String permissao) {
		if (permissao == null || permissao.isEmpty()) {
			return new ArrayList<String>();
		}
		return usuarioDAO.pesquisarUsuariosComPermissao(permissao);
	}

	public void validarLogin(String login) throws ApplicationBusinessException {
		this.validarUsuarioAtivo(login);
	}

	/**
	 * Valida se o usuário existe e se está ativo. Logica de negocio duplicado no
	 * AghuBaseLoginModule.
	 * 
	 * @param login Login do usuário no sistema AGHU
	 * @throws ApplicationBusinessException Caso não exista ou esteja ativo
	 */
	public void validarUsuarioAtivo(final String login) throws ApplicationBusinessException {
		Usuario usuario = obterUsuario(login);
		if (usuario == null) {
			LOG.warn("Este usuário não foi encontrado no sistema: " + login);
			throw new ApplicationBusinessException(UsuarioONExceptionCode.CASCA_MENSAGEM_USUARIO_NAO_ENCONTRADO);
		}

		if (!usuario.isAtivo()) {
			LOG.warn("Este usuário está inativo no sistema: " + login);
			throw new ApplicationBusinessException(UsuarioONExceptionCode.CASCA_MENSAGEM_USUARIO_INATIVO);
		}

		if (perfilON.pesquisarPerfisAtivosDoUsuarioCount(usuario) == 0) {
			LOG.warn("Usuário [" + login + "] não tem perfil associado ou todos seus perfis estão inativos.");
			throw new ApplicationBusinessException(UsuarioONExceptionCode.CASCA_MENSAGEM_USUARIO_SEM_PERFIL);
		}
	}

	public Set<String> pesquisarUsuariosPorPerfil(String perfil) {
		Set<String> result = new HashSet<String>();
		if (perfil != null && !perfil.isEmpty()) {
			List<String> usuarios = usuarioDAO.pesquisarUsuariosPorPerfil(perfil);
			if (usuarios != null) {
				result.addAll(usuarios);
			}
		}
		return result;
	}

	public void clearCachePermissoes(Usuario usuario, Boolean isMobile) {
		String username = !isMobile ? usuario.getLogin() : usuario.getLogin().toLowerCase();
		CloseableIteratorSet<String> keys = permissionCache.keySet();
		for (String key : keys) {
			if (key.startsWith(username)) {
				permissionCache.remove(key);
			}
		}
	}

	public void validarSenha(String login, String senhaAtual) throws ApplicationBusinessException {
		if (!ElytronUtil.authenticate(login, senhaAtual.toCharArray())) {
			throw new ApplicationBusinessException(UsuarioONExceptionCode.ERRO_AUTENTICACAO);
		}
	}

	// #74566
	public void salvarUsuarioManter(Usuario usuario) throws ApplicationBusinessException {

		if (usuario == null) {
			throw new ApplicationBusinessException(UsuarioONExceptionCode.CASCA_MENSAGEM_USUARIO_NAO_INFORMADO);
		}

		// Verifica se o usuário possui um nome que já existe em outro usuário
		verificarUsuarioNomeExistente(usuario);

		if (usuario.getId() == null) { // inclusao
			if (isLoginExistente(null, usuario.getLogin())) {
				throw new ApplicationBusinessException(UsuarioONExceptionCode.CASCA_MENSAGEM_LOGIN_EXISTENTE);
			}
			usuario.setDataCriacao(new Date());
			usuarioDAO.persistir(usuario);
		}
		usuarioDAO.flush();
	}

	public void salvarSenha(Senha senha) throws ApplicationBusinessException {
		senhaDAO.merge(senha);
		senhaDAO.flush();
	}
}
