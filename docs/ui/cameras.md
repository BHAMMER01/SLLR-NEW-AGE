# Câmeras no SLRR New Age: arquitetura, fluxo e ciclo de vida

Este documento descreve como as câmeras são representadas pelo jogo, como os
scripts as selecionam, como o host mantém suas poses e como o renderer escolhe
e desenha cada vista. Ele separa o comportamento observado nos scripts
decompilados do comportamento implementado pelo New Age. Os arquivos citados
são a referência executável: valores e atalhos devem ser rechecados no checkout
antes de mudanças.

## Escopo e termos

No jogo, “câmera” pode significar quatro coisas diferentes:

1. **Modo Track**: estado de `java.game.Track` (`cameraMode`, `cameraNum`,
   `cameraTarget`, `cameraTarget2` e `renderer`).
2. **Objeto `java.render.Camera`**: pose, alvo, viewport, prioridade, lente e
   estado de atualização mantidos por `GameRefState`.
3. **Câmera interna do carro**: uma pose `camera` do CFG aplicada ao chassis;
   o host cria um objeto de câmera sintético para apresentá-la.
4. **Vista do renderer**: a câmera de mundo que o `bgfx` escolhe para o passe
   principal, distinta de câmeras de preview, mapa e interface.

Uma câmera só aparece como vista principal se os quatro níveis concordarem:
o script precisa selecionar o modo, o objeto precisa estar ativo, o viewport
precisa estar válido e a câmera precisa pertencer ao mundo selecionado.

## Mapa do código

| Responsabilidade | Código principal |
| --- | --- |
| Estrutura e campos comuns de câmera/viewport | `include/slrr/gameref.hpp`, `GameRefState` |
| Registro, aliases, remoção, comandos `render/look/move/...`, escolha da câmera principal e pose | `src/resources/gameref.cpp` |
| Parse das poses `camera` no CFG | `src/resources/part_config.cpp`, `PartConfig::cameras` |
| Pose de chassis, câmera interna e personagem | `src/resources/part_runtime.cpp`, `part_camera_pose` |
| Comandos do chassi `render`/`hide` e objeto `_hostCockpitCamera` | `src/resources/part_runtime.cpp`, `part_command` |
| Modos de pista, seleção dos alvos e câmera de TV | `build/decompiled/Track/java/game/Track.java` |
| Atalhos New Age, ciclo C, voo, entrada/saída do personagem | `src/platform/host_input.cpp` |
| Ordem de atualização da pose no frame | `src/boot/mainloop.cpp` |
| Câmeras de preview, passe principal, matriz BGFX, cursor e fotos | `src/render/bgfx_lib_backend.cpp` |
| Construção e submissão da vista do mundo | `src/boot/mainloop.cpp`, `src/render/` |

## Estado comum (`GameRefState`)

`GameRefState` é a união de estado usada pelo host para objetos de várias
classes. Para câmeras, os campos importantes agrupam-se assim:

- **Identidade e seleção**: `kind`, `key`, `parent`, `binding`, `live_id`,
  `cam_active`, `cam_seq`, `cam_pri`, `viewport`.
- **Lente e recorte**: `half_aov`, `aov_goal`, `aov_rate`, `dmin`, `dmax`,
  `fog_set`, `fog_color`, `fog_near`, `fog_far`.
- **Alvo fixo/scriptado**: `move_id`, `look_id`, `move_off`, `look_off`,
  `aim_move`, `aim_look`, `move_dist`, `cam_height`, `cam_height_set`.
- **Seguimento de veículo**: `follow_vehicle`, `follow_variant`,
  `cockpit_index`, `camera_attached`, distância e parâmetros de mola,
  amortecimento, suavização e retenção.
- **Órbita e animação**: `orbit_yaw`, `orbit_pitch`, `orbit_roll`, `pos`, `ypr`,
  `eye_s`, `look_s`, velocidades e flags de inicialização.
- **Modos New Age**: `camera_free`, `camera_on_foot`, `camera_mode_override`.

