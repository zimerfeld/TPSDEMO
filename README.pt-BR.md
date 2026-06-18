# Third Person Shooter Demo — Documentação completa (Português)

> Documentação detalhada e extensa em português. Para o resumo bilíngue de alto nível veja
> [README.md](README.md); a versão em inglês é [README.en-US.md](README.en-US.md).
> O cofre [`OBSIDIAN/`](OBSIDIAN) espelha este conteúdo com notas por sistema.

Demo de tiro em terceira pessoa feita com a [Godot Engine](https://godotengine.org).

![Captura de tela da demo TPS](screenshots/screenshot.webp)

## Visão geral

Partindo da demo TPS original da Godot, este projeto a expande para um pequeno sandbox de tiro
em terceira pessoa. Em alto nível, oferece:

- **Fluxo por menus** — um menu principal leva à seleção de personagem, ao seletor de fases, à
  tela de configurações, à tela de desenvolvedor e ao jogo online.
- **Personagens jogáveis** — variações de player selecionáveis que se movem, miram, pulam e
  atiram, com câmera em primeira pessoa e um HUD de vida local.
- **Inimigos** — um inimigo terrestre (Red Robot) que se aproxima, mira e dispara um laser, e um
  bombardeiro voador (Criatura Alada) que orbita o player e solta bombas.
- **Dano localizado** — colliders 3D nativos por membro (cabeça, tronco, braços, pernas)
  dimensionados pela malha de cada personagem, então acertos em partes diferentes causam dano
  diferente (headshots causam dano extra). Tanto as balas quanto o laser do inimigo os respeitam.
- **Várias fases** — uma arena simples (Level 1), um encontro com o bombardeiro (Level 2), uma
  fase completa e complexa (Level Base), além do jogo online (host/conectar).
- **Biblioteca + visualizador de modelos 3D** — assets 3D reutilizáveis organizados por tipo em
  `library3D/`, navegáveis no jogo pela tela Models (categoria → modelo → parte) com toggles de
  rotação, animação, **Áudio** (todo som que não é fala: movimento, motor, tiros…), **Falas**
  (apenas emissores de fala/grito), colliders e **Efeitos especiais** (todo o resto ligado ao
  modelo — partículas, luzes, malhas de laser/clarão presas a ossos). Cada toggle é o interruptor
  mestre da sua categoria (nenhum som/animação toca enquanto o toggle estiver desligado,
  independentemente do dropdown — inclusive som disparado por trilhas de animação) e os estados
  dos toggles são persistidos entre visitas. Os dropdowns de "Animação" e "Efeitos Especiais"
  aparecem só na visão montada "Modelo completo"; o de efeitos isola um único efeito quando
  escolhido. Escolher um valor em qualquer seletor (Categoria → Prefixo → Modelo → Parte) reseta
  todos os dropdowns abaixo dele para "Selecione…". Arraste para girar o modelo à mão em até 180°
  nos dois eixos. Alternar qualquer opção age no preview ao vivo, no lugar — nunca recarrega o
  modelo nem altera a câmera/rotação. Para Personagens e Armas, um rótulo (CABEÇA, TRONCO, BRAÇO…)
  flutua sobre o collider de cada membro; personagens com skin são enquadrados/centralizados pelos
  colliders posados para girarem no lugar em vez de derivar.
- **HUD cyberpunk & widgets 2D** — um conjunto de controles de UI reutilizáveis (HUD, minimapa,
  vitais, mira, menu de pausa, scanlines e mais).
- **Ferramentas de debug** — veja [Tela developer & overlay de debug](#tela-developer--overlay-de-debug).
- **Localização (EN/PT)** — veja [Localização](#localização-enpt).
- **Configurações** — veja [Configurações](#configurações).

## Tela developer & overlay de debug

Um overlay de debug global (`autoload/debug_overlay.gd`, autoload **DebugOverlay**) é ligado pela
tela **developer** e pela aba "Debug" das configurações. Todos os toggles persistem nas
configurações salvas (seção `game`) e aplicam na hora (`DebugOverlay.refresh()`).

A tela developer organiza os toggles em **duas colunas**, cujos tooltips usam cores claras
distintas para você diferenciá-los:

- **Debug 2D** (rótulos/tooltips amarelo claro) — master `debug_2d` mais os interruptores
  dependentes `Type` / `Name` / `Id`. Controla o overlay 2D (uma borda colorida + um tooltip
  TYPE/Name/ID) em cada `Control`.
- **Debug 3D** (rótulos ciano claro) — master `debug_3d` mais os dependentes `Type` / `Name` /
  `Id` (descrevendo o nó `Skeleton3D`), `Members`, `Skeleton` e `Mesh`. Renderiza rótulos
  `Label3D` por membro que seguem a pose viva.

Regra de dependência: o master de uma coluna estar ligado **não basta** — cada linha/recurso
dependente só passa a valer quando *também* selecionado, em sincronia com seu master. Quando o
master de uma coluna está desligado, os botões dos sub-toggles ficam desativados e escurecidos
(acinzentados). Quando o master está ligado mas nenhuma linha dependente está selecionada, a
coluna não mostra nada (a borda e os tooltips 2D só aparecem quando ao menos um de Type/Name/Id
está selecionado; os rótulos 3D ficam ocultos até seus sub-toggles serem selecionados).

Os extras de **Debug 3D** são: **Members** (rótulos por membro CABEÇA/TRONCO/BRAÇO… pelo mesmo
classificador `BodyParts` usado pelos colliders de dano localizado), **Skeleton** (linhas brancas
de osso refeitas todo frame a partir da pose viva) e **Mesh** (caixa wireframe ciano do AABB de
cada MeshInstance3D).

Acima das colunas, uma seção geral tem **HUD FPS** (`hud_fps`) e **Malha no Solo** (`show_grid`) —
uma grade wireframe de 100 m × 100 m na origem, em qualquer tela que contenha conteúdo 3D
(Modelos 3D, fases). Como o `main.gd` troca as telas como filhas do nó `Main` (então
`current_scene` permanece sempre `Main`, um `Node` comum), o grid detecta a tela carregada ativa e
procura qualquer descendente `Node3D` em vez de checar o tipo da raiz; ele some nas telas puramente
2D (menu/configurações/developer).

## Localização (EN/PT)

O idioma da UI alterna entre **Português** e **English** pelo autoload **Locale**
(`autoload/locale.gd`).

- Cada idioma é um dicionário JSON plano na raiz do projeto — `pt.json` e `en.json` — com as
  **mesmas chaves** (o texto-fonte canônico, do build em português, de cada Button/Label) mapeando
  para o texto daquele idioma. `pt.json` é essencialmente identidade (preserva a aparência atual);
  `en.json` traz as traduções em inglês.
- A escolha é persistida nas configurações salvas (`game/language`, padrão `pt`) e aplicada na
  inicialização. No `_ready`, o Locale carrega o dicionário e conecta-se a `node_added`, então todo
  Button/Label que entra na árvore é traduzido automaticamente — telas novas são cobertas **sem
  código por cena**. Na primeira vez que vê um nó, guarda o texto original em um meta, para que
  trocas de idioma traduzam a partir do original e não de um texto já traduzido.
- Dois botões de idioma (**Português** / **English**) ficam ancorados no rodapé do menu principal.
  Pressionar um chama `Locale.set_language(...)`, que persiste a escolha e re-localiza a árvore viva
  no lugar (o botão do idioma ativo fica acinzentado).

**Regra de manutenção:** sempre que alterar ou adicionar um texto de Button/Label numa cena,
atualize a chave correspondente em **ambos** `pt.json` e `en.json` na mesma mudança (PT recebe o
texto em português, EN o em inglês) e valide os dois JSON. Como o Locale indexa pelo texto-fonte,
mudar a cena sem atualizar a chave quebra a tradução.

## Configurações

A tela de configurações tem abas (`Display`, `Resolution`, `Antialiasing`, `Lighting`, `Effects`,
`Audio`) com um ritmo vertical consistente (espaçamento de linhas/seções igual a 8). A maioria das
linhas é um conjunto de botões toggle que compartilham um gradiente verde → amarelo → laranja →
vermelho lido como barato → caro (ex.: performance vs. qualidade), com o botão verde sendo a opção
segura/leve.

- **Display** — Modo de exibição (Window / Fullscreen / Exclusive Fullscreen), Sincronização
  Vertical e Limite de FPS (30…144 / Unlimited). Os botões de modo e de limite de FPS são coloridos
  pelo mesmo gradiente (limite maior = mais exigente = cor mais quente).
- **Resolution** — um dropdown de resolução de vídeo (tingido de ciano claro para marcá-lo como
  seletor), escala de resolução e o filtro de escala (Bilinear / FSR / MetalFX…).
- **Antialiasing** — TAA, MSAA e FXAA.
- **Lighting** — Shadow Mapping, Tipo/Qualidade de GI, SSAO e SSIL.
- **Effects** — Bloom e Volumetric Fog.
- **Audio** — controles independentes para **Música** de fundo (o bus `Music`) e **Efeitos de Som**
  (o bus `SFX`, para onde os buses de gameplay `Outside`/`Reactor` são roteados), cada um salvo e
  aplicado globalmente.

**Configurações ao vivo** — não há botão "Apply": cada opção salva e aplica no instante em que muda.
O dropdown de resolução de vídeo é a exceção: pede confirmação, aplicando (e travando em modo
janela) no "Sim" ou revertendo para a escolha salva no "Não". Um botão **Reset** (ao lado de
"Voltar") restaura os padrões internos para hardware comum — após a mesma confirmação Sim/Não —
salvando e aplicando na hora. Sem config salva (instalação nova) o jogo também inicia nesses
padrões. O menu principal lê todas as configurações salvas do disco e as aplica (gráficos,
resolução e áudio) antes de mostrar o menu. Uma resolução escolhida é limitada à área visível da
tela (para que uma escolha 4K/8K num monitor menor não empurre a janela para fora), e a barra de
botões no rodapé e o título no topo de cada tela são ancorados em largura total à sua borda para
permanecerem visíveis em qualquer resolução.

## Requisitos

Este projeto tem como alvo o **Godot 4.6.2 (estável)** — baixe-o
[no site](https://godotengine.org/download/) ou
[compile a partir do código-fonte](https://github.com/godotengine/godot). Git LFS não é necessário.

> **Nota:** o repositório é grande, então espere um tempo de espera alto ao abrir o projeto pela
> primeira vez.

## Executando

Pegue o projeto em [zimerfeld/TPSDEMO](https://github.com/zimerfeld/TPSDEMO) — clone-o ou
[baixe um arquivo ZIP](https://github.com/zimerfeld/TPSDEMO/archive/refs/heads/main.zip) — e abra-o
no Godot 4.6.2.

## Estrutura do projeto

As telas 2D e a UI ficam em `scenes2D/`, as fases 3D em `scenes3D/`, e a biblioteca de assets 3D
reutilizáveis em `library3D/`:

- `scenes2D/` — todas as telas 2D e a UI:
  - `main` — cena de entrada. `main.gd` é um roteador que troca as telas como filhas (reagindo aos
    sinais `replace_main_scene` / `quit`) em vez de chamar `SceneTree.change_scene`, então
    `current_scene` permanece `main`.
  - `menu`, `chooseplayer`, `levels`, `settings`, `developer`, `playonline` — as telas de navegação.
  - `controls2D` — widgets de UI reutilizáveis (HUD cyberpunk, minimapa, vitais, barra de
    habilidade, mira, menu de pausa, scanlines, log feed, etc.).
  - `controls` — um visualizador de controles 2D (o análogo 2D da tela Models) que navega e
    pré-visualiza os widgets de `controls2D` por um dropdown.
  - `cyberpunkhud` — tela de HUD montada a partir dos widgets de `controls2D`.
- `scenes3D/` — fases e ferramentas 3D: `level_1`, `level_2`, `level_base` e o visualizador `models`.
- `library3D/` — biblioteca de assets 3D, organizada por tipo: `characters`, `propulsores`,
  `structures`, `weapons`, mais as pastas de apoio `geometry` e `textures`. Novas pastas de modelos
  colocadas aqui aparecem automaticamente no visualizador Models.
- `effects_shared/` — helpers compartilhados entre personagens: `limb_colliders.gd` (colliders
  nativos por membro para dano localizado), `body_parts.gd` (classificação osso → membro) e assets
  de blast/sombra compartilhados.
- `autoload/` — singletons globais: `crash_handler.gd`, `player_selection.gd`, `debug_overlay.gd`,
  `locale.gd`. O `Settings` fica em `scenes2D/settings/config.gd`.
- `pt.json`, `en.json` — dicionários de idioma da UI lidos pelo autoload `Locale`.
- `ui/`, `themes/` — recursos de tema compartilhados. `tools/` — scripts helper headless.
- `OBSIDIAN/` — cofre de documentação do projeto (espelha este README).

Fluxo de telas:

```
menu ─┬─ play ───────► chooseplayer ─► levels ─► level_1 / level_2 / level_base
      ├─ play online ─► playonline ──► level_base
      ├─ settings
      ├─ developer ──┬─ models    (visualizador de modelos 3D da library3D)
      │              └─ controls  (visualizador de controles 2D dos widgets controls2D)
      └─ quit
```

`main.gd` é o roteador: cada tela emite `replace_main_scene` e o `main` a troca, então os botões de
voltar (e <kbd>Escape</kbd>) navegam para a tela anterior do mesmo jeito. A tela `settings` aplica e
persiste cada mudança na hora e o `menu` reaplica todas as configurações salvas ao entrar. A tela
`developer` e a aba "Debug" das configurações controlam o `DebugOverlay`. O autoload `Locale` troca
o idioma da UI (EN/PT) pelos botões de idioma do menu. A cena `cyberpunkhud` é um preview de HUD
montado isolado, fora deste fluxo de navegação.

Layout de pastas e subpastas:

```
TPSDEMO/
├─ scenes2D/             # telas 2D, UI e widgets reutilizáveis
│  ├─ main/              # cena de entrada + roteador (main.gd troca as telas)
│  ├─ menu/              # menu principal
│  ├─ chooseplayer/      # seletor de personagem (preview 3D)
│  ├─ levels/            # seletor de fases
│  ├─ settings/          # tela de configurações + autoload Settings (config.gd)
│  ├─ developer/         # menu de ferramentas dev (toggles de debug, links p/ visualizadores)
│  ├─ playonline/        # tela de host/conectar online
│  ├─ controls/          # visualizador de widgets 2D (análogo da tela Models)
│  └─ controls2D/        # widgets de HUD reutilizáveis: crosshair, minimap_panel, vitals_panel, …
├─ scenes3D/             # fases e ferramentas 3D
│  ├─ level_1/ level_2/ level_base/   # fases jogáveis
│  └─ models/            # visualizador/inspetor de modelos 3D da library3D
├─ library3D/            # biblioteca de assets 3D, organizada por tipo
│  ├─ characters/        # players + inimigos
│  ├─ propulsores/       # props de propulsão (forklift)
│  ├─ structures/        # estruturas estáticas (door, core, lights, props, structure)
│  ├─ weapons/           # armas (pistola_infantil, bomb)
│  ├─ geometry/          # malhas/materiais compartilhados (.tres)
│  └─ textures/          # texturas compartilhadas
├─ effects_shared/       # helpers entre personagens: limb_colliders.gd, body_parts.gd, …
├─ autoload/             # singletons globais: crash_handler, player_selection, debug_overlay, locale
│                        #   (Settings fica em scenes2D/settings/config.gd)
├─ pt.json  en.json      # dicionários de idioma da UI (Português / English) lidos pelo Locale
├─ ui/  themes/          # recursos de Theme compartilhados (ui_theme.tres, cyberpunk.tres)
├─ tools/  _gen/         # geradores GDScript headless de assets 3D (gen_*.gd)
├─ addons/               # plugins do editor Godot (godot_ai — o servidor MCP)
├─ OBSIDIAN/             # cofre de documentação do projeto (espelha este README)
├─ screenshots/          # imagens de preview capturadas
└─ project.godot · default_bus_layout.tres · file_format.sh   # config do projeto · buses de áudio · formatador
```

## Controles

- Mouse ou <kbd>Analógico direito do gamepad</kbd>: Olhar ao redor
- <kbd>W</kbd>/<kbd>A</kbd>/<kbd>S</kbd>/<kbd>D</kbd>, <kbd>Setas</kbd>, <kbd>Analógico esquerdo</kbd> ou <kbd>D-Pad</kbd>: Mover
- <kbd>Espaço</kbd>, <kbd>Gamepad A/Cross</kbd>: Pular
- <kbd>Botão direito do mouse</kbd>, <kbd>Gatilho esquerdo (L2)</kbd> (pressione p/ alternar, ou segure e solte): Mirar
- <kbd>Botão esquerdo do mouse</kbd>, <kbd>Gatilho direito (R2)</kbd>: Atirar (apenas mirando)
- <kbd>Escape</kbd>, <kbd>Gamepad Start</kbd>: Ir ao menu principal/sair
- <kbd>F11</kbd> ou <kbd>Alt + Enter</kbd>: Alternar tela cheia
- <kbd>F3</kbd>: Alternar informações de debug (como o contador de FPS)

## Formatação de código

Todos os arquivos de texto deste projeto devem seguir um formato consistente, garantido pelo
[`file_format.sh`](file_format.sh). Sempre aplique-o antes de commitar mudanças:

- Codificação UTF-8 **sem BOM**
- Quebras de linha LF (Unix)
- Sem espaços em branco no fim das linhas
- Uma quebra de linha final no fim do arquivo

Rode o formatador a partir da raiz do repositório:

```bash
bash file_format.sh
```

No Windows, rode pelo Git Bash. Ele requer `dos2unix` e `perl` (`recode` é opcional). Uma causa
comum de `Parse Error: Expected '['` ao carregar um `.tscn`/`.tres` é um BOM UTF-8 perdido — rodar o
formatador o remove.

> **Dica:** após mover ou renomear cenas/recursos, reabra o projeto no editor Godot uma vez para que
> ele reconstrua o `.godot/uid_cache.bin` e reimporte os assets movidos (isso limpa os avisos
> `invalid UID … using text path instead`).

## Documentação & base de conhecimento

O `README.md` é um resumo bilíngue de alto nível; este arquivo (`README.pt-BR.md`) e o
[`README.en-US.md`](README.en-US.md) guardam a documentação extensa e detalhada, e o cofre
[`OBSIDIAN/`](OBSIDIAN) os espelha com notas por sistema. **Os três arquivos README são mantidos
atualizados ao final de cada mudança** para continuarem sendo uma base de conhecimento confiável
para qualquer análise ou tomada de decisão.

## Links úteis

- [Site principal](https://godotengine.org)
- [Código-fonte](https://github.com/godotengine/godot)
- [Documentação](http://docs.godotengine.org)
- [Comunidade](https://godotengine.org/community)
- [Outras demos](https://github.com/godotengine/godot-demo-projects)

## Licença

Veja [LICENSE.md](LICENSE.md) para detalhes.
