# FAROL

**Ferramentas e Apoio para Rotinas Off-Line**

App de emergência que funciona sem internet, pensado para apagões e outros desastres no Brasil. Prioridade para o celular: num apagão de dias, o que fica ligado é o celular com um powerbank.

- **Plataformas:** Android primeiro. O mesmo código gera Windows, Linux, macOS e web (PWA); iOS depois.
- **Idioma:** português do Brasil.
- **Público:** uso pessoal e do círculo próximo. O código é aberto para quem quiser usar ou adaptar.

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

Pacotes opcionais, para baixar quando houver internet: mapa offline da região (Organic Maps), Wikipédia em português sem imagens (Kiwix), manuais oficiais completos e livros em domínio público.

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