Esses campos não são todos válidos em todos os tipos. Em particular,
`cockpit_index >= 0` exige um alvo veicular com array de câmeras no CFG; um
`RenderRef` do personagem não tem esse array. `camera_free` troca a câmera
acompanhada por uma pose livre. `camera_on_foot` mantém o objeto principal,
mas muda a semântica do alvo para o personagem.

## Como objetos de câmera nascem, ativam e morrem

### Câmera de script (`java.render.Camera`)

O construtor nativo `Camera.create` registra o objeto no GameRef, define pai,
viewport, prioridade, campo de visão e planos near/far, e o deixa ativo.
`Camera.activate(viewport, priority)` ativa ou reativa o objeto; `deactivate`
desativa-o; `destroy()` chama `gameref_remove` e remove seu registro, live ID,
relação com pai e participação na lista de câmeras. A remoção de um GameRef
também desliga o registro da câmera. `gameref_clear()` limpa tudo em transições
globais de cena.

### Câmeras criadas pelos comandos de cena

`GameRef` com recurso de câmera recebe `gameref_bind_scene_camera`. O host lê
pose, parâmetros e flags de colisão; começa inativo e semeia pose/estado de
órbita. `render <viewport> ... <prioridade>` ativa a câmera naquele viewport;
`hide <viewport>` a desativa. `look`, `move`, `height`, `dist`, `smooth`,
`force`, `angle`, `zoom`, `roll`, `simulate`, `nearplane` e `farplane` alteram
alvo, dinâmica, orientação ou lente. São comandos que atualizam um mesmo
estado, não criam uma câmera nova por chamada.

### Câmera interna sintética do carro

O comando de script `chassis.command("render viewport controller index")`
é interceptado em `part_command`. Para viewport de tela cheia, o host obtém a
pose no `PartConfig::cameras[index]` e cria/reutiliza um objeto
`java.render.Camera` guardado no campo `_hostCockpitCamera` do chassis. O objeto
segue o live ID do carro, mantém `cockpit_index`, recebe parâmetros de lente e
é ativado no viewport. `hide` apenas o desativa: ele fica guardado no chassis
para a próxima troca. Quando o chassis é removido, a limpeza de seus campos
remove a câmera sintética e seus registros.

### Câmeras temporárias de Track

`Track.makeCamExternal` cria uma câmera quando não existe uma externa válida e
guarda o objeto em `cam_external`. Follow, chase e inverse-chase reutilizam
essa câmera externa; comandos subsequentes mudam seus alvos e offsets. A câmera
de TV é recriada a cada troca: `changeCamTV` chama `changeCamNone`, calcula
uma posição junto a cruzamentos do mapa, cria `track tv cam`, configura mira,
roll e zoom, e registra o timer para atualizar a tomada. `changeCamNone`
esconde o renderer atual, destrói `cam` e limpa também `cam_external` se era o
mesmo objeto. A troca de modo pode esconder sem destruir uma câmera externa que
será reutilizada.

## Modos de câmera de `Track`

Os valores vêm de `Track.java` e são diferentes das teclas físicas. A ordem do
ciclo New Age por `C` foi definida em `host_input.cpp` como interno, TV,
follow, chase, inverse-chase.

| `cameraMode` | Nome | Origem da pose e ciclo de vida |
| ---: | --- | --- |
| 0 | NONE | Sem renderer Track ativo. `changeCamNone` esconde a vista e destrói a câmera temporária `cam`. |
| 1 | FOLLOW | Câmera externa reutilizável. `Track` configura `dist`, `smooth`, `force`, `torque`, `roll`, render e associa o chassis à câmera. O host usa `follow_vehicle` e `follow_variant=0`. |
| 2 | TV | Câmera temporária colocada perto de cruzamentos e orientada ao veículo. Timer chama `changeCamTV`; cada tomada pode destruir e recriar a câmera. |
| 3 | CHASE | Câmera externa; move offset relativo ao osso/alvo secundário e mira o segundo alvo. Sem segundo alvo, cai para follow. |
| 4 | INVCH | Similar a chase, mas troca os lados dos alvos/ossos para a tomada invertida. Sem segundo alvo, cai para follow. |
| 5 | INTERNAL | `cameraTarget.getInfo(GII_RENDER)` informa quantidade de posições; `cameraNum` escolhe uma pose CFG e o chassis recebe `render`. Internamente, `changeCamInternal` percorre os índices em módulo da contagem. |
| 6 | FREE (stock Track) | Script chama `makeCamExternal`, remove o carro do controlador e vincula o controller à câmera `cam` com estado 5. É a câmera de controle do script original. Não é o voo livre New Age de Delete. |
| 7 | POINT | Câmera externa movida por osso do veículo e orientada para um ponto dado no mapa. |

