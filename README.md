# Batalha das Atléticas — projeto Godot

Este README documenta a nova organização do projeto (pasta `_reorganizado`)
e como ela substitui a estrutura antiga (tudo solto na raiz).

## 1. Por que essa estrutura

O Godot recomenda organizar projetos **por funcionalidade** (feature), e não
por tipo de arquivo — ou seja, a cena de um personagem, o script dele e os
sprites dele ficam juntos na mesma pasta, em vez de espalhados em `scenes/`,
`scripts/`, `sprites/` separados. Isso ajuda bastante um projeto em grupo:
cada pessoa (ou dupla) pode "dono" de uma pasta de personagem/feature e
mexer nela sem esbarrar no trabalho dos outros, o que gera muito menos
conflito de merge no Git.

```
project.godot
README.md
.editorconfig  .gitattributes  .gitignore

assets/                      # arte ainda não usada em nenhuma cena específica
  icon/icon.svg
  backgrounds/                # cenários "de reserva" para futuras fases
    floor.png, floor_01.png, bg.jpg, uemg1.png, uemg2.png

core/
  characters/
    fighter.gd                # classe base de todo lutador (NOVO)

characters/
  nhagare/                     # uma pasta por personagem jogável
    nhagare.tscn  nhagare.gd
    metadata.json              # prompt/gerador usado para criar a arte
    idle/ walk/ jump/ die/ die_animation/

objects/
  hadoken/                     # golpes especiais/objetos interativos
    hadoken.tscn  hadoken.gd  Hadouken.png

stages/
  stage_01/                    # uma pasta por fase/arena
    stage_01.tscn  ground_collision.gd  uemg3.png

ui/
  main_menu/
    main_menu.tscn  main_menu.gd
  hud/
    hud.tscn  hud.gd  health_bar.png
```

Quando a equipe criar a atlética de Engenharia, por exemplo, ela vai virar
`characters/engenharia/` com a mesma cara da pasta do Nhagare — e uma nova
fase vira `stages/stage_02/`. É só copiar o padrão.

## 2. Arquitetura orientada a objetos: `Fighter`

Antes, `player.gd` misturava duas responsabilidades num arquivo só:
vida/dano (que vale para qualquer personagem) e movimento/animação
específicos do Nhagare. Isso ia virar um problema assim que a equipe
começasse a criar os outros personagens do relatório (cada um copiaria e
colaria a lógica de vida, duplicando bugs).

Agora existe:

- **`core/characters/fighter.gd`** — classe base (`class_name Fighter`,
  `extends CharacterBody2D`). Guarda vida atual/máxima, os sinais
  `health_changed` e `died`, e os métodos `take_damage()`, `heal()`. Todo
  personagem futuro (bot ou jogador) estende essa classe.
- **`characters/nhagare/nhagare.gd`** — `extends Fighter`. Só cuida do que é
  específico do Nhagare: `_physics_process` (pulo, agachar, andar) e escolha
  de animação. Não sabe nada sobre barra de vida.
- **`ui/hud/hud.gd`** — escuta o sinal `health_changed` do lutador (a
  conexão já está feita em `stage_01.tscn`) e atualiza a barra sozinho.
  Antes o script do jogador ia direto no nó `ColorRect_fill` da HUD
  (`$"../CanvasLayer/ColorRect_fill"`), o que travava o personagem a uma
  posição fixa na árvore de cena. Agora HUD e personagem não se conhecem —
  só conversam por sinal, então dá pra reaproveisar o Nhagare em outra fase
  sem quebrar nada.

### Para criar um personagem novo

1. Duplique `characters/nhagare/` para `characters/<curso>/`.
2. Troque os sprites e o `class_name` do script (ex.: `class_name Engenharia`),
   mantendo `extends Fighter`.
3. Implemente só o que muda: movimento, animações e o(s) golpe(s) especial(is)
   do curso (o relatório já lista sugestões na seção 5.1).
4. `take_damage`, `heal`, a barra de vida e o sinal de morte já funcionam
   de graça, herdados do `Fighter`.

### Próximo passo natural (não feito agora)

Hoje só existe um golpe especial (`objects/hadoken/`). Quando a equipe
criar o segundo golpe especial de outro curso, vale criar uma classe base
`SpecialAttack` (parecida com o `Fighter`) para os golpes reaproveitarem
código — não fiz isso agora porque com um único exemplo seria especular
demais sobre o formato que os outros golpes vão ter.

## 3. O que foi limpo/deixado de lado (nada foi apagado do original)

- `players/nhagare/player.gd` (dentro da pasta de arte) — script solto e
  não usado por nenhuma cena, sobra de outra ferramenta/exportação. Não foi
  trazido para a nova estrutura.
- `control.tscn*.tmp` e `player.tscn*.tmp` — backups automáticos do editor
  do Godot, sem uso.
- `players/nhagare/jump/1_old.png`, `2_old.png`, `3_old.png` — versões
  antigas dos frames de pulo, sem uso; foram guardadas em
  `characters/nhagare/jump/legacy/` para não sumir de vez.
- `players/nhagare/die_animation/*` e `floor.png`, `floor_01.png`, `bg.jpg`,
  `uemg1.png`, `uemg2.png` — não estão referenciados em nenhuma cena hoje,
  então foram para `assets/backgrounds/` (arte "de reserva") em vez de
  dentro da fase 1, pra não sugerir que já estão em uso.

## 4. Como finalizar a migração

Por segurança, esta pasta (`_reorganizado`) foi criada **do lado** do
projeto antigo — nada foi apagado do projeto original. Passos para você
finalizar:

1. Abra `_reorganizado/project.godot` no Godot e confirme que tudo roda
   igual (menu → jogar → pulo, andar, hadoken, barra de vida).
2. Recomendo iniciar o controle de versão agora (o projeto ainda não tinha
   Git): dentro de `_reorganizado`, rode `git init`, `git add .`,
   `git commit -m "Reorganiza projeto por feature + Fighter base class"`.
   Depois crie o repositório remoto (GitHub/GitLab) e dê `git push` — a
   partir daí a equipe clona o repositório em vez de trocar a pasta por
   pendrive/WhatsApp.
3. Depois de confirmar que está tudo certo, apague a pasta antiga (os
   arquivos soltos na raiz de `joguin do nhacare`, fora `_reorganizado`) e
   mova o conteúdo de `_reorganizado` para a raiz do projeto — ou
   simplesmente passe a trabalhar direto dentro de `_reorganizado` e apague
   os arquivos antigos quando quiser.

## 5. Convenções para o grupo trabalhar junto

- Nomes de arquivo em `snake_case` (`ground_collision.gd`), nomes de classe
  em `PascalCase` (`class_name Fighter`).
- Cada personagem/fase/feature nova ganha sua própria pasta — evita
  conflito de merge quando duas pessoas mexem em personagens diferentes ao
  mesmo tempo.
- Sugestão de fluxo de Git para o grupo: uma branch por pessoa/feature
  (`feature/atletica-engenharia`, `feature/stage-02-quadra`), merge via
  Pull Request depois de testar no editor.
- `.gitignore` já ignora a pasta `.godot/` (cache local, não deve ir pro
  Git) — mantenha assim.
