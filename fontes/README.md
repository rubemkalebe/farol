# Fontes

O Farol não inventa orientação de saúde ou segurança. O fluxo é:

1. **Coletar:** achar o material oficial (Ministério da Saúde, Defesa Civil, Anvisa, Cruz Vermelha, concessionárias) e registrar em `fontes.yaml`.
2. **Guardar:** baixar uma cópia em `arquivos/` quando a licença permitir. Se não permitir, fica só o link.
3. **Adaptar:** o texto do app em `conteudo/` é um resumo curto, em passos, feito para ler no celular durante a crise. Cada número e cada instrução vem de uma fonte catalogada, citada pelo `id`.
4. **Oferecer o original:** quando a fonte puder ser redistribuída, o documento completo entra num pacote opcional.

Quando duas fontes discordarem, vale a mais recente do órgão responsável, e a divergência fica anotada em `notas`.

## Regra de decisão

Quando as fontes divergem, a decisão segue esta ordem, sem depender de revisão leiga:

1. Fonte oficial brasileira (federal, depois estadual) antes de fonte estrangeira.
2. Entre números diferentes, vale **o mais seguro** (menos tempo fora da geladeira, mais tempo de fervura, mais distância).
3. Remédios: o app nunca substitui a bula. Sempre orienta a conferir a bula e procurar farmácia ou UBS.
4. Sem fonte oficial, o ponto pode entrar como **orientação geral**, marcado com `[geral]`, que no app vira uma etiqueta azul "geral". Isso **nunca** vale para dose, tempo ou temperatura de remédio, nem para número de saúde: esses só entram com fonte.
5. Nunca prometer direito que a norma não garante.

As decisões tomadas ficam em `divergencias.md`.

## Como citar no texto

No Markdown dos capítulos, escreva `[fonte: id]` depois da frase. O app transforma a marca numa etiqueta "fonte" (citações seguidas viram uma só, "2 fontes"), e o toque mostra as fontes. O teste `test/fontes_test.dart` falha se o `id` não existir no catálogo. Orientação sem fonte oficial leva `[geral]`.
