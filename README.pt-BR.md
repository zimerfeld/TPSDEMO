# ZIMARO — Documentação completa (Português)

> Documentação detalhada e extensa em português. Para o resumo bilíngue de alto nível veja
> [README.md](README.md); a versão em inglês é [README.en-US.md](README.en-US.md).
> O cofre [`OBSIDIAN/`](OBSIDIAN) espelha este conteúdo com notas por sistema.

ZIMARO é um sandbox de tiro em terceira pessoa feito com a [Godot Engine](https://godotengine.org).

[![GitHub stars](https://img.shields.io/github/stars/zimerfeld/ZIMARO?style=for-the-badge&logo=github)](https://github.com/zimerfeld/ZIMARO/stargazers) &nbsp; [![GitHub downloads](https://img.shields.io/github/downloads/zimerfeld/ZIMARO/total?style=for-the-badge&logo=github&label=Downloads)](https://github.com/zimerfeld/ZIMARO/releases)

Este jogo é construído e mantido no meu tempo livre. Se você curte o ZIMARO, um patrocínio ajuda a manter novas funcionalidades e correções chegando. 💜

[![GitHub Sponsor](https://img.shields.io/badge/Sponsor-zimerfeld-EA4AAA?style=for-the-badge&logo=githubsponsors&logoColor=white)](https://github.com/sponsors/zimerfeld) &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; [![Ko-fi](https://img.shields.io/badge/Ko--fi-Buy%20me%20a%20coffee-FF5E2B?style=for-the-badge&logo=ko-fi&logoColor=white)](https://ko-fi.com/C0D621FCGD)

## Visão geral

Construído sobre a Godot Engine, o ZIMARO é um pequeno sandbox de tiro
em terceira pessoa. Em alto nível, oferece:

- **Fluxo por menus** — um menu principal leva à seleção de personagem, ao seletor de fases, à
  tela de configurações, à tela de desenvolvedor e ao jogo online.
- **Visuais das telas & diálogos** — cada tela 2D tem seu próprio **fundo animado por shader** (leve)
  que remete à sua função: uma **grade de fase** em perspectiva (Níveis), uma **rede de nós conectando**
  (Jogar Online), um **equalizador** (Configurações) e um **blueprint de dev** com varredura (Developer).
  A tela **Jogar Online** ainda emoldura a borda (com margem para dentro) com um **fio de metal
  trançado grosso** por onde **dois pulsos de energia elétrica intensa** (núcleo branco-quente,
  bloom pulsante e faíscas ramificadas) correm devagar, **espelhados no
  eixo vertical** (saem juntos do topo e se reencontram embaixo), com **faíscas tipo raio/trovão**
  crepitando no fio.
  Todas as **janelas de confirmação/aviso são montadas sobre um controle de janela flutuante
  reutilizável** (`FloatingWindow`, uma cena `controls2D`) — texto centralizado, botões de largura
  uniforme, × de fechar padrão e fundo modal —, criadas pelo helper `FloatingDialog`; a mesma base
  serve de fundação para outras janelas flutuantes.
- **Personagens jogáveis** — variações de player selecionáveis que se movem, miram, pulam e
  atiram, com câmera em primeira pessoa e um HUD de vida local. O **pulo é mais alto** e a
  **cadência de tiro mais espaçada**; o **tiro sai só depois de a mira assentar** (ao fim da
  animação de mira), partindo da extremidade do cano — corrigindo o glitch em que, no jogador
  **cliente**, a bala parecia sair antes da mira / fora do cano.
- **Bots aliados (cobertura)** — players da **facção amiga** (spawnados como `bot_controlled` pelos
  templates de fase) dão **cobertura e assistência** ao jogador: engajam ameaças próximas do bot ou
  do jogador, mas **seguem o jogador** e ficam dentro de uma **coleira** — ao se afastarem demais,
  reagrupar tem prioridade sobre perseguir, então **não saem mais correndo até cair do mapa**. Os
  comportamentos (seguir esquadrão, priorizar inimigos, espaçamento de combate, flanco sob pressão…)
  ficam num script de IA dedicado (`library3D/characters/players/player/IA/player_bot_ai.gd`).
- **Inimigos** — um inimigo terrestre (Red Robot) que se aproxima, mira e dispara uma **bala de
  canhão** preta (uma versão recolorida, com brilho vermelho, do tiro do player), e um bombardeiro
  voador (Criatura Alada) que orbita o player e solta bombas.
- **IA do Red Robot** — comportamentos e decisões em tempo de execução isolados num script de IA
  dedicado (`library3D/characters/red_robot/IA/red_robot_ai.gd`): recarga **1,5× mais rápida** (no
  1º e nos próximos tiros); **abre fogo** assim que o player entra no alcance da arma e está a mais
  de 10 m; e, se o player chegar a **10 m ou menos**, o robô **recua correndo no sentido oposto**
  enquanto continua olhando/mirando e atirando. Cada robô se move de forma **individualizada**
  (sinal de strafe, fase e velocidade próprios, semeados no spawn) para o pelotão **não andar igual
  a cada segundo**, e mantém uma **formação frouxa**: circula/estrafa livre em combate, mas tende a
  **voltar ao seu lugar designado** (a direção a partir do player capturada do ponto de spawn). A
  **Criatura Alada** também teve a oscilação de voo dessincronizada entre instâncias.
- **HUD do inimigo** — a *boss bar* compartilhada no topo da tela mostra nome, vida e distância do
  inimigo e, quando ele possui um mecanismo de ataque/tiro, também o **alcance da arma em metros**.
  Aparece ao **mirar no inimigo** e some assim que a mira sai dele; a mira reconhece tanto o corpo
  quanto os **colliders de membro/sub-membro** — então apontar para um **sub-membro saliente**
  (ex.: as placas das pernas) também exibe a vida do inimigo.
- **Dano localizado** — colliders 3D nativos por membro dimensionados pela malha de cada
  personagem, então acertos em partes diferentes causam dano diferente (headshots causam dano
  extra). Os membros vêm do **plano corporal** do modelo, escolhido por um `body_type`
  (**bípede** = cabeça/tronco/2 braços/2 pernas — o padrão; **quadrúpede** = cabeça/tronco/4
  pernas; **rastejante** = só cabeça/tronco), classificados pela hierarquia `BodyParts` via a
  factory `BodyPlans`. Os tiros atravessam o collider de corpo genérico e acertam os colliders de
  membro. **Sub-membros** — peças salientes que ganham um collider PRÓPRIO em caixa (ex.: as
  **placas traseiras das pernas** do Red Robot e as **placas de ombro** do Player, que a cápsula
  do membro não cobriria) — agora são **editáveis na tela Models** (adicionar/remover + um bônus %
  cada), não mais hardcoded; cada peça é agrupada e rotulada sob o membro a que pertence pelo nome
  (ex.: "PLACA BRAÇO E", "PLACA PERNA D"), mesmo quando está presa a outro osso no esqueleto. O
  multiplicador por membro é **por modelo e editável na tela Models**, numa **janela flutuante
  arrastável** (barra de título + **×**, estilo Windows) com uma **ÁRVORE (Tree)**: cada membro é um
  galho, seus sub-membros são folhas sob ele (ex.: "↳ PLACA BRAÇO E" sob "BRAÇO E"). Colunas:
  Nome | Definir (check) | Bônus % | Dono; cada folha de sub-membro tem um **botão de lixeira à
  direita do nome** para removê-la ali mesmo (com diálogo de confirmação; no lugar do antigo botão
  "Remover sub-membro" do rodapé). **Nenhum valor é obrigatório** — sem valor próprio um
  sub-membro **herda o do membro-dono**, depois o default do plano. O **dono** é escolhido
  **explicitamente** (agrupamento só lógico — não altera a malha; reassociar pede confirmação).
  Tudo é salvo em **um arquivo por modelo, na pasta do próprio modelo**
  (`library3D/<cat>/<modelo>/limb_config.json` — valores de dano, afastamentos/escalas + a relação de
  dono/herança de cada sub-membro; como o `res://` é somente-leitura no `.exe` exportado, edições no
  jogo vão para um override gravável `user://limb_config/<modelo>.json` que tem precedência na leitura;
  migra do antigo `data/limb_config/<key>.json` / combinado `data/limb_config.json`) e lido em
  runtime via `LimbConfig`; o multiplicador default vem do plano corporal (cabeça +50%, resto ×1). As
  formas dos colliders são por modelo — ex.: o **red_robot** usa **tronco esférico** e **cabeça com
  volume maior** (`torso_shape`/`head_scale` em `LimbColliders`).
- **Tiro reutilizável** — o disparo de bala de canhão e o de laser hitscan foram isolados em
  componentes reutilizáveis (`CannonShooter` / `LaserShooter` em `effects_shared/`) que qualquer
  modelo pode usar; player e Red Robot disparam via `CannonShooter`. O transform do cano da bala é
  fixado **antes** de ela entrar na árvore, então o spawn replicado nasce exatamente na arma nos
  clientes remotos (sem deslocamento para fora do cano); e a raycast de mira agora **exclui o próprio
  corpo/membros do atirador** e ignora acertos colados, então mirar-e-atirar rápido não manda mais
  o tiro para o céu.
- **Várias fases** — uma arena simples (Level 1), um encontro com o bombardeiro (Level 2), uma
  fase completa e complexa (Level Base), além do **jogo online por salas**: a tela **Jogar Online** tem
  dois botões que escolhem o papel. **Gerenciar Salas** abre o gerenciador de salas
  (`host_session`), onde inicia um ou mais levels como salas isoladas e, por sala, **Jogar** (após o
  seletor de personagem, nasce nela como player), **Observar** (câmera livre sem colisão), **Reiniciar**
  ou **Parar** — ambos mandam um **aviso DISTINTO aos clientes daquela sala**: **Parar** encerra a sala e
  os manda de volta ao navegador com "O nível foi parado pelo host"; **Reiniciar** recarrega o nível do
  zero e avisa "O nível foi reiniciado pelo host" (a sala recriada reaparece na lista para reentrar).
  Após um reinício o host fica na grade de gerência com o mouse livre (igual a iniciar um level).
  **Entrar em Salas** abre o navegador de salas (`client_session`), que lista as salas
  em execução com um botão **Jogar** (só aparece enquanto houver sala) que leva à sala escolhida após o
  seletor de personagem. A variante/cor escolhida por cada jogador aparece para todos online (loadout
  por peer), e os outros players/inimigos são suavizados por um **buffer de interpolação com snapshots
  datados** — visão do cliente sem flicker e com FPS alto. A tela Jogar Online tem ainda um seletor de
  **Otimização** aplicado antes de hospedar/entrar: interpolação **Suave / Equilibrado / Responsivo**
  (atraso de render 100 / 60 / 35 ms — suavidade × resposta), **taxa de sincronização 30 / 60 Hz**
  (updates servidor→cliente por segundo) e **render do host Janela / Servidor puro** (sem renderizar as
  salas, libera a GPU). Todos os modelos dinâmicos (players, inimigos, balas, bombas) sincronizam a
  partir do servidor host. A tela Jogar Online persiste todas as opções (última Porta/IP, interpolação,
  taxa de sync, render do host) e as recarrega na próxima vez; o dropdown de **IP/Domínio** lista os
  endereços recentes **e os domínios completos salvos** (FQDN guardados à parte, sem rolarem com os
  IPs recentes) para reusar pela seleção; as telas Host/Client são em tela cheia,
  no padrão do resto da UI.
- **Biblioteca + visualizador de modelos 3D** — assets 3D reutilizáveis organizados por tipo em
  `library3D/`, navegáveis no jogo pela tela Models (categoria → modelo → parte) com toggles, nesta
  ordem, de rotação, **Animação**, **Efeitos especiais** (tudo ligado ao modelo que nenhum outro
  toggle cobre — partículas, luzes, malhas de laser/clarão presas a ossos), **Áudio** (todo som que
  o modelo emite — movimento, motor, tiros, explosões, vozes), **Colisores de Membro** (com o toggle
  ligado e um membro/sub-membro isolado, exibe o gizmo verde daquele collider), **rótulos de membro**
  (toggle próprio do browser para as tags "Membro: …" sobre cada collider, independente da tela
  Debug 3D — com, logo abaixo do toggle **Membro**, um toggle **Esqueleto** que faz flutuar o rótulo
  "Esqueleto: \<nome\>" do osso avulso escolhido sobre ele, e as linhas extras Tipo/Nome/ID), **Colisores de Esqueleto** (no modo "Todos os membros" → filtro "Esqueleto", destaca com uma
  caixa translúcida a região do osso avulso escolhido, ou de todos), **Submembros** (rótulo flutuante
  "Submembro: \<nome\>" sobre o sub-membro escolhido no dropdown) e **Colisores de Submembros** (mostra
  só o limbcollider do sub-membro selecionado). Os seletores são **três
  dropdowns** — **Membro**, **Sub-membro** (logo abaixo, com a opção **"Todos os Sub-membros"** para ver todos de
  uma vez) e, só no modo **"Todos os membros"**, **Esqueleto** (ossos avulsos), que fica abaixo de Sub-membro.
  Ao escolher um item **real** (não "Selecione…"/"Todos") em qualquer um dos três, aparece **à direita** um
  **dropdown de geometria do collider** (Esfera/Caixa/Cápsula) e abre-se uma **janela flutuante reutilizável**
  (a `FloatingWindow` dos controles2D) com **Afastamento, Rotação (graus) e Escala** X/Y/Z, intitulada com o nome do item:
  cada mudança **persiste na hora**, aparece no modelo e é **relida quando um personagem entra em cena**. Todo
  dropdown de geometria segue a mesma regra: **carrega a última escolha salva**; **sem escolha, autodetecta** a
  forma pelo formato da peça (alongado → cápsula, redondo → esfera, senão caixa); e **"Selecione…" = sem
  limbcollider**. "Selecione…" num **membro** remove o collider dele; num **sub-membro** **suprime** o collider
  mas **mantém o sub-membro** na árvore/dropdown de Dano para reconfigurar (a remoção total fica na lixeira). Para
  um **osso avulso** (Esqueleto), a forma escolhida só **previsualiza** o collider via o toggle **"Colisor de
  Esqueleto"** e "Selecione…" o esconde; o osso **não** é promovido a sub-membro (a promoção segue na janela de
  Dano, em "Adicionar sub-membro"), e esqueletos não têm dano, então são **ignorados nas cenas de level**. Quando
  um **sub-membro** específico está escolhido, o dropdown de geometria do **membro** fica oculto (vale o do
  sub-membro). Os colliders de membro só aparecem com
  **Membro = "Todos os membros"** (em "Modelo completo"/"Selecione…" nenhum aparece). A **tela de Dano** não
  fica na lista de toggles: é aberta pelo **botão "Dano"** (à direita do botão "Voltar") — uma **janela flutuante
  arrastável** de fundo preto opaco (barra de título "Dano" + botão × para fechar) com uma **árvore** do bônus %
  de cada membro/sub-membro, onde também se adicionam/removem colliders salientes `PART_*` (que **mantêm o nome
  original** do osso ao serem adicionados a um membro-dono) e se define o **membro-dono** de cada um. Cada toggle é o interruptor mestre da sua categoria (nenhum som/animação toca
  enquanto o toggle estiver desligado, inclusive som disparado por trilhas de animação) e os estados
  dos toggles são persistidos entre visitas (exceto o painel de dano, que abre fechado — mas a
  **última posição** da janela de dano é lembrada e restaurada na reabertura). Uma
  animação só roda quando **o toggle está ligado E um clip está escolhido** no dropdown
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
  até 180° nos dois eixos (a rotação **congela** enquanto o ponteiro está sobre uma janela
  flutuante — Dano/IA ou outra — e volta a responder ao sair dela ou fechá-la). Um **gizmo de eixos
  3D** (estilo editor: X vermelho, Y verde, Z azul, com bola e letra na ponta) fica no **topo à
  direita** — num SubViewport próprio sobreposto, à esquerda dos toggles, sem cobrir o modelo — e
  **gira junto com o modelo**, indicando sua orientação. Alternar qualquer opção age no preview ao vivo, no lugar — nunca recarrega
  o modelo nem altera a câmera/rotação. Para Personagens e Armas, uma **pilha de tooltips de membro**
  flutua sobre o collider de cada membro: cada linha tem **cor própria** (Membro = azul-ciano, Tipo =
  laranja, Nome = verde, ID = amarelo), **a mesma cor aplicada ao toggle** que a liga, e as pilhas de
  membros diferentes **não se sobrepõem** — quando colidiriam na tela, uma é empurrada para outra
  posição (cada conjunto fica inteiro, "um abaixo do outro"). Controladas pelos toggles
  **próprios** da tela Models (Membro + toggles Tipo/Nome/ID) — a cena Models está **totalmente
  desacoplada** do overlay de **Debug 3D** global (seu nó raiz está no grupo `no_debug_overlay`),
  então o Debug 3D só afeta os **levels do jogo** (o Debug 2D agora vale em todas as telas). O nome
  da cena aparece pelo **watermark global** no canto inferior esquerdo (de `debug_overlay.gd`); o
  rótulo LOCAL antigo fica oculto (não é exibido na janela de dano). Personagens com skin são
  enquadrados/centralizados pelos colliders posados para girarem no lugar em vez de derivar, e os
  modelos abrem **de frente para a câmera** (player e red_robot, exportados com a frente em +Z, já
  iniciam mostrando o rosto, sem precisar rotacionar).
- **HUD cyberpunk & widgets 2D** — um conjunto de controles de UI reutilizáveis (HUD, minimapa,
  vitais, mira, menu de pausa, scanlines e mais).
- **Ferramentas de debug** — veja [Tela developer & overlay de debug](#tela-developer--overlay-de-debug).
- **Localização (EN/PT)** — veja [Localização](#localização-enpt).
- **Configurações** — veja [Configurações](#configurações).

## Tela developer & overlay de debug

Um overlay de debug global (`autoload/debug_overlay.gd`, autoload **DebugOverlay**) é ligado pela
tela **developer** e pela aba "Debug" das configurações. Todos os toggles persistem nas
configurações salvas (seção `game`) e aplicam na hora (`DebugOverlay.refresh()`). Cada par
Desativado/Ativado usa o **mesmo estilo de botão colorido da tela Settings**: a opção **selecionada**
mostra a cor autorada cheia (verde/amarelo) e a **não selecionada** fica **escurecida** (uma sub-linha
desativada — com o master Debug 2D desligado — fica acinzentada em vez disso).

A tela developer organiza os toggles em **duas colunas**, cujos tooltips usam cores claras
distintas para você diferenciá-los:

- **Debug 2D** (rótulos/tooltips amarelo claro) — master `debug_2d` mais os interruptores
  dependentes `Type` / `Name` / `Id` / `Tab`. Controla o overlay 2D (uma borda colorida + um tooltip
  TYPE/Name/ID/TAB) em cada `Control`. Os tooltips 2D aparecem em **todas as telas, sem exceção** —
  inclusive Models e o editor de Dano (que saem do overlay **3D** via `no_debug_overlay`) — e
  também sobre o **rótulo do nome da cena** no canto inferior esquerdo. A linha **Tab** (branca,
  `show_tab`) mostra o **índice de Tab/foco** de cada controle na cena 2D ativa (`-` para
  controles não focáveis).
- **Debug 3D** (rótulos ciano claro) — master `debug_3d` mais os dependentes `Type` / `Name` /
  `Id` (descrevendo o nó `Skeleton3D`), `Members`, `Skeleton` e `Mesh`. Renderiza rótulos
  `Label3D` por membro que seguem a pose viva.

Regra de dependência: o master de uma coluna estar ligado **não basta** — cada linha/recurso
dependente só passa a valer quando _também_ selecionado, em sincronia com seu master. Quando o
master de uma coluna está desligado, **as sub-linhas inteiras** (o rótulo da linha mais os botões)
ficam desativadas e escurecidas (acinzentadas). Quando o master está ligado mas nenhuma linha dependente está selecionada, a
coluna não mostra nada (a borda e os tooltips 2D só aparecem quando ao menos um de Type/Name/Id/Tab
está selecionado; os rótulos 3D ficam ocultos até seus sub-toggles serem selecionados).

Os extras de **Debug 3D** são: **Members** (rótulos por membro CABEÇA/TRONCO/BRAÇO… pelo mesmo
classificador `BodyParts` usado pelos colliders de dano localizado), **Skeleton** (linhas brancas
de osso refeitas todo frame a partir da pose viva) e **Mesh** (caixa wireframe ciano do AABB de
cada MeshInstance3D).

Ao lado da coluna Debug 3D, uma **pré-visualização do modelo do player** (mesma altura das colunas)
renderiza o robô do player em um `SubViewport` próprio (com `World3D`, câmera e luz próprios),
girando lentamente com sua animação idle. Como o modelo do preview fica **fora** do grupo
`no_debug_overlay`, o `DebugOverlay` global o varre como qualquer outro esqueleto, então os toggles
de **Debug 3D** (Skeleton / Mesh / Members / Type / Name / Id) se aplicam a ele ao vivo — clicar
qualquer botão ativado/desativado mostra o efeito no robô na hora.

Acima das colunas, uma seção geral tem **HUD FPS** (`hud_fps`), **Monitor de Saúde**
(`performance_hud`, rótulo da linha na tela developer para o Performance HUD; veja abaixo) e **Malha no Solo** (`show_grid`) — uma grade wireframe de
100 m × 100 m na origem, em qualquer tela que contenha conteúdo 3D (Modelos 3D, fases). Como o
`main.gd` troca as telas como filhas do nó `Main` (então `current_scene` permanece sempre `Main`,
um `Node` comum), o grid detecta a tela carregada ativa e procura qualquer descendente `Node3D` em
vez de checar o tipo da raiz; ele some nas telas puramente 2D (menu/configurações/developer).

## Indicadores de performance (Performance HUD + StabilityGuard)

Dois autoloads complementares, ambos lendo **só** do singleton `Performance` do Godot (métricas
internas da engine, confiáveis e multiplataforma). Substituíram o antigo monitor único "System Health".

**StabilityGuard** (`autoload/stability_guard.gd`) é uma rede de segurança contra crash/freeze,
**sempre ligada** (sem toggle). A cada 0,5 s classifica em três estados e age na transição: `NORMAL`
(física a 60 ticks/s), `THROTTLE` (física cai para 30 ticks/s + sinal de aviso) e `EMERGENCY`
(`get_tree().paused = true` + overlay de tela cheia, dispensável com **ESC**). Monitora cinco
indicadores de risco real: **RAM física livre do sistema** (`OS.get_memory_info()` — age quando a RAM
livre cai abaixo dos limites; antes usava `MEMORY_STATIC`, que fica 0 no `.exe` em release e nunca
disparava), **VRAM** (`RENDER_VIDEO_MEM_USED`), **collision pairs** (`PHYSICS_3D_COLLISION_PAIRS`),
**contagem de nós** (`OBJECT_NODE_COUNT`) e **FPS** (`TIME_FPS`, detecção de loop travado). Cada limite é um `@export`. Emite `state_changed` /
`throttle_activated` / `emergency_activated` / `recovered`, e o overlay roda em `PROCESS_MODE_ALWAYS`
(vive durante a pausa).

**Performance HUD** (`autoload/performance_hud.gd` + `scenes2D/overlays/performance_bar.gd`) é uma
barra-overlay global no topo, ligada/desligada pela linha **Performance HUD** da tela developer
(`game/performance_hud`, padrão desligado). É **click-through** (só o botão do toggle captura o mouse)
e fica ociosa quando oculta. O modo **básico** mostra `FPS | NET | RAM | CPU% | GPU% | ● badge do
StabilityGuard` (CPU% por `TIME_PROCESS`, GPU% um proxy de draw calls; **NET** mostra o **ping**
(RTT) do ENet — cliente→servidor, ou a média dos clientes no host, colorido por latência; funciona
através de túneis UDP como o playit.gg e só degrada para **N/D** quando offline; **RAM** = memória do **sistema** em "usado/total
GB" via `OS.get_memory_info()` — funciona em release, onde `Performance.MEMORY_STATIC` ficaria 0). O
modo **avançado** (toggle ▼/▲) acrescenta colunas por categoria — CPU (processo/física/carga/nós/
objetos/corpos 3D/collision pairs), GPU (draw calls/triângulos/VRAM/mem. de textura) e Memória (RAM do
sistema/resources) — cada valor colorido por limiar.

> Nota: substituir o System Health abriu mão do CPU real por processo dele (thread PowerShell
> `Get-Process`) e do bip de pico crítico; o CPU% do HUD é um proxy por tempo de frame.

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
  **Português** / **English** (o mesmo padrão do menu), **alinhada à altura do botão "Voltar"**,
  está presente em menu, chooseplayer,
  settings, developer, levels, playonline, controls e models. Pressionar um chama
  `Locale.set_language(...)`, que persiste a escolha e re-localiza a árvore viva no lugar (o botão do
  idioma ativo fica acinzentado).
- **Textos vindos de código** (linhas de status dinâmicas, placeholders de dropdown, os títulos das
  abas de configurações e diálogos de confirmação, o Performance HUD e o overlay do StabilityGuard) não são alcançados pelo
  localizador automático de Button/Label, então esses nós entram no grupo `Locale.SKIP_GROUP` e
  reaplicam `Locale.tr_key(...)` sozinhos no sinal `language_changed`.

**Regra de manutenção:** sempre que alterar ou adicionar um texto de UI numa cena, atualize a chave
correspondente em **ambos** `Resources/<cena>.pt.json` e `.en.json` da cena na mesma mudança (PT
recebe o texto em português, EN o em inglês) e valide os dois JSON. Como o Locale indexa pelo
texto-fonte, mudar a cena sem atualizar a chave quebra a tradução.

## Configurações

A tela de configurações tem abas — na ordem **`Resolution`, `Display`**, `Antialiasing`,
`Lighting`, `Effects`, `Audio` — com uma **faixa de abas com metade da altura** (fonte das abas 15)
e um ritmo vertical consistente (espaçamento de linhas/seções igual a 8). Os títulos das abas também são localizados (vêm dos nomes dos nós-filhos, então o Locale
os traduz em código). A maioria das linhas é um conjunto de botões toggle que compartilham um
gradiente verde → amarelo → laranja → vermelho lido como barato → caro (ex.: performance vs.
qualidade), com o botão verde sendo a opção segura/leve. O botão **ativo** (selecionado) fica
**aceso** — fundo claro com borda branca e brilho — enquanto as opções **não selecionadas** ficam
**bem menos iluminadas** (escurecidas), realçando ainda mais a escolha atual.

- **Resolution** — um dropdown de resolução de vídeo (tingido de ciano claro para marcá-lo como
  seletor; com **largura mínima ajustada ao maior item** para nenhum texto ser truncado), escala de
  resolução e o filtro de escala (Bilinear / FSR / MetalFX…).
- **Display** — Modo de exibição (Window / Fullscreen / Exclusive Fullscreen), Sincronização
  Vertical e Limite de FPS (30…144 / Unlimited). Os botões de modo e de limite de FPS são coloridos
  pelo mesmo gradiente (limite maior = mais exigente = cor mais quente). No modo **Window** a janela
  é uma **janela normal do SO**: ao entrar nela, é redimensionada para a resolução salva e
  centralizada, ficando arrastável pela barra de título (não mais presa do tamanho da tela cheia).
- **Antialiasing** — TAA, MSAA e FXAA.
- **Lighting** — Shadow Mapping, Tipo/Qualidade de GI, SSAO e SSIL.
- **Effects** — Bloom e Volumetric Fog.
- **Audio** — controles independentes para **Música** de fundo (o bus `Music`) e **Efeitos de Som**
  (o bus `SFX`, para onde os buses de gameplay `Outside`/`Reactor` são roteados), cada um salvo e
  aplicado globalmente. A **música de fundo é por cena/level**, conduzida pelo autoload **MusicManager**
  em **loop infinito**, trocando a cada tela (ver `Audios/README.md`). Por padrão, uma cena fica em
  **"Selecione…" = silêncio** (sem música) até você atribuir uma faixa. Ao clicar em **Música → Enabled**
  abre o **Gerenciador de Música**: ouça qualquer faixa e **atribua** a cada cena/level uma faixa
  específica, **"Padrão"** (resolve pelo nome da cena, `Audios/<nome>.<ext>`) ou **"Selecione…"** (silêncio);
  as atribuições são persistidas. Cada botão **▶ Tocar** tem ao lado um **⏸ Pausar** e um
  **⏹ Parar** (tanto na linha "Ouvir faixa" quanto na lista por cena); um botão **🎲 Sortear faixas** sorteia uma faixa
  aleatória para cada cena/level e salva para a próxima abertura. À direita de cada linha (**Música** e **Efeitos de
  Som**) há um **controle de volume tipo equalizador** (`VolumeBar`, 10 segmentos coloridos em
  gradiente): com o áudio ligado, clique/arraste para ajustar o volume daquele bus de **1 a 100**.

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

## Build Windows (executável + atalho no Desktop)

Para gerar um executável Windows independente e um atalho no Desktop, rode:

```powershell
pwsh -File build_windows.ps1
```

Ele exporta `build/windows/ZIMARO.exe` (release, **PCK embutido** → um único arquivo
autocontido de ~589 MB) pela CLI headless do Godot 4.6.2 e (re)cria um atalho **ZIMARO** no
Desktop usando `build/icon.ico` (rasterizado uma vez a partir do `icon.svg`). Requer Godot 4.6.2 +
os export templates instalados; o `.ico` é gerado só na 1ª execução (precisa de Python 3 com
Pillow) e reusado depois. A pasta `build/` e o `export_presets.cfg` são ignorados pelo git.

Antes de exportar, o script **encerra automaticamente** qualquer instância aberta do `ZIMARO.exe`
(e limpa um `.tmp` órfão), evitando o erro *"Failed to rename temporary file"* quando o jogo está
rodando — isso só acontece quando há de fato um rebuild (turnos sem mudança são pulados).

O **boot splash** abre numa tela **preta sem o logo do Godot** (`application/boot_splash/show_image=false`
+ `bg_color=preto` + `minimum_display_time=0` no `project.godot`), então a janela só aparece escura
até o menu carregar — sem a marca-d'água da engine.

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
  nativos por membro para dano localizado), `limb_config.gd` (`LimbConfig` — store dos
  multiplicadores de dano + sub-membros + donos + afastamentos/escalas de collider, **um arquivo por
  modelo na pasta do próprio modelo** `library3D/<cat>/<modelo>/limb_config.json`, com override gravável
  em `user://` para edições no jogo), a **hierarquia de
  planos corporais** `body_parts.gd` (base `BodyParts` + subclasses
  `body_parts_biped/quadruped/crawler.gd`, classificação osso → membro) e `body_plans.gd` (factory
  `BodyPlans`), e assets de blast/sombra compartilhados.
- `autoload/` — singletons globais: `crash_handler.gd`, `player_selection.gd`, `debug_overlay.gd`,
  `locale.gd`, `stability_guard.gd`, `performance_hud.gd`, `music_manager.gd` (música de fundo por
  cena/level, em loop infinito). O `Settings` fica em `scenes2D/settings/config.gd`.
- `<cena>/Resources/*.pt.json` + `*.en.json` — dicionários de idioma da UI por cena, varridos e
  mesclados pelo autoload `Locale`.
- `themes/` — recursos de tema compartilhados.
- `OBSIDIAN/` — cofre de documentação do projeto (espelha este README).

Fluxo de telas:

```
menu ─┬─ Jogar Offline ─► chooseplayer ─► levels ─► level_1 / level_2 / level_base
      ├─ Jogar Online ──► playonline (Gerenciar Salas / Entrar em Salas)
      │                    ├─ Host ───► host_session   (inicia salas; por sala: Jogar / Observar / Reiniciar / Parar)
      │                    └─ Client ─► client_session (navega salas; por sala: Jogar)
      │                                   └─ Jogar ─► chooseplayer ─► nasce na sala escolhida
      ├─ settings
      ├─ developer ──┬─ models    (visualizador de modelos 3D da library3D)
      │              └─ controls  (visualizador de controles 2D dos widgets controls2D)
      └─ quit
```

`main.gd` é o roteador: cada tela emite `replace_main_scene` e o `main` a troca, então os botões de
voltar (e <kbd>Escape</kbd>) navegam para a tela anterior do mesmo jeito. Toda tela 2D dá um foco
inicial ao entrar para as **setas do teclado** navegarem entre seus botões (helper compartilhado
`UINav`, autoload). O <kbd>Escape</kbd> segue uma regra única em todas as telas: primeiro **cancela
o preenchimento de um campo em edição** (um `LineEdit`/`SpinBox` em foco — ex.: o IP/porta do online)
e só um segundo toque sai da tela; no `menu` ele abre uma **confirmação "Deseja sair do Zimaro ?"**
(Sim/Não) em vez de sair direto. A tela `settings` aplica e
persiste cada mudança na hora e o `menu` reaplica todas as configurações salvas ao entrar. A tela
`developer` e a aba "Debug" das configurações controlam o `DebugOverlay`, e a linha "Performance HUD"
da tela developer controla o overlay `PerformanceHUD` (e o `StabilityGuard` roda sempre-ligado).
O autoload `Locale` troca o idioma da UI
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
│  ├─ playonline/        # entrada online: papel Host/Client → gerenciador/navegador de salas
│  ├─ host_session/      # servidor: gerenciador de salas (inicia + Jogar/Observar/Reiniciar/Parar por sala)
│  ├─ client_session/    # cliente: navegador de salas (Jogar numa sala em execução)
│  ├─ controls/          # visualizador de widgets 2D (análogo da tela Models)
│  └─ controls2D/        # widgets de HUD reutilizáveis: crosshair, minimap_panel, vitals_panel, volume_bar, …
├─ scenes3D/             # fases e ferramentas 3D
│  ├─ level_1/ level_2/ level_base/   # fases jogáveis
│  ├─ spectator_camera/  # câmera livre sem colisão para Observar uma sala (host) — WASD + Espaço
│  └─ models/            # visualizador/inspetor de modelos 3D da library3D
├─ library3D/            # biblioteca de assets 3D, organizada por tipo
│  ├─ characters/        # players + inimigos
│  ├─ propulsores/       # props de propulsão (forklift)
│  ├─ structures/        # estruturas estáticas (door, core, lights, props, structure)
│  ├─ weapons/           # armas (pistola_infantil, bomb)
│  ├─ geometry/          # malhas/materiais compartilhados (.tres)
│  └─ textures/          # texturas compartilhadas
├─ Audios/               # trilhas de fundo por cena/level (loop infinito; ver Audios/README.md)
├─ effects_shared/       # helpers entre personagens: limb_colliders.gd, body_parts.gd, …
├─ autoload/             # singletons: crash_handler, player_selection, debug_overlay, locale, stability_guard, performance_hud, music_manager
│                        #   (Settings fica em scenes2D/settings/config.gd)
│                        # dicionários da UI por cena: <cena>/Resources/*.pt.json + *.en.json (lidos pelo Locale)
├─ themes/               # recursos de Theme compartilhados (ui_theme.tres, cyberpunk.tres)
├─ addons/               # plugins do editor Godot (godot_ai — o servidor MCP)
├─ OBSIDIAN/             # cofre de documentação do projeto (espelha este README)
├─ screenshots/          # imagens de preview capturadas
└─ project.godot · default_bus_layout.tres · file_format.sh   # config do projeto · buses de áudio · formatador
```

## Blocos nativos do Godot

Tudo no jogo é construído com **nós e recursos NATIVOS do Godot** — não há nó custom em
C++/GDExtension. As únicas abstrações próprias são helpers `RefCounted` de lógica pura, **sem nó**
(`BodyParts` e suas subclasses de plano corporal + a factory `BodyPlans`, `WeaponParts`,
`LimbConfig`, `LaserShooter`, `CannonShooter`), que apenas orquestram nós nativos. Por subsistema:

- **Física & colisão:** `StaticBody3D`, `CharacterBody3D`, `RigidBody3D`, `Area3D`,
  `CollisionShape3D` (e `BoxShape3D`/`CapsuleShape3D`/`SphereShape3D`/`CylinderShape3D`), `RayCast3D`.
- **Malhas & geometria:** `MeshInstance3D`, `ArrayMesh` e primitivas (`BoxMesh`, `CylinderMesh`,
  `SphereMesh`, `PrismMesh`…).
- **Esqueleto & animação:** `Skeleton3D`, `BoneAttachment3D`, `Skin`, `AnimationPlayer`,
  `AnimationTree`, `SkeletonModifier3D`.
- **Câmera, luz & ambiente:** `Camera3D`, `SpringArm3D`, `Marker3D`, `DirectionalLight3D`/
  `OmniLight3D`/`SpotLight3D`, `WorldEnvironment`, `Sky`.
- **Partículas & materiais:** `CPUParticles3D`, `GPUParticles3D`, `StandardMaterial3D`, `ShaderMaterial`.
- **Áudio:** `AudioStreamPlayer3D`, `AudioStreamPlayer`, `AudioStream`/`AudioStreamWAV`,
  `AudioStreamRandomizer`.
- **Rede:** `MultiplayerSynchronizer`, `MultiplayerSpawner`, `SceneReplicationConfig`.
- **UI 2D (árvore `Control`):** `Button`, `Label`, containers, `OptionButton`, `ProgressBar`,
  `CanvasLayer`, `Theme`.

O sistema de hitboxes por membro é o exemplo canônico: `limb_colliders.gd` é um `Node3D` comum que
**monta** `StaticBody3D` + `CollisionShape3D` + `BoneAttachment3D` nativos. A nota do Obsidian
[`recursos-nativos-godot`](OBSIDIAN/CLAUDE/sistemas/recursos-nativos-godot.md) traz o inventário completo.

## Controles

- Mouse ou <kbd>Analógico direito do gamepad</kbd>: Olhar ao redor
- <kbd>W</kbd>/<kbd>A</kbd>/<kbd>S</kbd>/<kbd>D</kbd>, <kbd>Setas</kbd>, <kbd>Analógico esquerdo</kbd> ou <kbd>D-Pad</kbd>: Mover
- <kbd>Espaço</kbd>, <kbd>Gamepad A/Cross</kbd>: Pular
- <kbd>Botão direito do mouse</kbd>, <kbd>Gatilho esquerdo (L2)</kbd> (pressione p/ alternar, ou segure e solte): Mirar
- <kbd>Botão esquerdo do mouse</kbd>, <kbd>Gatilho direito (R2)</kbd>: Atirar (apenas mirando)
- <kbd>Setas</kbd> / <kbd>D-Pad</kbd> (nos menus): Mover o foco entre os botões
- <kbd>Escape</kbd>, <kbd>Gamepad Start</kbd>: Cancela um campo em edição, senão volta / vai ao menu principal (o menu pede confirmação para sair)
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
