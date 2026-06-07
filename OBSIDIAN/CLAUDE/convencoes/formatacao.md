# Convenção — Formatação de arquivos

> Sempre aplicar a formatação correta antes de commitar e ao final de cada tarefa.

## Regras (impostas por `file_format.sh`)

- Codificação **UTF-8 sem BOM**
- Quebras de linha **LF** (Unix)
- **Sem** espaços em branco no fim das linhas (trailing whitespace)
- **Newline final** no fim do arquivo

## Como aplicar

Na raiz do repositório (`C:\GODOT\TPSDEMO`), via **Git Bash** no Windows:

```bash
bash file_format.sh
```

Dependências: `dos2unix` e `perl` (o `recode` é opcional — os arquivos já são UTF-8).

## Por que importa

- Um **BOM** (`EF BB BF`) no início de um `.tscn`/`.tres` faz o parser do Godot
  falhar com `Parse Error: Expected '['`, quebrando o carregamento da cena.
  Foi exatamente o que impedia o `level_base` de carregar — a correção foi
  remover o BOM de 12 arquivos.

## Convenção relacionada — cache de UIDs

Ao **mover/renomear** cenas ou recursos:

1. Atualizar todas as referências `res://...` (incl. internas de `.tscn`/`.tres`/`.import`).
2. Reabrir o projeto no **editor do Godot** uma vez para reconstruir o
   `.godot/uid_cache.bin` e reimportar os assets movidos. Isso limpa os warnings
   `invalid UID … using text path instead`.

Arquivos binários (`.mesh`, `.glb`) podem conter caminhos embutidos que **não**
são corrigidos por edição de texto — nesses casos é preciso reimportar/re-exportar
do `.blend` ou reatribuir o recurso no editor.

## Links

- [[000-INDEX]]
