# Controles padrão

Estas são as bindings padrão do SLRR New Age. O jogador pode redefini-las no
menu de controles; o contexto ativo (garagem, menu, direção ou câmera)
determina qual grupo recebe a tecla.

## Onde isso fica no projeto

As teclas padrão não são uma tabela fixa duplicada no C++. O fluxo é dividido
em duas partes:

1. O patch `patch/system/Scripts/io/src/ControlSet.java` redefine os padrões
   de direção (`W`, `S`, `A`, `D`), câmbio (`Left Shift`, `Left Ctrl`),
   embreagem (`E`), nitro (`N`), buzina (`H`) e cruise control (`P`).
   As demais bindings continuam herdadas do `ControlSet` original.
2. O host SLRR New Age implementa a leitura e o transporte desses eixos em
   `src/platform/host_input.cpp`, `src/platform/host_input_mapping.hpp` e
   `include/slrr/host_input.hpp`. Por exemplo, os eixos de direção, throttle,
   freio, NOS, freio de mão, embreagem, marcha e buzina são consumidos pelo
   controlador nesses arquivos.

O `.java` é a fonte versionada; depois de compilado, o `.class` correspondente
deve ser instalado no diretório `system/Scripts/io` do pacote do jogo. Se o
usuário alterar as teclas no menu, a configuração salva passa a ser a fonte
efetiva.

Para regenerar os artefatos depois de alterar o `.java`, use uma cópia privada
do jogo (nunca a instalação em uso):

```powershell
.\build\Release\compile_game_sources.exe <copia-do-jogo> system/Scripts/io
Copy-Item <copia-do-jogo>\system\Scripts\io\ControlSet*.class patch\system\Scripts\io\
```

## Direção

| Tecla | Ação |
| --- | --- |
| `W` | Acelerar |
| `S` | Frear |
| `A` | Virar para a esquerda |
| `D` | Virar para a direita |
| `Space` | Freio de mão |
| `Left Shift` | Subir marcha |
| `Left Ctrl` | Descer marcha |
| `E` | Embreagem |
| `N` | Nitro/NOS |
| `H` | Buzina |
| `P` | Cruise control |
| `B` | Olhar para trás |
| `M` | Mapa/GPS |

## Menu e câmera

| Tecla/gesto | Ação |
| --- | --- |
| `Esc` | Menu/voltar; também pula as intros |
| Setas | Navegação de menus e, na garagem, órbita da câmera |
| `Page Up` / `Page Down` | Zoom da câmera |
| Botão direito + arrastar | Orbitar a câmera na garagem |
| Roda do mouse | Zoom na garagem |
| `F12` | Screenshot/ação de impressão do jogo |
| `Ctrl+F12` | Painel de diagnóstico ImGui do host |

## Inventário do mapeamento padrão

Este inventário junta os grupos de `ControlSet.java` com os atalhos registrados
pela classe de pista `Track` instalada. O grupo ativo depende da tela: a mesma
seta pode navegar no menu, olhar ao redor ou mover a câmera de uma loja.

| Tecla | Grupo/contexto | Ação encontrada no código |
| --- | --- | --- |
| `W` / `S` | Direção | Acelerar / frear |
| `A` / `D` | Direção | Virar à esquerda / direita |
| `Space` | Direção e menu | Freio de mão; também selecionar no menu |
| `Left Shift` / `Left Ctrl` | Direção | Subir / descer marcha |
| `E` | Direção | Embreagem |
| `N` / `H` | Direção | Nitro / buzina |
| `P` | Direção | Cruise control |
| `B` / `M` | Direção | Olhar para trás / abrir o mapa |
| `Enter` / `Numpad Enter` | Menu | Selecionar |
| `Esc` | Geral/menu | Abrir/voltar/cancelar; também pula as intros |
| Setas | Menu | Navegar para cima, baixo, esquerda e direita |
| Setas | Olhar | Inclinar a visão para cima/baixo e girar para esquerda/direita |
| Setas | Movimento de loja | Mover para frente/trás e para os lados |
| `Page Up` / `Page Down` / roda | Câmera | Zoom para perto/longe |
| Botão esquerdo | Ponteiro | Clique/seleção |
| Botão direito | Câmera/ponteiro | Segurar e arrastar para orbitar; também ação secundária |
| `.` / `,` | Música | Próxima faixa / faixa anterior |
| `Numpad *` / `Numpad /` | Música | Aumentar / diminuir volume |
| `Numpad 7, 8, 9, 4, 5, 6, 1, 2, 3, 0` | Direção | Ações especiais/fogo do perfil; o efeito depende do veículo ou script ativo |
| `F12` | Geral | Screenshot/ação de impressão |
| `Ctrl+F12` | Host New Age | Abrir/fechar painel de diagnóstico |

