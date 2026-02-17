extends Node
## Autoload: guarda o nome do marcador onde o jogador deve spawnar ao carregar a próxima cena.
## O ScenePortal define isso antes de trocar de cena; o SpawnAtMarker aplica ao carregar.

var next_marker_name: String = ""
