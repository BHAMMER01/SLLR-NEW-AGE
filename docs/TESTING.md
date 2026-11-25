# Testes do SLRR New Age

## Abrir na garagem

Use o executável compilado do projeto e o runtime do jogo indicado em `--root`.
`--spawn-car` entra diretamente na garagem com o Baiern de teste carregado:

```powershell
cd C:\games\SLRROPENCLEAN\SLRR-NEWAGE\SLLR-NEW-AGE
& .\build\Release\slrr_host.exe `
  --game --window --no-vsync `
  --root "C:\games\SLRROPENCLEAN\SLRR-NEWAGE\Street Legal Racing - Redline" `
  --spawn-car cars/racers/Baiern.rpk:0x6 `
  --renderer vulkan
```

O log deve mostrar `[section] enter java.game.Garage` e
`[boot] spawned cars/racers/Baiern.rpk:0x6`.

## Abrir a cidade automaticamente

Para entrar diretamente na cidade com o mesmo carro, acrescente `--auto-city`:

```powershell
cd C:\games\SLRROPENCLEAN\SLRR-NEWAGE\SLLR-NEW-AGE
& .\build\Release\slrr_host.exe `
  --game --window --no-vsync `
  --root "C:\games\SLRROPENCLEAN\SLRR-NEWAGE\Street Legal Racing - Redline" `
  --spawn-car cars/racers/Baiern.rpk:0x6 `
  --auto-city --renderer vulkan
```

`--auto-city` inicia `java.game.Valocity` sem passar pela garagem. Para
medições repetíveis, use o monitor abaixo; ele cria uma cópia privada do runtime.

O runtime fica fora do checkout do código. Use sempre o `-GameRoot` explícito:

```powershell
cd C:\games\SLRROPENCLEAN\SLRR-NEWAGE\SLLR-NEW-AGE
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\monitor_slrr.ps1 `
  -Seconds 60 `
  -Renderer vulkan `
  -GameRoot "C:\games\SLRROPENCLEAN\SLRR-NEWAGE\Street Legal Racing - Redline"
```

Sem `-Map`, o script usa `--auto-cmd street`; com `-Map`, ele mantém o mapa de
benchmark. Esse script serve para medições e não substitui os comandos de
abertura interativa documentados acima. Ele cria uma cópia privada em
`build/monitor/root-*`, portanto não altera o runtime principal.

## Onde ficam os resultados

- `build/monitor/run-*.out.log`: log do host e do jogo;
- `build/monitor/run-*.err.log`: erros;
- `build/monitor/perf-*.csv`: tempo de quadro;
- `build/monitor/system-*.csv`: CPU, memória e GPU.

## Diagnóstico de teclas

O host registra transições de hotkey com o estado físico de `S` e `P` usando a
linha `[input-hotkey]` no log. O teste de benchmark não injeta teclas; para
validar entrada é necessário executar o runtime interativo e enviar a sequência
`W`, `S` e `P`, depois consultar o `run-*.out.log` mais recente.

## Inspecionar classes Java instaladas

Quando um comportamento não aparece em `patch/`, decompile a classe TUFA
instalada antes de alterar o host:

```powershell
.\scripts\decompile_slrr_class.ps1 `
  "C:\games\SLRROPENCLEAN\SLRR-NEWAGE\Street Legal Racing - Redline\sl\Scripts\game\Track.class" `
  -OutputDirectory .\build\decompiled\Track -Ir -Strict
```

O resultado fica em `build/decompiled/` e não modifica a instalação do jogo.