F1/F2/F3/F4/F5 são os atalhos originais registrados na classe `Track` para
internal/TV/follow/chase/inverse-chase. Os comandos também podem chegar por
`Track.osdCommand`, mensagens de evento, timers (`refreshCamera`/TV), demo e
mudança de alvo. O New Age consome F1–F4 no host e usa `C` para enviar os
comandos nativos de Track; o F5 permanece disponível como olhar traseiro fora
do voo, e inverse-chase continua alcançável por `C`. Perfis de controle
salvos/menu podem introduzir bindings adicionais e precisam ser considerados
na validação de entrada.

### Câmeras internas definidas no veículo

`PartConfig::cameras` é preenchido pelo parser das linhas `camera` do CFG.
`part_camera_pose(car, index)` obtém a matriz interpolada do chassis, valida o
índice, multiplica pela pose local correspondente e acrescenta o deslocamento
de cockpit do veículo controlado quando aplicável. O valor é enviado a
`GII_RENDER`, que o Track consulta para avançar o `cameraNum`. A quantidade e
as poses variam por modelo/configuração; não há uma contagem universal segura.

No arquivo principal do carro também podem existir definições de rear-look,
espelho e `ext_camera`. Elas não devem ser automaticamente tratadas como
índices da lista Track: é o parser e o retorno `GII_RENDER` que determinam o
array interno usado por aquele veículo. O retrovisor, o olhar para trás e a
câmera externa são caminhos semânticos separados.

## Câmera do personagem a pé

Ao sair do carro (`F`), o New Age instancia um `RenderRef` do ped, guarda o
estado da câmera veicular em `OnFootCameraSave`, suspende a física do carro,
coloca o ator no mundo e passa o `follow_vehicle` do objeto de câmera ativo
para o live ID do ator. O estado salvo inclui o índice cockpit e os campos de
alvo, variantes, offsets, distância, limites, pose/órbita, attachment e hold.

`camera_on_foot` seleciona uma pose de órbita direta separada: o alvo é o frame
mundial do ped, o ponto de mira usa âncora na altura do ombro, há colisão de
câmera contra paredes e filtragem de piso/teto. Mouse modifica a órbita com
sinais próprios para yaw/pitch; não se reaproveita a convenção de sinal do voo
ou da câmera de carro. WASD/Shift/Space movimentam/correm/pulam o ped; `C` não
deve tirar a câmera dele. Ao entrar de volta no carro, o host restaura o estado
salvo e remove o RenderRef do personagem.

Estado importante: `cockpit_index` é limpo durante a órbita a pé e restaurado
no retorno, pois o ped não oferece câmeras CFG. Além da pose, o seletor da
câmera de mundo precisa resolver a propriedade do mundo pelo RenderRef seguido
quando `camera_on_foot` estiver ativo. Se olhar apenas para o objeto de câmera
ou exigir uma câmera CFG, o renderer pode ficar só com a cor de clear enquanto
HUD/minimapa continuam visíveis. Essa transição deve ser testada a partir de
cada modo, não presumida a partir do follow padrão.

## Câmera livre / drone do New Age

Delete alterna `camera_free` no mesmo objeto de câmera principal. Na entrada,
o host avalia a pose corrente, grava eye e orientação para começar sem salto,
ativa `free_camera_mode` e os controles de voo. A pose livre integra a posição
em espaço de mundo por forward/right/vertical, roda em torno do forward e usa
orientação derivada do yaw/pitch. Mouse orienta a câmera sem botão pressionado;
W/S avançam/recuam, A/D deslocam lateralmente, Shift/Ctrl sobem/descem e E/Q
rolam. Scroll percorre multiplicadores discretos de x0.01 a x512. O carro e o
personagem não devem receber controles enquanto o voo está ativo. F1 alterna
modo foto, escondendo OSD e a câmera-preview separada do minimapa. Delete outra
vez retoma o modo de câmera que ficou no objeto; o modo de voo não cria nem
destrói o objeto de câmera.

