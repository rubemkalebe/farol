# FAROL

**Ferramentas e Apoio para Rotinas Off-Line**

App de emergência que funciona sem internet, pensado para apagões e outros desastres no Brasil. Prioridade para o celular: num apagão de dias, o que fica ligado é o celular com um powerbank.

- **Plataformas:** Android primeiro. O mesmo código gera Windows, Linux, macOS e web (PWA); iOS depois.
- **Idioma:** português do Brasil.
- **Público:** uso pessoal e do círculo próximo. O código é aberto para quem quiser usar ou adaptar.

## Acessibilidade

- Fonte **Atkinson Hyperlegible** (Braille Institute, SIL OFL), feita para quem enxerga mal, embutida no app.
- **Tamanho da letra** no próprio app (Normal, Grande, Muito grande), somado ao tamanho escolhido no celular. Com letra grande, as telas viram uma coluna só e os botões de ligar ficam empilhados.
- Cores com contraste conferido pela WCAG: texto ≥ 4,5:1, contornos de campos ≥ 3:1.
- Nomes para leitor de tela (TalkBack, VoiceOver) nos botões de emergência e de ligar.
- Testes abrem as telas principais num celular comum com a letra no máximo e falham se algo estourar a tela.

## Organização

| Pasta | O que tem |
|---|---|
| `conteudo/` | Os guias, em Markdown. O app só exibe. Para corrigir um texto, não é preciso mexer no código. |
| `locais/` | Telefones e serviços por cidade, em camadas: padrão, estado, empresa e cidade. Veja `CONTRIBUTING.md`. |
| `fontes/` | Catálogo das fontes oficiais usadas (`fontes.yaml`) e cópias quando a licença permite. Veja `fontes/README.md`. |
| `ferramentas/` | `conferir_telefones.py`: confere se cada telefone aparece na fonte citada. |
| `lib/` | O app Flutter. |

## Conteúdo

O núcleo vem sempre instalado e é pequeno:

1. Durante o apagão: bateria, geladeira, água, remédios, segurança, comunicação
2. Primeiros socorros
3. Antes de cair: kit de 72 horas e checklist
4. Contatos de emergência e ficha da família (a ficha fica só no aparelho)
5. Quando a energia voltar
6. Outros desastres: enchente, deslizamento, tempestade, calor, fumaça, falta d'água

Para a hora do aperto: o botão **"O que está acontecendo?"** leva direto ao trecho certo do guia, com botão grande de ligar 192 ou 193, e a **busca** entende o jeito que a gente fala ("engasgou", "picou", "faltou luz"). O roteiro fica em `conteudo/emergencia.yaml` e os sinônimos em `conteudo/sinonimos.yaml`.

Ferramentas no app: **Ficha da família** (tipo sanguíneo, alergias, remédios e contatos, salva só no aparelho), **checklists** que ficam marcadas e **números que ligam com um toque**.

**Folha para imprimir:** um PDF com os telefones da cidade e, se a pessoa quiser, a Ficha da família, para imprimir ou mandar alguém imprimir.

**Passar o Farol adiante** (Android): o app manda a si mesmo, como arquivo .apk, para outro celular por Quick Share ou Bluetooth, sem internet.

**Onde ser atendido:** hospitais com pronto-socorro e UPAs 24 horas de cada cidade, com telefone e um botão que abre o endereço no app de mapas do celular.

**Mapa sem internet:** o Farol não tem mapa próprio. Ele ensina a guardar o mapa da cidade no Google Maps ou nos Mapas da Apple e lembra de conferir de tempos em tempos.

**Biblioteca sem internet:** o app baixa, a pedido, pacotes em português feitos pelo Kiwix e lê tudo sem internet. Wikipédia (Medicina, 116 MB; artigos principais; a Wikipédia inteira), com busca pelo título também na busca geral. E uma biblioteca para um apagão longo: Vikidia (enciclopédia para crianças), quase mil livros em domínio público do Projeto Gutenberg, Wikilivros, Wikiversidade, Wikivoyage, Wikcionário e Wikisource. Em inglês, a Appropedia (tecnologia simples: água, energia solar, saneamento) e os guias de conserto do iFixit (3,4 GB, menu em português). Nos pacotes que trazem fotos (Vikidia, Appropedia), o leitor mostra as imagens. O leitor do formato ZIM é do próprio Farol, em Dart, sem app extra.

**Manuais para recomeçar:** uma estante de PDFs gratuitos de órgãos públicos e instituições reconhecidas (Embrapa, Funasa, Ministério da Saúde, FAO, USP, ASA, UFV, Celesc): horta, milho, feijão, mandioca, sementes, galinhas, cabras, conservas, secador solar, tratamento de água, cisterna, fossa séptica, construção, fogão a lenha e aquecedor solar. O app baixa cada PDF direto do site de quem publicou, sem copiar nem alterar, e lê no próprio Farol, lembrando a página onde a pessoa parou. A lista fica em `conteudo/estante.yaml`, com a licença de cada manual.

Em estudo: manuais oficiais completos e livros em domínio público.

> **Aviso:** o Farol resume orientações de órgãos oficiais e cita a fonte de cada uma. Ele não substitui atendimento médico nem as instruções das autoridades locais. Em emergência, ligue 192 (SAMU) ou 193 (Bombeiros).

## Contribuir

Número errado ou faltando? Abra uma issue com o formulário **"Sugerir número ou correção"**. Para adicionar uma cidade, veja `CONTRIBUTING.md`.

## Rodar

```sh
flutter pub get
flutter run            # escolhe o dispositivo conectado
flutter build apk      # APK para instalar à mão no Android
```

## Licenças

- Código: MIT (`LICENSE`)
- Textos em `conteudo/`: CC BY-SA 4.0 (`conteudo/LICENSE.md`)
- Materiais de terceiros: licença dos autores, registrada em `fontes/fontes.yaml`
- Pacotes da biblioteca: baixados do Kiwix direto no aparelho (não ficam no repositório). Projetos Wiki em CC BY-SA (Vikidia 3.0, os demais 4.0, Appropedia incluída); livros do Projeto Gutenberg em domínio público; guias do iFixit em CC BY-NC-SA 3.0 (uso não comercial, como o Farol)
- Manuais para recomeçar: não ficam no repositório; cada um segue a licença de quem publicou (anotada em `conteudo/estante.yaml`) e é baixado do site oficial.
