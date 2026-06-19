# ZIMARO — Documentação completa (Português)

> Documentação detalhada e extensa em português. Para o resumo bilíngue de alto nível veja
> [README.md](README.md); a versão em inglês é [README.en-US.md](README.en-US.md).
> O cofre [`OBSIDIAN/`](OBSIDIAN) espelha este conteúdo com notas por sistema.

ZIMARO é um sandbox de tiro em terceira pessoa feito com a [Godot Engine](https://godotengine.org).

- Ajude a manter este projeto sempre atualizado 💜

[![GitHub Sponsor](https://img.shields.io/badge/Sponsor-zimerfeld-EA4AAA?style=for-the-badge&logo=githubsponsors&logoColor=white)](https://github.com/sponsors/zimerfeld) &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; [![Ko-fi](https://img.shields.io/badge/Ko--fi-Buy%20me%20a%20coffee-FF5E2B?style=for-the-badge&logo=ko-fi&logoColor=white)](https://ko-fi.com/C0D621FCGD)

## Visão geral

Construído sobre a Godot Engine, o ZIMARO é um pequeno sandbox de tiro
em terceira pessoa. Em alto nível, oferece:

- **Fluxo por menus** — um menu principal leva à seleção de personagem, ao seletor de fases, à
  tela de configurações, à tela de desenvolvedor e ao jogo online.
- **Personagens jogáveis** — variações de player selecionáveis que se movem, miram, pulam e
  atiram, com câmera em primeira pessoa e um HUD de vida local.
- **Inimigos** — um inimigo terrestre (Red Robot) que se aproxima, mira e dispara uma **bala de
  canhão** preta (uma versão recolorida, com brilho vermelho, do tiro do player), e um bombardeiro
  voador (Criatura Alada) que orbita o player e solta bombas.
- **IA do Red Robot** — comportamentos e decisões em tempo de execução isolados num script de IA
  dedicado (`library3D/characters/red_robot/IA/red_robot_ai.gd`): recarga **1,5× mais rápida** (no
  1º e nos próximos tiros); **abre fogo** assim que o player entra no alcance da arma e está a mais
  de 10 m; e, se o player chegar a **10 m ou menos**, o robô **recua correndo no sentido oposto**
  enquanto continua olhando/mirando e atirando.
- **HUD do inimigo** — a *boss bar* compartilhada no topo da tela mostra nome, vida e distância do
  inimigo e, quando ele possui um mecanismo de ataque/tiro, também o **alcance da arma em metros**.
- **Dano localizado** — colliders 3D nativos por membro (cabeça, tronco, braços, pernas)
  dimensionados pela malha de cada personagem, então acertos em partes diferentes causam dano
  diferente (headshots causam dano extra). Os tiros atravessam o collider de corpo genérico e
  acertam os colliders de membro. Peças salientes ganham um collider PRÓPRIO em caixa (ex.: as
  **placas traseiras das pernas** do Red Robot, que a cápsula da perna não cobriria).
- **Tiro reutilizável** — o disparo de bala de canhão e o de laser hitscan foram isolados em
  componentes reutilizáveis (`CannonShooter` / `LaserShooter` em `effects_shared/`) que qualquer
  modelo pode usar; player e Red Robot disparam via `CannonShooter`.
- **Várias fases** — uma arena simples (Level 1), um encontro com o bombardeiro (Level 2), uma
  fase completa e complexa (Level Base), além do jogo online (host/conectar).
- **Biblioteca + visualizador de modelos 3D** — assets 3D reutilizáveis organizados por tipo em
  `library3D/`, navegáveis no jogo pela tela Models (categoria → modelo → parte) com toggles, nesta
  ordem, de rotação, **Animação**, **Efeitos especiais** (tudo ligado ao modelo que nenhum outro
  toggle cobre — partículas, luzes, malhas de laser/clarão presas a ossos), **Áudio** (todo som que
  o modelo emite — movimento, motor, tiros, explosões, vozes) e colliders. Cada toggle é o
  interruptor mestre da sua categoria (nenhum som/animação toca enquanto o toggle estiver desligado,
  inclusive som disparado por trilhas de animação) e os estados dos toggles são persistidos entre
  visitas. Uma animação só roda quando **o toggle está ligado E um clip está escolhido** no dropdown
  "Animação" (não há mais auto-play de um clip padrão). Os dropdowns de "Animação" e "Efeitos
  Especiais" aparecem só na visão montada "Modelo completo". "Efeitos Especiais" lista, após
  "Selecione…", a opção **"Todos"** e exibe efeitos de todos os tipos que existirem (luzes/
  luminosidade, fumaça, partículas, decals, névoa…); escolher um item isola um único efeito.
  Escolher um valor em qualquer seletor (Categoria → Prefixo → Modelo → Parte) reseta
  todos os dropdowns abaixo dele para "Selecione…". **Todas as escolhas dos seletores são
  persistidas** (junto com os toggles), e ao reabrir a tela a cadeia é restaurada exatamente como foi
  deixada — sem auto-selecionar nenhum item: o primeiro seletor sem escolha salva fica em "Selecione…"
  pronto para continuar; se uma escolha salva não existir mais na biblioteca, esse seletor (e os
  abaixo) ficam desabilitados. A navegação é guiada apenas pelo gating sequencial dos dropdowns
  (sem linha de status). Arraste para girar o modelo à mão em
  até 180° nos dois eixos. Alternar qualquer opção age no preview ao vivo, no lugar — nunca recarrega
  o modelo nem altera a câmera/rotação. Para Personagens e Armas, a **pilha de tooltips do Debug 3D**
  (TYPE/Name/ID/Membro, em ciano) flutua sobre o collider de cada membro — os **mesmos tooltips** das
  fases, controlados pelas mesmas sub-chaves da coluna **Debug 3D** (tela developer): cada linha
  aparece conforme `Type`/`Name`/`Id`/`Membros`. Personagens com skin são enquadrados/centralizados
  pelos colliders posados para girarem no lugar em vez de derivar.
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
dependente só passa a valer quando _também_ selecionado, em sincronia com seu master. Quando o
master de uma coluna está desligado, os botões dos sub-toggles ficam desativados e escurecidos
(acinzentados). Quando o master está ligado mas nenhuma linha dependente está selecionada, a
coluna não mostra nada (a borda e os tooltips 2D só aparecem quando ao menos um de Type/Name/Id
está selecionado; os rótulos 3D ficam ocultos até seus sub-toggles serem selecionados).

Os extras de **Debug 3D** são: **Members** (rótulos por membro CABEÇA/TRONCO/BRAÇO… pelo mesmo
classificador `BodyParts` usado pelos colliders de dano localizado), **Skeleton** (linhas brancas
de osso refeitas todo frame a partir da pose viva) e **Mesh** (caixa wireframe ciano do AABB de
cada MeshInstance3D).

Acima das colunas, uma seção geral tem **HUD FPS** (`hud_fps`), **System Health**
(`system_health`, veja abaixo) e **Malha no Solo** (`show_grid`) — uma grade wireframe de
100 m × 100 m na origem, em qualquer tela que contenha conteúdo 3D (Modelos 3D, fases). Como o
`main.gd` troca as telas como filhas do nó `Main` (então `current_scene` permanece sempre `Main`,
um `Node` comum), o grid detecta a tela carregada ativa e procura qualquer descendente `Node3D` em
vez de checar o tipo da raiz; ele some nas telas puramente 2D (menu/configurações/developer).

## Monitor System Health

A linha **System Health** da tela developer alterna um overlay de monitoramento global
(`autoload/system_health.gd`, autoload **SystemHealth**) — um **painel flutuante arrastável**. A barra
de título fica num **cabeçalho com uma linha**: o **texto do título** à esquerda (o **único** ponto
que move a janela — segure o botão esquerdo do mouse **sobre o título**) e um **botão de fechar vermelho
estilo Windows (✕)** à direita, cuja área **não** arrasta a janela. Fechar **esconde** o painel mas
**mantém o monitoramento rodando** (a rede de segurança continua armada e um pico crítico reabre o
painel); reabra pelo interruptor da tela developer. O painel **sempre fica dentro da tela** e sua
**posição é lembrada entre execuções** (o **Reset** das configurações o devolve ao canto superior
direito). Ele mostra: **FPS**, o **uso real de CPU do processo** (`CPU`), a memória estática do jogo
(`Mem. Jogo`), a memória de vídeo (`Mem. Vídeo`) e a RAM do sistema em uso (`Mem. Sistema` = total −
RAM física livre; ex.: 12,6 / 16,2 GB = 78%). As três linhas de memória seguem o mesmo padrão
**"usado / total (%)"**, tendo a RAM física como total comum (ex.: `Mem. Jogo` = 0,4 / 16,2 GB = 2%).

A CPU é o uso real do processo do Godot, batendo com o que o Gerenciador de Tarefas mostra: o Godot
não tem API para isso, então uma **thread em segundo plano** amostra do SO (`Get-Process … .CPU` via
PowerShell no Windows) e converte leituras sucessivas em porcentagem sobre os núcleos lógicos. Mostra
**N/D** até o primeiro delta ficar pronto, ou em plataformas não-Windows. (Uso de GPU por processo e
temperatura de CPU não estão disponíveis de forma confiável pela engine, então não são exibidos.)

Quando a RAM do sistema atinge o limite seguro de **90%** — ou a CPU fica acima dele por alguns
segundos (picos curtos são tolerados) — o painel deixa a linha de alerta vermelha e, se o interruptor
"Pausar ao atingir o limite" do painel estiver ligado (padrão), **pausa o processamento**
(`get_tree().paused`) para impedir que uma máquina fraca congele ou trave o SO, oferecendo um botão
**Retomar**. O overlay continua funcionando mesmo pausado (`PROCESS_MODE_ALWAYS`); ao retomar, trava a
auto-pausa até o uso voltar abaixo do limite, para não pausar de novo na hora.

Acima disso há a regra **crítica (> 95%)**: enquanto **qualquer** indicador fica acima de 95%, cada
segundo sustentado conta como um **pico** e dispara um **bip de alerta** (um tom curto sintetizado, no
bus SFX, audível mesmo pausado). Após **mais de 3 picos consecutivos** (de 1 s cada), o painel é
**reexibido** (mesmo se o usuário o tinha fechado, desde que habilitado no developer) e o jogo é
**pausado à força** — **ignorando** o interruptor "Pausar ao atingir o limite". Essa é a garantia
máxima do brief: **em hipótese alguma** deixar o uso seguir até congelar/travar a máquina — antes
disso, pausa. Pausar derruba a carga do jogo, então picos de CPU cedem e o usuário pode retomar; um
recurso ainda crítico (ex.: RAM quase cheia) simplesmente permanece pausado, que é o desfecho seguro.

## Localização (EN/PT)

O idioma da UI alterna entre **Português** e **English** pelo autoload **Locale**
(`autoload/locale.gd`).

- **Dicionários por cena.** Cada cena traz seu próprio par de arquivos JSON planos numa pasta
  `Resources/` ao lado do `.tscn` — ex.: `scenes2D/menu/Resources/menu.pt.json` + `menu.en.json`.
  Eles têm as **mesmas chaves** (o texto-fonte canônico de cada Button/Label) mapeando para o texto
  daquele idioma. Na inicialização o Locale varre recursivamente `scenes2D/` e `scenes3D/`, acha
  todo `*.pt.json` / `*.en.json` e os **mescla** numa única tabela por idioma — então adicionar os
  dicionários `Resources/` de uma tela é tudo o que basta (sem editar o autoload).
- A escolha é persistida nas configurações salvas (`game/language`, padrão `pt`) e aplicada na
  inicialização. No `_ready`, o Locale conecta-se a `node_added`, então todo Button/Label que entra
  na árvore é traduzido automaticamente. `OptionButton`/`MenuButton` são ignorados (seu texto é a
  seleção viva) e, na primeira vez que vê um nó, guarda o texto original em um meta, para que trocas
  de idioma traduzam a partir do original e não de um texto já traduzido.
- **Toda tela tem os botões de idioma.** Uma `LangBar` no canto inferior direito com botões
  **Português** / **English** (o mesmo padrão do menu) está presente em menu, chooseplayer,
  settings, developer, levels, playonline, controls e models. Pressionar um chama
  `Locale.set_language(...)`, que persiste a escolha e re-localiza a árvore viva no lugar (o botão do
  idioma ativo fica acinzentado).
- **Textos vindos de código** (linhas de status dinâmicas, placeholders de dropdown, os títulos das
  abas de configurações e diálogos de confirmação, o painel System Health) não são alcançados pelo
  localizador automático de Button/Label, então esses nós entram no grupo `Locale.SKIP_GROUP` e
  reaplicam `Locale.tr_key(...)` sozinhos no sinal `language_changed`.

**Regra de manutenção:** sempre que alterar ou adicionar um texto de UI numa cena, atualize a chave
correspondente em **ambos** `Resources/<cena>.pt.json` e `.en.json` da cena na mesma mudança (PT
recebe o texto em português, EN o em inglês) e valide os dois JSON. Como o Locale indexa pelo
texto-fonte, mudar a cena sem atualizar a chave quebra a tradução.

## Configurações

A tela de configurações tem abas — na ordem **`Resolution`, `Display`**, `Antialiasing`,
`Lighting`, `Effects`, `Audio` — com um ritmo vertical consistente (espaçamento de linhas/seções
igual a 8). Os títulos das abas também são localizados (vêm dos nomes dos nós-filhos, então o Locale
os traduz em código). A maioria das linhas é um conjunto de botões toggle que compartilham um
gradiente verde → amarelo → laranja → vermelho lido como barato → caro (ex.: performance vs.
qualidade), com o botão verde sendo a opção segura/leve.

- **Resolution** — um dropdown de resolução de vídeo (tingido de ciano claro para marcá-lo como
  seletor), escala de resolução e o filtro de escala (Bilinear / FSR / MetalFX…).
- **Display** — Modo de exibição (Window / Fullscreen / Exclusive Fullscreen), Sincronização
  Vertical e Limite de FPS (30…144 / Unlimited). Os botões de modo e de limite de FPS são coloridos
  pelo mesmo gradiente (limite maior = mais exigente = cor mais quente).
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

Pegue o projeto em [zimerfeld/ZIMARO](https://github.com/zimerfeld/ZIMARO) — clone-o ou
[baixe um arquivo ZIP](https://github.com/zimerfeld/ZIMARO/archive/refs/heads/main.zip) — e abra-o
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
  `locale.gd`, `system_health.gd`. O `Settings` fica em `scenes2D/settings/config.gd`.
- `<cena>/Resources/*.pt.json` + `*.en.json` — dicionários de idioma da UI por cena, varridos e
  mesclados pelo autoload `Locale`.
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
`developer` e a aba "Debug" das configurações controlam o `DebugOverlay`, e a linha "System Health"
da tela developer controla o monitor `SystemHealth`. O autoload `Locale` troca o idioma da UI
(EN/PT) pelos botões Português/English presentes em todas as telas. A cena `cyberpunkhud` é um
preview de HUD montado isolado, fora deste fluxo de navegação.

Layout de pastas e subpastas:

```
ZIMARO/
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
├─ autoload/             # singletons: crash_handler, player_selection, debug_overlay, locale, system_health
│                        #   (Settings fica em scenes2D/settings/config.gd)
│                        # dicionários da UI por cena: <cena>/Resources/*.pt.json + *.en.json (lidos pelo Locale)
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