Esse fluxo é diferente de `Track.CAMMODE_FREE` (modo 6) do script original,
que associa um controller à câmera e tem regras próprias para liberar/religar o
carro. Não se deve usar o nome “free camera” sem especificar qual desses dois
fluxos está em questão.

## TV, mapa e câmeras auxiliares

- **TV de Track**: câmera temporária de mundo, alterna tomadas em resposta a
  timer e acompanha `cameraTarget`.
- **GPS/minimapa**: `Navigator.show` e o caminho ViewMap criam câmeras de
  preview próprias (viewport prioritário 12 para o mapa da cidade); elas não
  são a câmera principal da pista nem parte do desenho da HUD. Modo foto precisa
  filtrar esse passe separado.
- **Previews de catálogo/garagem/loja**: câmeras locais parentadas ao cenário
  local e limitadas ao viewport de preview. A propriedade do mundo impede que
  uma vista de inventário ou catálogo substitua o mundo da pista.
- **Câmera de showroom/seleção de carro**: órbita vinculada à seção e seu alvo;
  `spin_car_select_camera` mantém sua atualização em vez de deixar o modo Track
  sobrescrevê-la.
- **Câmera de cursor/OSD**: `Osd.show()` pode ativar uma segunda câmera de tela
  cheia para widgets. É UI e não deve ganhar a seleção principal do mundo.
- **Preview de slot/inset**: câmeras ativas em viewport secundário são
  renderizadas depois da cena principal, ordenadas pelo viewport/prioridade;
  não substituem a câmera global.

## Seleção da câmera principal e renderização

`gameref_active_cameras()` percorre o registro de objetos `Camera`, exclui
aliases, objetos inativos e câmeras cujo viewport está ausente/inativo, e ordena
por prioridade e sequência de ativação. `fullscreen_script_camera()` então
aplica filtros adicionais: propriedade do mundo da cena selecionada, viewport
compatível com a tela, exclusão de câmera OSD/cursor e regra específica para
câmera cockpit sem parent próprio. A câmera principal elegível com sequência
mais nova vence; logo, `cam_seq` e ordem de ativação são parte do comportamento.

No começo do frame, scripts e eventos podem trocar o modo. `mainloop.cpp`
sincroniza o `follow_variant` com Track (salvo override do New Age ou modo a
pé), atualiza a pose via `gameref_advance_world_camera`, e só então chama o
renderer. `world_camera_pose` prioriza: voo livre; câmera interna por matriz do
CFG; órbita a pé; pose `move/look` anexada; follow/chase; por fim a pose
genérica scriptada. Retornar `false` da pose específica não significa que o
renderer deixa de renderizar; pode haver fallback para `pos/ypr`, o que explica
vistas inválidas se o estado especializado ficou inconsistente.

BGFX converte a câmera de mundo para view/projection, aplica a região e
parâmetros do viewport, profundidade e fog. Câmeras de preview são passos
separados que coletam os objetos sob seu parent ou alvo de mira. A pose de
malhas usa a convenção de Z refletido do renderer; uma matriz ou sinal correto
no espaço do jogo pode precisar transformação correspondente antes da view.
Não “corrigir” mouse/sinal sem identificar se o valor está no espaço de input,
órbita, pose de jogo ou matriz BGFX.

## Entrada e saída: invariantes

Ao mudar de câmera, checar em conjunto:

1. `Track.cameraMode`, `cameraNum`, `renderer`, `cameraTarget` e
   `cameraTarget2`.
2. Objeto ativo escolhido, viewport, prioridade e `cam_seq`.
3. `follow_vehicle`, `cockpit_index`, `follow_variant`, `camera_attached`,
   `camera_free` e `camera_on_foot`.
