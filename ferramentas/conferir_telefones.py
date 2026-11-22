#!/usr/bin/env python3
"""Confere se cada telefone dos arquivos locais aparece na página da fonte citada.

Para cada linha de locais/**/*.yaml com um link tel: e uma ou mais
[fonte: id], baixa as URLs dessas fontes (de fontes/fontes.yaml) e procura os
dígitos do número no texto. Saída:

  OK        o número aparece numa das fontes da linha
  AUSENTE   a página abriu e o número não está lá  → precisa de revisão humana
  SEM-ACESSO a página não abriu ou é PDF (bloqueio, fora do ar) → conferir à mão
  SEM-FONTE  o número não tem [fonte: id] na linha nem logo abaixo → erro

Termina com erro só se houver AUSENTE. Uso: python3 ferramentas/conferir_telefones.py
"""
import glob
import re
import sys
import urllib.request

FONTES = 'fontes/fontes.yaml'
TEL = re.compile(r'\]\(tel:(\d+)\)')
CITA = re.compile(r'\[fonte: ([a-z0-9-]+)\]')
CURTOS = {'190', '191', '192', '193', '194', '197', '198', '199', '100', '180', '181', '188',
          '112', '115', '116', '117', '136', '153', '156', '167'}


def urls_das_fontes():
    urls, atual = {}, None
    for linha in open(FONTES, encoding='utf-8'):
        m = re.match(r'\s*- id: (\S+)', linha)
        if m:
            atual = m.group(1)
        m = re.match(r'\s+url: "?([^"\s]+)"?', linha)
        if m and atual:
            urls[atual] = m.group(1)
    return urls


_cache = {}


def baixar(url):
    if url not in _cache:
        try:
            req = urllib.request.Request(url, headers={'User-Agent': 'farol-conferencia/1.0'})
            with urllib.request.urlopen(req, timeout=20) as r:
                corpo = r.read()
                # PDF não é lido aqui: precisa de conferência manual.
                if corpo[:5] == b'%PDF-' or 'pdf' in r.headers.get('Content-Type', ''):
                    _cache[url] = ValueError('PDF')
                else:
                    _cache[url] = corpo.decode('utf-8', 'ignore')
        except Exception as e:  # noqa: BLE001
            _cache[url] = e
    return _cache[url]


def so_digitos(s):
    return re.sub(r'\D', '', s)


def main():
    urls = urls_das_fontes()
    ausentes = 0
    for arq in sorted(glob.glob('locais/**/*.yaml', recursive=True)):
        linhas = open(arq, encoding='utf-8').read().split('\n')
        for n, linha in enumerate(linhas, 1):
            numeros = [t for t in TEL.findall(linha) if t not in CURTOS]
            fontes = CITA.findall(linha)
            # Linha de tabela sem citação: vale a citação logo abaixo da tabela
            # (até o fim da tabela e uma linha em branco).
            seguinte, brancas = n, 0
            while numeros and not fontes and seguinte < len(linhas) and brancas < 2:
                if not linhas[seguinte].strip():
                    brancas += 1
                fontes = CITA.findall(linhas[seguinte])
                seguinte += 1
            if numeros and not fontes:
                for num in numeros:
                    print(f'{"SEM-FONTE":10} {num:14} {arq}:{n}')
                ausentes += len(numeros)
                continue
            for num in numeros:
                achou, ilegivel = False, False
                for f in fontes:
                    pagina = baixar(urls.get(f, ''))
                    if isinstance(pagina, Exception) or not pagina:
                        ilegivel = True
                        continue
                    # aceita 0800 281 7005, (84) 3232-5155, 84 3232 5155...
                    if num in so_digitos(pagina) or num[-8:] in so_digitos(pagina):
                        achou = True
                        break
                # Só é AUSENTE quando todas as fontes foram lidas e nenhuma tem o número.
                estado = 'OK' if achou else ('SEM-ACESSO' if ilegivel else 'AUSENTE')
                ausentes += estado == 'AUSENTE'
                print(f'{estado:10} {num:14} {arq}:{n}')
    if ausentes:
        print(f'\n{ausentes} número(s) não encontrados na fonte. Confira antes de aprovar.')
        sys.exit(1)


if __name__ == '__main__':
    main()