### Câmeras da pista e conflito F1–F5

A classe `Track` instalada registra originalmente F1 para câmera interna, F2
para câmera de TV, F3 para câmera externa/seguimento, F4 para chase e F5 para
chase invertida. O grupo `ControlSet` também associa F1/F2 a olhar anterior/
próximo e F5 a olhar para trás. Essa duplicidade é a origem do conflito.

No New Age, `C` é o único atalho para trocar os modos de câmera da pista. Ele
usa os comandos nativos de `Track` e avança por cada posição interna retornada
pelo carro antes de seguir pelos demais modos. F1–F4 são consumidas pelo host e
nunca mudam a câmera. F5 continua sendo olhar para trás; seu comando original
de chase invertida também é acessível pelo ciclo de `C`.

### Câmera do personagem a pé

| Tecla/gesto | Ação |
| --- | --- |
| `F` | Sair do carro / voltar ao carro |
| Mouse | Orbitar a câmera em torno do personagem, sem segurar botão |
| `W` / `A` / `S` / `D` | Andar |
| `Shift` | Correr |
| `Space` | Pular |
| `C` | Ignorado a pé; mantém a câmera presa ao personagem |
| `Delete` | Alternar para a câmera de voo; personagem e carro ficam parados |

A câmera a pé usa pose direta própria; não reutiliza o amortecimento nem os
comandos de ângulo herdados da câmera do carro. Yaw e pitch têm sinais
independentes para manter o mouse natural após a conversão dos eixos para
BGFX. A colisão considera paredes e filtra piso/teto para evitar saltos nas
emendas do terreno. Ao voltar ao carro, o estado salvo da câmera veicular é
restaurado.

### Câmera de voo New Age

| Tecla | Ação durante o voo |
| --- | --- |
| `Delete` | Entrar/sair da câmera de voo |
| `W` / `S` | Avançar / recuar a câmera, sem mover o carro |
| `A` / `D` | Deslocar a câmera para os lados, sem virar o carro |
| `Left Shift` / `Left Ctrl` | Subir / descer |
| `E` / `Q` | Inclinar/rolar a câmera para os lados |
| Mouse | Orientar a câmera livremente, sem segurar botão |
| Roda do mouse | Mudar o multiplicador de voo em passos; faixa de `x0,01` a `x512` |
| Indicador na tela | Mostra o multiplicador de velocidade atual durante o voo |
| `F1` | Alternar modo foto, ocultando/mostrando a HUD; não troca a câmera |

F1–F5 são atalhos de câmera originais da classe `Track`; F9 (câmera livre),
F10 (reparo rápido) e F11 (troca do alvo de câmera) só são registrados quando
`Config.majomParade` está ativo no jogo original.

## Música

| Tecla | Ação |
| --- | --- |
| `.` | Próxima música |
| `,` | Música anterior |
| `Num *` | Aumentar volume da música |
| `Num /` | Diminuir volume da música |

## Câmera livre/debug

As bindings abaixo pertencem ao grupo de câmera/debug e só atuam quando esse
modo está ativo:

- `A` / `Z`: mover para frente/trás;
- Setas esquerda/direita: mover lateralmente;
- Setas cima/baixo: mover verticalmente;
- `Num +` / `Num -`: zoom.

Gamepads, volantes, pedais e shifters devem ser configurados em **Options →
Controls**. O projeto mantém o perfil lógico legado `XInput Gamepad`, mas a
leitura atual passa pelo SDL3 e aceita periféricos adicionais.