4. Estado da câmera externa reutilizável ou temporária (`cam`,
   `cam_external`), incluindo se a anterior só foi ocultada ou destruída.
5. Pose do frame final e seu alvo real; validar ambos no mundo selecionado.
6. Inputs físicos, bindings de ControlSet, hotkeys Track, mensagens/eventos e
   timers; um atalho pode ser despachado por mais de um subsistema.
7. Desativação de viewports ao sair de seção e remoção de GameRefs quando o
   alvo, câmera, OSD ou seção morre.

Fluxo `carro → ped → carro`: salvar antes de reatribuir alvo; limpar índice de
cockpit para o ped; conservar o objeto/viewport da câmera principal; conferir
que a seleção usa o mundo do ped; ao retornar, restaurar todos os campos salvos
antes de destruir o RenderRef.

Fluxo `veículo → drone → veículo`: obter eye/at da pose ativa; entrar sem salto;
desabilitar controles de carro e ped; atualizar pose livre; sair zerando foto e
captura do cursor e reconstruindo a pose normal sem mudar `Track.cameraMode` ou
`cameraNum`.

## Matriz de validação necessária

Não basta provar no modo padrão. Para cada carro de referência, anotar a
contagem `GII_RENDER` e testar:

| Caso | Entrada e expectativa |
| --- | --- |
| Internal 0..N-1 | Entrar a pé, manter a visão no ped, retornar ao mesmo índice e à mesma câmera. |
| TV | Preservar/restaurar modo; confirmar timer não rouba câmera durante a pé. |
| Follow | Preservar distância e modo após retorno. |
| Chase | Preservar variante e alvos secundários. |
| Inverse chase | Preservar variante e alvos secundários. |
| Point | Se usado pela seção, registrar se é suportado na saída do carro ou se Track substitui a pose. |
| Track free (6) | Validar em separado o vínculo do controller e a recuperação de controle. |
| Drone New Age | Em cada modo de origem, verificar entrada/saída, carro/ped imóvel e estado de câmera restaurado. |
| Preview/GPS/OSD | Confirmar que câmera secundária não vence a seleção principal e que esconder/destruir a viewport a exclui. |

Para cada amostra registrar `cameraMode`, `cameraNum`, ID da câmera ativa,
viewport, prioridade/sequência, alvo live ID e tipo (`Chassis`/`RenderRef`),
`cockpit_index`, flags de modo, eye/at e se a matriz de mundo foi resolvida.
Comparar um caso que funciona com o primeiro que falha; esse delta é a pista
para a causa, não apenas o screenshot final.

## Estado conhecido desta documentação

- A existência e os contratos de Track, câmera CFG, câmera de script,
  câmera de voo e câmera a pé foram rastreados no código atual e em
  `Track.java` decompilado.
- O teste de round-trip cockpit/personagem identificou uma falha na seleção da
  câmera principal: a câmera precisa validar o mundo pelo `RenderRef` seguido,
  não pelo índice CFG do carro. A alteração proposta no selector precisa passar
  build e a matriz automatizada antes de ser declarada resolvida.
- A matriz preparada em `build/test_onfoot_camera_modes.ps1` cobre cinco
  índices internos do Baiern e quatro modos externos (TV, follow, chase,
  inverse-chase). Não prova todos os carros, perfis salvos, câmera Point,
  Track FREE, cada caminho de evento ou inspeção visual em todas as vistas.
- Os scripts decompilados em `build/decompiled/` são artefatos locais de
  investigação; a descrição aqui se baseia neles e no host versionado, não em
  uma alegação de equivalência byte a byte com o executável original.

## Fontes primárias no repositório

- `include/slrr/gameref.hpp`
- `src/resources/gameref.cpp`
- `src/resources/part_config.cpp`
- `src/resources/part_runtime.cpp`
- `src/natives/natives_osd.cpp`
- `src/platform/host_input.cpp`
- `src/boot/mainloop.cpp`
- `src/render/bgfx_lib_backend.cpp`
- `build/decompiled/Track/java/game/Track.java`
- `docs/ui/notes.md`
- `docs/CONTROLS.md`
