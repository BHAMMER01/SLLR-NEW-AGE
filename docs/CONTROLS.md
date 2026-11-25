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
