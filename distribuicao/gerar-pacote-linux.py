#!/usr/bin/env python3
"""Gera o pacote Linux (.tar.gz) do instalador AGHUse: original ou variante.

Uso (na raiz do repositorio do instalador):
    python3 distribuicao/gerar-pacote-linux.py <saida.tar.gz>
    python3 distribuicao/gerar-pacote-linux.py <saida.tar.gz> --variante <pasta-da-variante>

O pacote contem SOMENTE o necessario para instalar no Linux (lista INCLUIR abaixo), tirado dos
arquivos versionados no git, com os scripts .sh executaveis, dentro da pasta "aghuse/".
Ficam de fora o instalador do Windows (windows/), as ferramentas de geracao (distribuicao/),
o codigo-fonte/patch/testes das modificacoes e as notas tecnicas: eles ficam no repositorio.

Com --variante: a pasta deve conter o aghu.ear modificado e o arquivo VARIANTE. O aghu.ear e
dividido em partes de 95 MB (pacote/aghu.ear.parte-NNN, como no original), o pacote/SHA256SUMS
e atualizado e o arquivo VARIANTE vai para a raiz do pacote, onde o instalar.sh e o
instalar-assistente.sh o reconhecem. Ver modificacoes/integracao-ldap/README.md.
"""
import hashlib
import io
import os
import re
import subprocess
import sys
import tarfile
import time

PARTE = 95 * 1024 * 1024

# O que vai no pacote Linux (arquivos na raiz e pastas inteiras)
INCLUIR_RAIZ = {"instalar.sh", "instalar-assistente.sh", "usuario.sh", "verificar.sh",
                "aghuse.conf", "README.md", "LICENSE"}
INCLUIR_PREFIXOS = ("lib/", "pacote/", "dependencias/")
INCLUIR_ARQUIVOS = {"docs/CADASTRO_DE_USUARIOS.md"}
# so nos pacotes "variante": o resumo do que mudou (o codigo-fonte fica no repositorio)
INCLUIR_VARIANTE = {"modificacoes/integracao-ldap/README.md", "modificacoes/integracao-ldap/tela-trocar-senha.png"}


def incluir(a, variante):
    return (a in INCLUIR_RAIZ or a.startswith(INCLUIR_PREFIXOS) or a in INCLUIR_ARQUIVOS
            or (variante and a in INCLUIR_VARIANTE))


def sha256(caminho):
    h = hashlib.sha256()
    with open(caminho, "rb") as f:
        for bloco in iter(lambda: f.read(1 << 20), b""):
            h.update(bloco)
    return h.hexdigest()


def adicionar_bytes(tar, nome, dados, modo=0o644):
    ti = tarfile.TarInfo("aghuse/" + nome)
    ti.size, ti.mode, ti.uname, ti.gname = len(dados), modo, "root", "root"
    ti.mtime = time.time()
    tar.addfile(ti, io.BytesIO(dados))


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    saida = sys.argv[1]
    variante = sys.argv[sys.argv.index("--variante") + 1] if "--variante" in sys.argv else None

    arquivos = subprocess.run(["git", "ls-files", "--cached", "--others", "--exclude-standard"],
                              capture_output=True, text=True, check=True).stdout.split("\n")
    arquivos = sorted(a for a in set(arquivos) if a and os.path.isfile(a) and incluir(a, variante))

    ear = desc = None
    if variante:
        ear = os.path.join(variante, "aghu.ear")
        var = open(os.path.join(variante, "VARIANTE"), encoding="utf-8").read()
        esperado = re.search(r'^SHA256_AGHU_EAR="([0-9a-f]{64})"', var, re.M)
        hash_ear = sha256(ear)
        if esperado and esperado.group(1) != hash_ear:
            sys.exit("ERRO: SHA-256 do aghu.ear da variante nao confere com o arquivo VARIANTE")
        desc = re.search(r'^DESCRICAO="(.*)"', var, re.M).group(1)
        # remove as partes do aghu.ear original e usa as da variante
        arquivos = [a for a in arquivos if not a.startswith("pacote/aghu.ear.parte-")]

    with tarfile.open(saida, "w:gz", compresslevel=6) as tar:
        for a in arquivos:
            if variante and a == "pacote/SHA256SUMS":
                linhas = open(a, encoding="utf-8").read().splitlines()
                linhas = [("%s  aghu.ear" % hash_ear) if re.search(r"\saghu\.ear$", l) else l for l in linhas]
                adicionar_bytes(tar, a, ("\n".join(linhas) + "\n").encode())
                continue
            ti = tar.gettarinfo(a, arcname="aghuse/" + a)
            ti.mode = 0o755 if a.endswith(".sh") else 0o644
            ti.uid = ti.gid = 0
            ti.uname = ti.gname = "root"
            with open(a, "rb") as f:
                tar.addfile(ti, f)
        if variante:
            adicionar_bytes(tar, "VARIANTE", var.encode())
            with open(ear, "rb") as f:
                n = 0
                while True:
                    bloco = f.read(PARTE)
                    if not bloco:
                        break
                    n += 1
                    adicionar_bytes(tar, "pacote/aghu.ear.parte-%03d" % n, bloco)
    print("pacote gerado: %s (%d MB)%s" % (saida, os.path.getsize(saida) // 2**20, (" - " + desc) if desc else ""))
    print("SHA-256: %s" % sha256(saida))


if __name__ == "__main__":
    main()
