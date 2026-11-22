# Como contribuir

O Farol é usado em emergência. **Um número errado pode custar uma vida**, então toda informação precisa de fonte oficial.

## Não programo, mas sei de um número errado ou faltando

Abra uma issue com o formulário **"Sugerir número ou correção"**. Coloque o link da página oficial onde o número aparece.

## Quero adicionar ou corrigir uma cidade

Os dados locais ficam em `locais/`, em camadas:

| Arquivo | O que tem | Exemplo |
|---|---|---|
| `locais/padrao.yaml` | Texto para "Outra cidade". Lista **todos** os blocos existentes | números nacionais (116, 115, 117) |
| `locais/estados/UF.yaml` | O que vale para o estado todo | centro de intoxicação, Defesa Civil estadual |
| `locais/empresas/ID.yaml` | Empresas de energia, água e gás | Cemig, Caern |
| `locais/cidades/UF/ID.yaml` | O que é só da cidade | Defesa Civil municipal, hospitais, áreas de risco |

Os capítulos (`conteudo/capitulos/`) têm linhas `{{nome-do-bloco}}`. O app usa o bloco da camada mais específica: **cidade, depois empresa, depois estado, depois padrão**.

### Passo a passo para uma cidade nova

1. Crie `locais/cidades/UF/nome-da-cidade.yaml` (copie uma cidade parecida). Preencha `nome`, `uf`, `energia`, `agua` e `gas` com os ids das empresas (`null` se não houver gás encanado), e `verificado_em`.
2. Acrescente a cidade em `locais/indice.yaml`.
3. Se o estado ou a empresa ainda não existem, crie os arquivos em `locais/estados/` ou `locais/empresas/`.
4. Pasta de estado nova? Inclua `- locais/cidades/UF/` nos `assets` do `pubspec.yaml`.
5. **Cada informação precisa de `[fonte: id]`**, e a fonte precisa estar em `fontes/fontes.yaml`, com o link e o trecho onde aparece. Veja `fontes/README.md`.
6. Telefones tocáveis: `[(31) 3224-4000](tel:3132244000)`. No link, só dígitos.
7. Rode `flutter test`. Os testes conferem:
   - que todo bloco usado existe no padrão;
   - que as empresas e o estado da cidade existem;
   - que as fontes citadas existem no catálogo;
   - que **nenhuma cidade vê o serviço de outra**.

### Revisão

- Todo pull request roda `ferramentas/conferir_telefones.py`, que abre a fonte e procura o número na página.
  - **AUSENTE:** a página abriu e o número não está lá. Bloqueia o PR até alguém conferir.
  - **SEM-ACESSO:** a página não abriu. Precisa de conferência manual.
- Mudança de telefone só entra com aprovação de quem mantém o projeto.
- Informação conferida há mais de um ano deve ser conferida de novo (campo `verificado_em`).

## Textos dos capítulos

Siga a regra de `fontes/README.md`: fonte oficial brasileira primeiro; entre fontes que divergem, a mais segura; orientação sem fonte oficial marcada com `[geral]`; dose e número de saúde só com fonte.
